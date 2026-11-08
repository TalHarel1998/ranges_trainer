// Repo constants + path mapping between the app's chart paths and the paths
// in the GitHub repo. Pure module — no DOM, no fetch.

export const GITHUB_OWNER = 'TalHarel1998';
export const GITHUB_REPO = 'ranges_trainer';
export const GITHUB_BRANCH = 'main';

// The web app serves charts from `./charts/...` through a symlink. In the
// repo, the files actually live under PreflopT/. The GitHub API wants the
// repo path.
export const CHART_APP_PREFIX = 'charts/';
export const CHART_REPO_PREFIX = 'PreflopT/PreflopT/Resources/Charts/';

// The palette is a plain file at `web/palette.json`. On the deployed site it
// is at `./palette.json` (web/* → _site/*). The GitHub API path is below.
export const PALETTE_APP_PATH = 'palette.json';
export const PALETTE_REPO_PATH = 'web/palette.json';

// localStorage keys.
export const TOKEN_STORAGE_KEY = 'preflopt.githubToken.v1';
export const PENDING_WRITES_KEY = 'preflopt.pendingWrites.v1';

// Old palette keys to delete on boot (AC12.2).
export const OLD_PALETTE_KEYS = Object.freeze([
  'preflopt.palette.v1',
  'preflopt.rfiPalette.v1',
]);

// Pending-write TTL (AC14.1).
export const PENDING_TTL_MS = 30 * 60 * 1000;

// Convert an in-app path (what the service worker and loader see) to the
// GitHub repo path. Returns `null` if the path doesn't map to a repo file we
// can edit.
export function appPathToRepoPath(appPath) {
  if (appPath === PALETTE_APP_PATH) return PALETTE_REPO_PATH;
  if (appPath.startsWith(CHART_APP_PREFIX)) {
    return CHART_REPO_PREFIX + appPath.slice(CHART_APP_PREFIX.length);
  }
  return null;
}

export function repoPathToAppPath(repoPath) {
  if (repoPath === PALETTE_REPO_PATH) return PALETTE_APP_PATH;
  if (repoPath.startsWith(CHART_REPO_PREFIX)) {
    return CHART_APP_PREFIX + repoPath.slice(CHART_REPO_PREFIX.length);
  }
  return null;
}

// F18: frozen GTO snapshot of every chart, used by "Restore to GTO" in the
// editor. `charts/defense/bb_vs_btn.json` → `gto/defense/bb_vs_btn.json`.
// These files are never edited by the app; update them only on purpose.
export const GTO_APP_PREFIX = 'gto/';

export function gtoPathFor(appPath) {
  if (!appPath.startsWith(CHART_APP_PREFIX)) throw new Error(`Not a chart path: ${appPath}`);
  return GTO_APP_PREFIX + appPath.slice(CHART_APP_PREFIX.length);
}
