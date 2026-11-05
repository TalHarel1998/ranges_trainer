// Tests for the GitHub REST client. All HTTP is mocked via `fetchImpl`.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { testConnection, testWriteAccess, getFile, putFile, GitHubError } from '../js/github.js';
import { utf8ToBase64 } from '../js/serialize.js';

const TOKEN = 'github_pat_FAKE_111122223333';

function makeResponse({ status = 200, body = {}, text = null } = {}) {
  const textVal = text ?? JSON.stringify(body);
  return {
    status,
    ok: status >= 200 && status < 300,
    async json() { return JSON.parse(textVal); },
    async text() { return textVal; },
  };
}

function recorder(responder) {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    return responder(url, init);
  };
  return { calls, fetchImpl };
}

// ---------------------- testConnection ----------------------

test('testConnection: 200 with push=true returns ok and uses correct URL/headers', async () => {
  const { calls, fetchImpl } = recorder(() => makeResponse({
    status: 200, body: { full_name: 'TalHarel1998/ranges_trainer', permissions: { push: true } },
  }));
  const result = await testConnection(TOKEN, { fetchImpl });
  assert.equal(result.ok, true);
  assert.equal(result.fullName, 'TalHarel1998/ranges_trainer');
  assert.equal(calls.length, 1);
  const { url, init } = calls[0];
  assert.equal(url, 'https://api.github.com/repos/TalHarel1998/ranges_trainer');
  assert.equal(init.headers['Authorization'], `Bearer ${TOKEN}`);
  assert.equal(init.headers['Accept'], 'application/vnd.github+json');
  assert.equal(init.headers['X-GitHub-Api-Version'], '2022-11-28');
});

test('testConnection: 200 with push=false → kind "noPush", not stored', async () => {
  const { fetchImpl } = recorder(() => makeResponse({
    status: 200, body: { permissions: { push: false } },
  }));
  await assert.rejects(testConnection(TOKEN, { fetchImpl }), (err) => {
    assert.ok(err instanceof GitHubError);
    assert.equal(err.kind, 'noPush');
    return true;
  });
});

test('testConnection: 401 → kind "unauthorized"', async () => {
  const { fetchImpl } = recorder(() => makeResponse({
    status: 401, body: { message: 'Bad credentials' },
  }));
  await assert.rejects(testConnection(TOKEN, { fetchImpl }), (err) => {
    assert.ok(err instanceof GitHubError);
    assert.equal(err.kind, 'unauthorized');
    assert.equal(err.status, 401);
    return true;
  });
});

test('testConnection: 404 → kind "notFound"', async () => {
  const { fetchImpl } = recorder(() => makeResponse({ status: 404, body: { message: 'Not Found' } }));
  await assert.rejects(testConnection(TOKEN, { fetchImpl }), (err) => {
    assert.equal(err.kind, 'notFound');
    return true;
  });
});

test('testConnection: thrown fetch → kind "network"', async () => {
  const fetchImpl = async () => { throw new Error('ECONNREFUSED'); };
  await assert.rejects(testConnection(TOKEN, { fetchImpl }), (err) => {
    assert.equal(err.kind, 'network');
    return true;
  });
});

test('testConnection: token must not appear in error messages', async () => {
  const scenarios = [
    () => makeResponse({ status: 401, body: { message: `invalid token ${TOKEN}` } }),
    () => makeResponse({ status: 403, body: { message: TOKEN } }),
    () => { throw new Error(`network ${TOKEN} failed`); },
  ];
  for (const resp of scenarios) {
    const fetchImpl = async () => resp();
    try {
      await testConnection(TOKEN, { fetchImpl });
      assert.fail('should have thrown');
    } catch (err) {
      assert.ok(!String(err.message).includes(TOKEN),
        `error leaked token: ${err.message}`);
    }
  }
});

// ---------------------- getFile ----------------------

test('getFile: decodes base64 content, returns sha and text', async () => {
  const text = '{"scenario":"rfi.utg"}\n';
  const encoded = utf8ToBase64(text);
  const { calls, fetchImpl } = recorder(() => makeResponse({
    status: 200,
    body: { sha: 'abc1234', encoding: 'base64', content: encoded },
  }));
  const { sha, text: got } = await getFile(TOKEN, 'web/palette.json', { fetchImpl });
  assert.equal(sha, 'abc1234');
  assert.equal(got, text);
  // URL contains ?ref=main
  assert.match(calls[0].url, /\?ref=main$/);
  // Path kept slash-separated
  assert.match(calls[0].url, /\/contents\/web\/palette\.json\?/);
});

test('getFile: handles multiline base64 payloads from GitHub', async () => {
  const text = 'line1\nline2 — ♠\n';
  const encoded = utf8ToBase64(text).replace(/.{20}/g, m => m + '\n');
  const { fetchImpl } = recorder(() => makeResponse({
    status: 200, body: { sha: 's', encoding: 'base64', content: encoded },
  }));
  const { text: got } = await getFile(TOKEN, 'web/palette.json', { fetchImpl });
  assert.equal(got, text);
});

test('getFile: 404 → kind "notFound"', async () => {
  const { fetchImpl } = recorder(() => makeResponse({ status: 404, body: { message: 'nope' } }));
  await assert.rejects(getFile(TOKEN, 'bad/path', { fetchImpl }), (err) => {
    assert.equal(err.kind, 'notFound');
    return true;
  });
});

// ---------------------- putFile ----------------------

test('putFile: 200 body shape and headers are correct', async () => {
  const { calls, fetchImpl } = recorder(() => makeResponse({
    status: 200, body: { content: { sha: 'newsha' } },
  }));
  const text = 'hello —♠';
  await putFile(TOKEN, 'charts/rfi/utg.json', {
    message: 'Edit UTG RFI from web app',
    text,
    sha: 'oldsha',
  }, { fetchImpl });

  assert.equal(calls.length, 1);
  const { url, init } = calls[0];
  assert.equal(url, 'https://api.github.com/repos/TalHarel1998/ranges_trainer/contents/charts/rfi/utg.json');
  assert.equal(init.method, 'PUT');
  assert.equal(init.headers['Authorization'], `Bearer ${TOKEN}`);
  assert.equal(init.headers['Accept'], 'application/vnd.github+json');
  assert.equal(init.headers['X-GitHub-Api-Version'], '2022-11-28');
  assert.equal(init.headers['Content-Type'], 'application/json');
  const body = JSON.parse(init.body);
  assert.equal(body.message, 'Edit UTG RFI from web app');
  assert.equal(body.sha, 'oldsha');
  assert.equal(body.branch, 'main');
  // content is base64 UTF-8 of text
  assert.equal(body.content, utf8ToBase64(text));
});

test('putFile: 409 → kind "conflict"', async () => {
  const { fetchImpl } = recorder(() => makeResponse({ status: 409, body: { message: 'sha mismatch' } }));
  await assert.rejects(putFile(TOKEN, 'p', { message: 'x', text: 'y', sha: 's' }, { fetchImpl }), (err) => {
    assert.equal(err.kind, 'conflict');
    assert.equal(err.status, 409);
    return true;
  });
});

test('putFile: 422 → kind "conflict"', async () => {
  const { fetchImpl } = recorder(() => makeResponse({ status: 422, body: { message: 'Unprocessable' } }));
  await assert.rejects(putFile(TOKEN, 'p', { message: 'x', text: 'y', sha: 's' }, { fetchImpl }), (err) => {
    assert.equal(err.kind, 'conflict');
    return true;
  });
});

test('putFile: 401 → kind "unauthorized"', async () => {
  const { fetchImpl } = recorder(() => makeResponse({ status: 401, body: { message: 'bad' } }));
  await assert.rejects(putFile(TOKEN, 'p', { message: 'x', text: 'y', sha: 's' }, { fetchImpl }), (err) => {
    assert.equal(err.kind, 'unauthorized');
    return true;
  });
});

test('putFile: network error → kind "network"', async () => {
  const fetchImpl = async () => { throw new Error('ENETUNREACH'); };
  await assert.rejects(putFile(TOKEN, 'p', { message: 'x', text: 'y', sha: 's' }, { fetchImpl }), (err) => {
    assert.equal(err.kind, 'network');
    return true;
  });
});

test('putFile: encoded path preserves slashes', async () => {
  const { calls, fetchImpl } = recorder(() => makeResponse({ status: 200, body: {} }));
  await putFile(TOKEN, 'PreflopT/PreflopT/Resources/Charts/rfi/utg.json', {
    message: 'x', text: 'y', sha: 's',
  }, { fetchImpl });
  assert.match(calls[0].url, /\/contents\/PreflopT\/PreflopT\/Resources\/Charts\/rfi\/utg\.json$/);
});

test('putFile: token never leaks into error messages', async () => {
  const scenarios = [
    () => makeResponse({ status: 409, body: { message: `conflict for ${TOKEN}` } }),
    () => makeResponse({ status: 401, body: { message: TOKEN } }),
    () => { throw new Error(`net ${TOKEN} boom`); },
  ];
  for (const resp of scenarios) {
    const fetchImpl = async () => resp();
    try {
      await putFile(TOKEN, 'p', { message: 'x', text: 'y', sha: 's' }, { fetchImpl });
      assert.fail('should have thrown');
    } catch (err) {
      assert.ok(!String(err.message).includes(TOKEN));
    }
  }
});

// ---------------------- testWriteAccess ----------------------
// GET /repos reports the account's permissions, so a fine-grained token with
// read-only Contents passes testConnection. testWriteAccess catches that by
// PUTting the unchanged file with a sha that can't match.

const PROBE_PATH = 'web/palette.json';
const PROBE_TEXT = '{\n  "actions": {}\n}\n';

function probeResponder(putStatus, putBody = { message: 'x' }) {
  return (url, init) => {
    if (init.method === 'GET') {
      return makeResponse({ status: 200, body: { sha: 'realsha', encoding: 'base64', content: utf8ToBase64(PROBE_TEXT) } });
    }
    return makeResponse({ status: putStatus, body: putBody });
  };
}

test('testWriteAccess: 409 on wrong sha → write access confirmed', async () => {
  const { calls, fetchImpl } = recorder(probeResponder(409, { message: 'web/palette.json does not match 0000' }));
  const result = await testWriteAccess(TOKEN, PROBE_PATH, { fetchImpl });
  assert.equal(result.ok, true);
  assert.equal(calls.length, 2);
  const put = calls[1];
  assert.equal(put.init.method, 'PUT');
  const body = JSON.parse(put.init.body);
  assert.equal(body.sha, '0000000000000000000000000000000000000000', 'probe sha never matches a real file');
  assert.equal(Buffer.from(body.content, 'base64').toString('utf8'), PROBE_TEXT, 'probe sends the current content unchanged');
  assert.equal(body.branch, 'main');
});

test('testWriteAccess: 403 (read-only token) → kind "noWrite" with fix instructions', async () => {
  const { fetchImpl } = recorder(probeResponder(403, { message: 'Resource not accessible by personal access token' }));
  await assert.rejects(testWriteAccess(TOKEN, PROBE_PATH, { fetchImpl }), (err) => {
    assert.ok(err instanceof GitHubError);
    assert.equal(err.kind, 'noWrite');
    assert.equal(err.status, 403);
    assert.match(err.message, /Contents: Read and write/);
    assert.ok(!err.message.includes(TOKEN));
    return true;
  });
});

test('testWriteAccess: 404 on PUT (no repo write) → kind "noWrite"', async () => {
  const { fetchImpl } = recorder(probeResponder(404));
  await assert.rejects(testWriteAccess(TOKEN, PROBE_PATH, { fetchImpl }), (err) => err.kind === 'noWrite');
});

test('testWriteAccess: 401 → kind "unauthorized"', async () => {
  const { fetchImpl } = recorder(probeResponder(401, { message: 'Bad credentials' }));
  await assert.rejects(testWriteAccess(TOKEN, PROBE_PATH, { fetchImpl }), (err) => err.kind === 'unauthorized');
});

test('testWriteAccess: GET failure propagates (e.g. network)', async () => {
  const fetchImpl = async () => { throw new TypeError('Failed to fetch'); };
  await assert.rejects(testWriteAccess(TOKEN, PROBE_PATH, { fetchImpl }), (err) => err.kind === 'network');
});
