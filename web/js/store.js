// Browser-side storage helpers for the GitHub token and recently-saved
// writes. The reconcile function is a pure helper so Node can test it.

import {
  TOKEN_STORAGE_KEY, PENDING_WRITES_KEY, PENDING_TTL_MS, OLD_PALETTE_KEYS,
} from './config.js';

// ---- Token ----------------------------------------------------------------

export function getToken() {
  try { return localStorage.getItem(TOKEN_STORAGE_KEY) || null; }
  catch { return null; }
}

export function setToken(token) {
  try { localStorage.setItem(TOKEN_STORAGE_KEY, token); } catch {}
}

export function clearToken() {
  try { localStorage.removeItem(TOKEN_STORAGE_KEY); } catch {}
}

// ---- Pending writes -------------------------------------------------------
//
// Shape: { [appPath]: { text: string, savedAt: number } }

export function loadPendingWrites() {
  try {
    const raw = localStorage.getItem(PENDING_WRITES_KEY);
    if (!raw) return {};
    const obj = JSON.parse(raw);
    if (!obj || typeof obj !== 'object') return {};
    return obj;
  } catch { return {}; }
}

export function savePendingWrites(obj) {
  try { localStorage.setItem(PENDING_WRITES_KEY, JSON.stringify(obj || {})); } catch {}
}

export function recordPendingWrite(appPath, text, now = Date.now()) {
  const pending = loadPendingWrites();
  pending[appPath] = { text: String(text), savedAt: now };
  savePendingWrites(pending);
}

// Delete legacy localStorage keys that are no longer used (AC12.2).
export function clearOldPaletteKeys() {
  for (const k of OLD_PALETTE_KEYS) {
    try { localStorage.removeItem(k); } catch {}
  }
}

// ---- Pure reconciliation (unit-tested) ------------------------------------
//
// For each pending write:
//   * if `savedAt` is older than `ttlMs` → drop it.
//   * else if the deployed text equals the pending text → drop it (deploy
//     has caught up and the on-disk value matches what we saved).
//   * otherwise → keep it and use the pending text as the override.
//
// `deployedByPath` is a map of appPath → deployed text (null/undefined if
// unknown, in which case the entry is kept if still fresh — we can't tell
// yet whether the deploy caught up). Returns both the trimmed `pending`
// (to persist back to localStorage) and the `overrides` map to apply.
export function reconcilePendingWrites(pending, deployedByPath, now = Date.now(), ttlMs = PENDING_TTL_MS) {
  const kept = {};
  const overrides = {};
  if (!pending || typeof pending !== 'object') {
    return { pending: kept, overrides };
  }
  for (const [path, entry] of Object.entries(pending)) {
    if (!entry || typeof entry !== 'object') continue;
    const text = typeof entry.text === 'string' ? entry.text : null;
    const savedAt = typeof entry.savedAt === 'number' ? entry.savedAt : NaN;
    if (text == null || !Number.isFinite(savedAt)) continue;
    if (now - savedAt > ttlMs) continue;                       // stale
    const deployed = deployedByPath ? deployedByPath[path] : undefined;
    if (typeof deployed === 'string' && deployed === text) continue; // caught up
    kept[path] = { text, savedAt };
    overrides[path] = text;
  }
  return { pending: kept, overrides };
}
