// Thin wrapper around the GitHub REST API. The token is never logged and is
// stripped from any error text we construct. `fetchImpl` is injectable so
// the Node tests can mock it; the browser uses `globalThis.fetch`.

import {
  GITHUB_OWNER, GITHUB_REPO, GITHUB_BRANCH,
} from './config.js';
import { utf8ToBase64, base64ToUtf8 } from './serialize.js';

const API_BASE = 'https://api.github.com';

export class GitHubError extends Error {
  constructor(message, { status = 0, kind = 'other' } = {}) {
    super(message);
    this.name = 'GitHubError';
    this.status = status;
    this.kind = kind;
  }
}

function headers(token, extra = {}) {
  return {
    'Authorization': `Bearer ${token}`,
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    ...extra,
  };
}

function scrub(message, token) {
  if (!message) return message;
  const s = String(message);
  if (!token) return s;
  // Replace both the raw token and anything that looks like it (defence in
  // depth: never let the user see their own secret in an error dialog).
  return s.split(token).join('«token»');
}

function wrapNetwork(err, token) {
  const msg = scrub(err?.message || err, token);
  return new GitHubError(`Couldn't reach GitHub (${msg})`, { kind: 'network' });
}

async function readBodyMessage(res, token) {
  try {
    const text = await res.text();
    if (!text) return `HTTP ${res.status}`;
    try {
      const body = JSON.parse(text);
      if (body && typeof body.message === 'string') return scrub(body.message, token);
    } catch { /* not json */ }
    return scrub(text, token);
  } catch { return `HTTP ${res.status}`; }
}

function encodePath(p) {
  // Preserve `/` separators; encode path segments.
  return p.split('/').map(encodeURIComponent).join('/');
}

// Test the token by hitting GET /repos/{o}/{r}. On success returns
// { ok: true, fullName }. On any failure throws a GitHubError whose
// `.kind` is one of 'network' | 'unauthorized' | 'forbidden' | 'notFound'
// | 'noPush' | 'other'. (AC10.2)
export async function testConnection(token, { fetchImpl = globalThis.fetch } = {}) {
  if (typeof token !== 'string' || token.length === 0) {
    throw new GitHubError('No token provided', { kind: 'unauthorized' });
  }
  let res;
  try {
    res = await fetchImpl(`${API_BASE}/repos/${GITHUB_OWNER}/${GITHUB_REPO}`, {
      method: 'GET',
      headers: headers(token),
    });
  } catch (err) {
    throw wrapNetwork(err, token);
  }
  if (res.status === 200) {
    let body;
    try { body = await res.json(); }
    catch { throw new GitHubError('GitHub returned an unexpected response', { status: 200, kind: 'other' }); }
    if (body?.permissions?.push === true) {
      return { ok: true, fullName: body.full_name || `${GITHUB_OWNER}/${GITHUB_REPO}` };
    }
    throw new GitHubError('Token has no push permission on this repo', { status: 200, kind: 'noPush' });
  }
  const message = await readBodyMessage(res, token);
  if (res.status === 401) throw new GitHubError(`Token rejected (401): ${message}`, { status: 401, kind: 'unauthorized' });
  if (res.status === 403) throw new GitHubError(`Access forbidden (403): ${message}`, { status: 403, kind: 'forbidden' });
  if (res.status === 404) throw new GitHubError(`Not found (404): ${message}`, { status: 404, kind: 'notFound' });
  throw new GitHubError(`GitHub returned HTTP ${res.status}: ${message}`, { status: res.status, kind: 'other' });
}

// GET /repos/{o}/{r}/contents/{path}?ref=<branch>. Returns { sha, text }.
export async function getFile(token, repoPath, { fetchImpl = globalThis.fetch } = {}) {
  const url = `${API_BASE}/repos/${GITHUB_OWNER}/${GITHUB_REPO}/contents/${encodePath(repoPath)}?ref=${encodeURIComponent(GITHUB_BRANCH)}`;
  let res;
  try {
    res = await fetchImpl(url, { method: 'GET', headers: headers(token) });
  } catch (err) {
    throw wrapNetwork(err, token);
  }
  if (res.status === 200) {
    let body;
    try { body = await res.json(); }
    catch { throw new GitHubError('GitHub returned an unexpected response', { status: 200, kind: 'other' }); }
    if (body?.encoding !== 'base64' || typeof body.content !== 'string') {
      throw new GitHubError('Unexpected contents payload (not base64)', { status: 200, kind: 'other' });
    }
    const text = base64ToUtf8(body.content);
    return { sha: String(body.sha || ''), text };
  }
  const message = await readBodyMessage(res, token);
  if (res.status === 401) throw new GitHubError(`Token rejected (401): ${message}`, { status: 401, kind: 'unauthorized' });
  if (res.status === 403) throw new GitHubError(`Access forbidden (403): ${message}`, { status: 403, kind: 'forbidden' });
  if (res.status === 404) throw new GitHubError(`File not found (404): ${message}`, { status: 404, kind: 'notFound' });
  throw new GitHubError(`GitHub returned HTTP ${res.status}: ${message}`, { status: res.status, kind: 'other' });
}

// PUT /repos/{o}/{r}/contents/{path} with the shape documented in AC11.6.
// 409/422 → kind 'conflict' (sha mismatch). 401/403 → 'unauthorized'/'forbidden'.
export async function putFile(token, repoPath, {
  message, text, sha,
}, { fetchImpl = globalThis.fetch } = {}) {
  const url = `${API_BASE}/repos/${GITHUB_OWNER}/${GITHUB_REPO}/contents/${encodePath(repoPath)}`;
  const body = {
    message: String(message || 'Update from web app'),
    content: utf8ToBase64(text),
    sha,
    branch: GITHUB_BRANCH,
  };
  let res;
  try {
    res = await fetchImpl(url, {
      method: 'PUT',
      headers: headers(token, { 'Content-Type': 'application/json' }),
      body: JSON.stringify(body),
    });
  } catch (err) {
    throw wrapNetwork(err, token);
  }
  if (res.status === 200 || res.status === 201) {
    let out;
    try { out = await res.json(); }
    catch { out = {}; }
    const newSha = out?.content?.sha || out?.commit?.sha || '';
    return { ok: true, sha: String(newSha) };
  }
  const bodyMsg = await readBodyMessage(res, token);
  if (res.status === 409 || res.status === 422) {
    throw new GitHubError(`This chart changed on GitHub since you opened it: ${bodyMsg}`, {
      status: res.status, kind: 'conflict',
    });
  }
  if (res.status === 401) throw new GitHubError(`Token rejected (401): ${bodyMsg}`, { status: 401, kind: 'unauthorized' });
  if (res.status === 403) throw new GitHubError(`Access forbidden (403): ${bodyMsg}`, { status: 403, kind: 'forbidden' });
  if (res.status === 404) throw new GitHubError(`File not found (404): ${bodyMsg}`, { status: 404, kind: 'notFound' });
  throw new GitHubError(`GitHub returned HTTP ${res.status}: ${bodyMsg}`, { status: res.status, kind: 'other' });
}

// A sha that can never match a real file version.
const PROBE_SHA = '0000000000000000000000000000000000000000';

// Checks that the token itself can write file contents. GET /repos reports
// `permissions.push` for the token's *owner*, so a fine-grained token without
// "Contents: Read and write" passes it and then fails on save. Here we read
// `probePath`, then PUT the same content back with a sha that can't match:
// GitHub checks authorization first, so a write-capable token gets 409
// (version mismatch, nothing written) and a read-only token gets 403/404.
// The content sent is the file's current content, so even an unexpected
// success leaves the file unchanged. Resolves { ok: true } or throws
// GitHubError with kind 'noWrite' | 'unauthorized' | 'network' | 'other'.
export async function testWriteAccess(token, probePath, { fetchImpl = globalThis.fetch } = {}) {
  const { text } = await getFile(token, probePath, { fetchImpl });
  try {
    await putFile(token, probePath, {
      message: 'Write-access check (rejected by design, changes nothing)',
      text,
      sha: PROBE_SHA,
    }, { fetchImpl });
    return { ok: true };
  } catch (err) {
    if (!(err instanceof GitHubError)) throw err;
    if (err.kind === 'conflict') return { ok: true };
    if (err.kind === 'forbidden' || err.kind === 'notFound') {
      throw new GitHubError(
        `Token can read but not write ranges_trainer (${err.status}). ` +
        'Give it Repository permissions → Contents: Read and write.',
        { status: err.status, kind: 'noWrite' },
      );
    }
    throw err;
  }
}
