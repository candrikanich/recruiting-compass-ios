#!/usr/bin/env node
// Read-only snapshot of where an iOS release stands: git (version, tags, notes), App Store Connect
// (version states, phased release) and Xcode Cloud (recent builds). Ends with the current stage and
// the next step. Used by the release skill (.claude/skills/release). Never writes anything.
//
//   node scripts/release/release-status.mjs          # markdown report
//   node scripts/release/release-status.mjs --json   # machine-readable
//
// Auth: App Store Connect API key (same one fastlane uses). ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH
// override the defaults; the .p8 stays outside the repo.

import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { homedir } from 'node:os';
import { pathToFileURL } from 'node:url';

const APP_ID = '6758562332';
const KEY_ID = process.env.ASC_KEY_ID ?? 'XMUY74WLK7';
const ISSUER_ID = process.env.ASC_ISSUER_ID ?? '9359bbe9-c1f5-4821-8314-cce0788f1224';
const KEY_PATH = process.env.ASC_KEY_PATH ?? `${homedir()}/.appstoreconnect/AuthKey_${KEY_ID}.p8`;
const PBXPROJ = 'TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj';
const NOTES = 'fastlane/metadata/en-US/release_notes.txt';
const WHATS_NEW = 'TheRecruitingCompass/TheRecruitingCompass/Features/AppUpdate/Models/WhatsNew.swift';

const REVIEW_STATES = new Set(['WAITING_FOR_REVIEW', 'IN_REVIEW', 'PENDING_APPLE_RELEASE']);
const APPROVED_STATES = new Set([
  'PENDING_DEVELOPER_RELEASE', 'PROCESSING_FOR_APP_STORE', 'READY_FOR_DISTRIBUTION', 'READY_FOR_SALE',
]);
const REJECTED_STATES = new Set(['REJECTED', 'METADATA_REJECTED', 'INVALID_BINARY']);

// ---------- versions ----------

export const parseVersion = (s) => {
  const m = /^(\d+)(?:\.(\d+))?(?:\.(\d+))?$/.exec(String(s ?? '').trim());
  return m ? [Number(m[1]), Number(m[2] ?? 0), Number(m[3] ?? 0)] : null;
};

export const compareVersions = (a, b) => {
  const [x, y] = [parseVersion(a), parseVersion(b)];
  if (!x || !y) return NaN;
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] - y[i];
  return 0;
};

/** "1.0" and "1.0.0" are the same release; tags are always vX.Y.Z. */
export const tagFor = (version) => `v${parseVersion(version)?.join('.') ?? version}`;

// ---------- stage ----------

/**
 * Pure: git facts + App Store Connect facts → { stage, next }.
 * g: { mainVersion, mainVersionConflict, mainHead, lastTag, tags, commitsSinceTag, notesReady }
 * a: { versions: [{ version, state, build, phased }], builds: [{ number, progress, status, commit }] }
 */
export function decideStage(g, a) {
  const main = g.mainVersion;
  if (!main) {
    return {
      stage: 'version-conflict',
      next: `MARKETING_VERSION differs across configurations (${g.mainVersionConflict?.join(', ')}). ` +
        'Fix it with fastlane bump_version.',
    };
  }

  const forMain = a.versions.find((v) => compareVersions(v.version, main) === 0) ?? null;
  const live = a.versions.find((v) => v.state === 'READY_FOR_SALE') ?? null;
  const headBuild = a.builds.find((b) => b.commit && (b.commit.startsWith(g.mainHead) || g.mainHead.startsWith(b.commit)));
  const latestGoodBuild = a.builds.find((b) => b.status === 'SUCCEEDED');

  if (forMain && REJECTED_STATES.has(forMain.state)) {
    return {
      stage: 'rejected',
      next: `${main} was rejected (${forMain.state}). Read Apple's message in App Store Connect → App Review, ` +
        'fix it, then resubmit (with a new build if the app itself changed).',
    };
  }
  if (forMain && REVIEW_STATES.has(forMain.state)) {
    return {
      stage: 'in-review',
      next: `${main} (build ${forMain.build ?? '?'}) is ${forMain.state}. Nothing to do until Apple responds ` +
        "(usually under 48h). Keep merging to main, but don't bump the version until it's approved.",
    };
  }
  if (forMain && APPROVED_STATES.has(forMain.state)) {
    const steps = [];
    if (forMain.state === 'PENDING_DEVELOPER_RELEASE') {
      steps.push(`${main} is approved and waiting for you to release it in App Store Connect.`);
    }
    const phased = forMain.phased;
    if (phased && phased.phasedReleaseState !== 'COMPLETE') {
      steps.push(`Phased release ${phased.phasedReleaseState}, day ${phased.currentDayNumber ?? '-'} of 7: watch Sentry ` +
        '(apple-ios) and Xcode Organizer; pause it in App Store Connect if something breaks.');
    }
    if (!g.tags.includes(tagFor(main))) steps.push(`Tag the commit build ${forMain.build ?? '?'} came from as ${tagFor(main)}.`);
    steps.push('Bump main for the next release: fastlane bump_version type:patch (or minor) on a branch → PR.');
    return { stage: 'released', next: steps.join(' ') };
  }
  if (forMain && forMain.state === 'PREPARE_FOR_SUBMISSION') {
    const build = headBuild?.status === 'SUCCEEDED' ? headBuild : latestGoodBuild;
    return {
      stage: 'ready-to-submit',
      next: `App Store version ${main} is prepared. After smoke-testing build ${build?.number ?? '<N>'} from TestFlight, ` +
        `run: fastlane submit_release build:${build?.number ?? '<N>'}`,
    };
  }
  if (live && compareVersions(main, live.version) <= 0) {
    return {
      stage: 'needs-bump',
      next: `main is still on ${main}, which is already live. Bump it (fastlane bump_version type:patch or minor, ` +
        'on a branch → PR), or every Xcode Cloud upload will be rejected.',
    };
  }
  if (g.commitsSinceTag.length === 0) {
    return { stage: 'nothing-to-release', next: `Nothing has merged since ${g.lastTag}.` };
  }
  if (!g.notesReady) {
    return {
      stage: 'draft-notes',
      next: `Draft What's New for ${main} (whats-new skill), merge it via PR, then prepare the App Store version.`,
    };
  }
  if (!headBuild || headBuild.progress !== 'COMPLETE') {
    return {
      stage: 'waiting-for-build',
      next: `Xcode Cloud hasn't finished building main @ ${g.mainHead} yet. Wait for it, then smoke-test it from TestFlight.`,
    };
  }
  if (headBuild.status !== 'SUCCEEDED') {
    return {
      stage: 'build-failed',
      next: `Xcode Cloud build ${headBuild.number} of main @ ${g.mainHead} ended ${headBuild.status}. ` +
        'Check its logs in App Store Connect → Xcode Cloud.',
    };
  }
  return {
    stage: 'ready-to-prepare',
    next: `Smoke-test build ${headBuild.number} from TestFlight, then run: fastlane prepare_release ` +
      `(creates ${main} in App Store Connect with the notes and phased release on).`,
  };
}

// ---------- git ----------

const git = (...args) => execFileSync('git', args, { encoding: 'utf8' }).trim();
const gitOr = (fallback, ...args) => {
  try { return git(...args); } catch { return fallback; }
};

function gitState() {
  gitOr('', 'fetch', '--quiet', '--tags', 'origin');
  const pbx = git('show', `origin/main:${PBXPROJ}`);
  const versions = [...new Set([...pbx.matchAll(/MARKETING_VERSION = ([0-9.]+);/g)].map((m) => m[1]))];
  const tags = gitOr('', 'tag', '--list', 'v*', '--sort=-version:refname').split('\n').filter(Boolean);
  const lastTag = tags[0] ?? null;
  const range = lastTag ? `${lastTag}..origin/main` : 'origin/main';
  const notes = gitOr('', 'show', `origin/main:${NOTES}`);
  const notesTouched = lastTag ? gitOr('', 'log', '-1', '--format=%h', range, '--', NOTES) !== '' : notes.trim() !== '';
  const mainVersion = versions.length === 1 ? versions[0] : null;
  const p = parseVersion(mainVersion);
  const whatsNew = gitOr('', 'show', `origin/main:${WHATS_NEW}`);
  return {
    mainVersion,
    mainVersionConflict: versions.length > 1 ? versions : null,
    mainHead: git('rev-parse', '--short=8', 'origin/main'),
    lastTag,
    tags,
    commitsSinceTag: gitOr('', 'log', '--first-parent', '--format=%h %s', range).split('\n').filter(Boolean),
    notesText: notes,
    notesReady: notesTouched && notes.trim() !== '',
    whatsNewEntry: p ? whatsNew.includes(`AppVersion(major: ${p[0]}, minor: ${p[1]}, patch: ${p[2]})`) : false,
  };
}

// ---------- App Store Connect ----------

function ascToken() {
  const key = readFileSync(KEY_PATH, 'utf8');
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const header = b64({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' });
  const payload = b64({ iss: ISSUER_ID, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' });
  const sig = createSign('SHA256').update(`${header}.${payload}`).sign({ key, dsaEncoding: 'ieee-p1363' }).toString('base64url');
  return `${header}.${payload}.${sig}`;
}

async function asc(path, token) {
  const res = await fetch(`https://api.appstoreconnect.apple.com${path}`, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`ASC ${res.status} for ${path.split('?')[0]}: ${(await res.text()).slice(0, 200)}`);
  return res.json();
}

async function ascState(token) {
  const versions = await asc(
    `/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=5` +
      '&fields[appStoreVersions]=versionString,appStoreState,releaseType,build,appStoreVersionPhasedRelease' +
      '&include=build,appStoreVersionPhasedRelease&fields[builds]=version' +
      '&fields[appStoreVersionPhasedReleases]=phasedReleaseState,currentDayNumber',
    token,
  );
  const included = new Map((versions.included ?? []).map((i) => [`${i.type}:${i.id}`, i.attributes]));
  const rel = (v, name) => {
    const d = v.relationships?.[name]?.data;
    return d ? included.get(`${d.type}:${d.id}`) ?? null : null;
  };

  const product = await asc(`/v1/apps/${APP_ID}/ciProduct?fields[ciProducts]=name`, token);
  const workflows = await asc(`/v1/ciProducts/${product.data.id}/workflows?fields[ciWorkflows]=name`, token);
  const runs = (await Promise.all(workflows.data.map(async (wf) => {
    const r = await asc(
      `/v1/ciWorkflows/${wf.id}/buildRuns?limit=5&sort=-number` +
        '&fields[ciBuildRuns]=number,executionProgress,completionStatus,sourceCommit,createdDate',
      token,
    );
    return r.data.map((b) => ({
      workflow: wf.attributes.name,
      number: b.attributes.number,
      progress: b.attributes.executionProgress,
      status: b.attributes.completionStatus,
      commit: b.attributes.sourceCommit?.commitSha?.slice(0, 8) ?? null,
      created: b.attributes.createdDate,
    }));
  }))).flat().sort((x, y) => y.number - x.number);

  return {
    versions: versions.data.map((v) => ({
      version: v.attributes.versionString,
      state: v.attributes.appStoreState,
      releaseType: v.attributes.releaseType,
      build: rel(v, 'build')?.version ?? null,
      phased: rel(v, 'appStoreVersionPhasedRelease'),
    })),
    builds: runs.slice(0, 5),
  };
}

// ---------- report ----------

function render(g, a, ascError, decision) {
  const lines = ['# Release status', '', `**Stage:** \`${decision.stage}\``, `**Next:** ${decision.next}`, ''];
  lines.push('## Git (origin/main)');
  lines.push(`- MARKETING_VERSION ${g.mainVersion ?? `conflict: ${g.mainVersionConflict}`} · head ${g.mainHead} · ` +
    `last tag ${g.lastTag ?? 'none'}`);
  lines.push(`- Commits since ${g.lastTag ?? 'start'}: ${g.commitsSinceTag.length}`);
  for (const c of g.commitsSinceTag.slice(0, 15)) lines.push(`  - ${c}`);
  const firstLine = g.notesText.trim().split('\n')[0];
  lines.push(`- release_notes.txt: ${firstLine ? `"${firstLine.slice(0, 80)}"` : '(empty)'} — ` +
    (g.notesReady ? 'written for this release' : 'not written for this release yet'));
  lines.push(`- WhatsNewCatalog entry for ${g.mainVersion}: ${g.whatsNewEntry ? 'yes' : 'no'}`, '');
  lines.push('## App Store Connect');
  if (ascError) lines.push(`- error: ${ascError}`);
  for (const v of a.versions) {
    const ph = v.phased ? ` · phased ${v.phased.phasedReleaseState} day ${v.phased.currentDayNumber ?? '-'}` : '';
    lines.push(`- ${v.version}: ${v.state} · build ${v.build ?? '-'} · ${v.releaseType ?? ''}${ph}`);
  }
  lines.push('', '## Xcode Cloud (latest builds)');
  for (const b of a.builds) {
    lines.push(`- #${b.number} ${b.workflow}: ${b.progress}${b.status ? `/${b.status}` : ''} · ` +
      `commit ${b.commit ?? '-'} · ${b.created?.slice(0, 16)}`);
  }
  return lines.join('\n');
}

async function main() {
  const g = gitState();
  let a = { versions: [], builds: [] };
  let ascError = null;
  try {
    a = await ascState(ascToken());
  } catch (e) {
    ascError = e.message;
  }
  const decision = ascError
    ? { stage: 'unknown', next: `Couldn't reach App Store Connect (${ascError}). Check the API key at ${KEY_PATH}.` }
    : decideStage(g, a);

  if (process.argv.includes('--json')) {
    console.log(JSON.stringify({ git: g, appStoreConnect: { ...a, error: ascError }, ...decision }, null, 2));
  } else {
    console.log(render(g, a, ascError, decision));
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) await main();
