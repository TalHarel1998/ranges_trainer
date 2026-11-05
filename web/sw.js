// PreflopT service worker.
//
// Caching strategy
// ----------------
// We precache the app shell + icons + all 23 chart JSONs so the app works
// offline after one successful online visit. At runtime we split by request:
//
//   * Navigation requests, and GETs for .js / .css / .webmanifest / .json
//     (chart data, manifest, code): network-first with a ~3s timeout. On
//     timeout or failure we fall back to the cached copy. Successful
//     network responses update the cache. A new deploy is visible on the
//     next app launch (a same-tab reload may still reuse in-memory JS).
//
//   * Everything else (icons / PNGs / images): cache-first with a quiet
//     background refresh.
//
// Versioning
// ----------
// VERSION contains the literal `preflopt-__BUILD__` in the repo. The Pages
// workflow rewrites `__BUILD__` to the short commit SHA when preparing
// `_site/` so each deploy owns a unique cache. On activate we drop every
// cache name that isn't the current VERSION.

const VERSION = 'preflopt-__BUILD__';
const NETWORK_TIMEOUT_MS = 3000;

const APP_SHELL = [
  './',
  './index.html',
  './styles.css',
  './manifest.webmanifest',
  './js/app.js',
  './js/domain.js',
  './js/charts.js',
  './js/colors.js',
  './icons/apple-touch-icon.png',
  './icons/icon-192.png',
  './icons/icon-512.png',
];

const CHART_FILES = [
  'charts/rfi/utg.json',
  'charts/rfi/mp.json',
  'charts/rfi/co.json',
  'charts/rfi/btn.json',
  'charts/rfi/sb.json',
  'charts/defense/btn_vs_utg.json',
  'charts/defense/btn_vs_co.json',
  'charts/defense/sb_vs_utg.json',
  'charts/defense/sb_vs_co.json',
  'charts/defense/sb_vs_btn.json',
  'charts/defense/bb_vs_utg.json',
  'charts/defense/bb_vs_co.json',
  'charts/defense/bb_vs_btn.json',
  'charts/vs_3bet/utg_vs_ip.json',
  'charts/vs_3bet/utg_vs_oop.json',
  'charts/vs_3bet/co_vs_ip.json',
  'charts/vs_3bet/co_vs_oop.json',
  'charts/vs_3bet/btn_vs_oop.json',
  'charts/vs_3bet/sb_vs_ip.json',
  'charts/vs_4bet/vs4b_btn_vs_utg.json',
  'charts/vs_4bet/vs4b_btn_vs_co.json',
  'charts/vs_4bet/vs4b_sb_vs_co.json',
  'charts/vs_4bet/vs4b_sb_vs_btn.json',
];

const PRECACHE = [...APP_SHELL, ...CHART_FILES];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(VERSION);
    // addAll is atomic; if any single request fails the whole install fails,
    // so we fetch individually and ignore per-file failures to keep the SW
    // installable on first run even if the network is partial.
    await Promise.all(PRECACHE.map(async (url) => {
      try {
        const res = await fetch(url, { cache: 'reload' });
        if (res.ok) await cache.put(url, res);
      } catch { /* ignore — a later request will refetch */ }
    }));
    self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter(n => n !== VERSION).map(n => caches.delete(n)));
    await self.clients.claim();
  })());
});

// --------------------------- strategy helpers ---------------------------

function shouldNetworkFirst(req, url) {
  if (req.mode === 'navigate') return true;
  const p = url.pathname.toLowerCase();
  return p.endsWith('.js')
      || p.endsWith('.css')
      || p.endsWith('.webmanifest')
      || p.endsWith('.json');
}

async function cachePut(cache, req, res) {
  if (!res || !res.ok) return;
  if (res.type !== 'basic' && res.type !== 'default') return;
  try { await cache.put(req, res.clone()); } catch {}
}

// Race a fetch against a timeout. Resolves to the Response if the network
// wins before the timeout, otherwise rejects. Network errors reject too.
function fetchWithTimeout(req, ms) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('network timeout')), ms);
    fetch(req).then(
      (res) => { clearTimeout(t); resolve(res); },
      (err) => { clearTimeout(t); reject(err); },
    );
  });
}

async function networkFirst(req, cache) {
  // GitHub Pages serves `Cache-Control: max-age=600` on every asset, so a
  // default-mode fetch(req) can be answered by the browser's HTTP cache for
  // up to 10 minutes after a deploy — the SW would see that stale body as
  // "network" and the user would get yesterday's build on first launch.
  // Fetching with cache: 'no-cache' forces a conditional revalidation
  // (cheap 304 when unchanged) so a fresh deploy is picked up immediately.
  // Navigation requests can't be rewrapped with new Request(req, {...}) in
  // some browsers (mode 'navigate' isn't copyable), so for navigations we
  // rebuild from the URL instead. The cache key stays the original `req`.
  let bypass;
  if (req.mode === 'navigate') {
    bypass = new Request(req.url, {
      cache: 'no-cache',
      credentials: req.credentials,
      headers: req.headers,
    });
  } else {
    bypass = new Request(req, { cache: 'no-cache' });
  }
  try {
    const res = await fetchWithTimeout(bypass, NETWORK_TIMEOUT_MS);
    await cachePut(cache, req, res);
    return res;
  } catch {
    const cached = await cache.match(req);
    if (cached) return cached;
    // Navigation fallback: index.html keeps the app bootable offline.
    if (req.mode === 'navigate') {
      const shell = await cache.match('./index.html') || await cache.match('./');
      if (shell) return shell;
    }
    return new Response('Offline and not cached.', {
      status: 503, headers: { 'Content-Type': 'text/plain' },
    });
  }
}

async function cacheFirst(req, cache) {
  const cached = await cache.match(req);
  const refresh = fetch(req).then(async (res) => {
    await cachePut(cache, req, res);
    return res;
  }).catch(() => null);
  if (cached) {
    // Fire-and-forget refresh so icons update eventually without blocking.
    refresh.catch(() => {});
    return cached;
  }
  const fresh = await refresh;
  if (fresh) return fresh;
  return new Response('Offline and not cached.', {
    status: 503, headers: { 'Content-Type': 'text/plain' },
  });
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith((async () => {
    const cache = await caches.open(VERSION);
    if (shouldNetworkFirst(req, url)) return networkFirst(req, cache);
    return cacheFirst(req, cache);
  })());
});
