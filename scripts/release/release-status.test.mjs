// node --test scripts/release/release-status.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { decideStage, compareVersions, tagFor } from './release-status.mjs';

const git = (overrides = {}) => ({
  mainVersion: '1.0.1',
  mainVersionConflict: null,
  mainHead: 'aaaa1111',
  lastTag: 'v1.0.0',
  tags: ['v1.0.0'],
  tagCommits: {},
  commitsSinceTag: ['aaaa111 fix: something (#300)'],
  notesReady: true,
  ...overrides,
});
const live10 = { version: '1.0', state: 'READY_FOR_SALE', build: '32', phased: null };
const build = (number, commit, status = 'SUCCEEDED', progress = 'COMPLETE') => ({ number, commit, status, progress });
const stageOf = (g, a) => decideStage(g, { versions: [], builds: [], ...a }).stage;

test('versions compare numerically and treat 1.0 == 1.0.0', () => {
  assert.equal(compareVersions('1.0', '1.0.0'), 0);
  assert.ok(compareVersions('1.10', '1.9') > 0);
  assert.equal(tagFor('1.0'), 'v1.0.0');
});

test('first release waiting on Apple → in-review', () => {
  const a = { versions: [{ version: '1.0', state: 'WAITING_FOR_REVIEW', build: '32' }] };
  assert.equal(stageOf(git({ mainVersion: '1.0' }), a), 'in-review');
});

test('rejected version → rejected', () => {
  assert.equal(stageOf(git(), { versions: [{ version: '1.0.1', state: 'REJECTED' }] }), 'rejected');
});

test('approved but main not bumped → released (tells you to tag + bump)', () => {
  const r = decideStage(git({ mainVersion: '1.0', tags: [] }), {
    versions: [{ ...live10, phased: { phasedReleaseState: 'ACTIVE', currentDayNumber: 2 } }],
    builds: [],
  });
  assert.equal(r.stage, 'released');
  assert.match(r.next, /day 2 of 7/);
  assert.match(r.next, /v1\.0\.0/);
  assert.match(r.next, /bump_version/);
});

test('already tagged live version does not ask to tag again', () => {
  const r = decideStage(git({ mainVersion: '1.0' }), { versions: [live10], builds: [] });
  assert.doesNotMatch(r.next, /Tag the commit/);
});

test('main older than live (no ASC row for it) → needs-bump', () => {
  assert.equal(stageOf(git({ mainVersion: '0.9' }), { versions: [live10] }), 'needs-bump');
});

test('bumped, nothing merged → nothing-to-release', () => {
  assert.equal(stageOf(git({ commitsSinceTag: [] }), { versions: [live10] }), 'nothing-to-release');
});

test('bumped with changes but no notes → draft-notes', () => {
  assert.equal(stageOf(git({ notesReady: false }), { versions: [live10] }), 'draft-notes');
});

test('notes ready, head still building → waiting-for-build', () => {
  const a = { versions: [live10], builds: [build(36, 'aaaa1111', null, 'RUNNING'), build(35, 'bbbb2222')] };
  assert.equal(stageOf(git(), a), 'waiting-for-build');
});

test('notes ready, head build failed → build-failed', () => {
  assert.equal(stageOf(git(), { versions: [live10], builds: [build(36, 'aaaa1111', 'FAILED')] }), 'build-failed');
});

test('notes ready, head build green → ready-to-prepare with that build', () => {
  const r = decideStage(git(), { versions: [live10], builds: [build(36, 'aaaa1111')] });
  assert.equal(r.stage, 'ready-to-prepare');
  assert.match(r.next, /build 36/);
});

test('version prepared in ASC → ready-to-submit with the head build number', () => {
  const a = { versions: [{ version: '1.0.1', state: 'PREPARE_FOR_SUBMISSION' }, live10], builds: [build(36, 'aaaa1111')] };
  const r = decideStage(git(), a);
  assert.equal(r.stage, 'ready-to-submit');
  assert.match(r.next, /submit_release build:36/);
});

test('prepared version never suggests a build from another commit', () => {
  const a = {
    versions: [{ version: '1.0.1', state: 'PREPARE_FOR_SUBMISSION' }, live10],
    builds: [build(37, 'aaaa1111', null, 'RUNNING'), build(36, 'cccc3333')],
  };
  const r = decideStage(git(), a);
  assert.equal(r.stage, 'waiting-for-build');
  assert.doesNotMatch(r.next, /build:36/);
});

test('approved but held by Apple for an OS release → approved-held (bump allowed)', () => {
  const r = decideStage(git({ mainVersion: '1.0' }), { versions: [{ version: '1.0', state: 'PENDING_APPLE_RELEASE', build: '32' }], builds: [] });
  assert.equal(r.stage, 'approved-held');
  assert.match(r.next, /bump_version/);
});

test('live rollout stays visible after main is bumped', () => {
  const live = { ...live10, version: '1.0.1', phased: { phasedReleaseState: 'ACTIVE', currentDayNumber: 3 } };
  const r = decideStage(git({ mainVersion: '1.0.2', tags: ['v1.0.1', 'v1.0.0'], lastTag: 'v1.0.1', commitsSinceTag: [] }),
    { versions: [live], builds: [] });
  assert.equal(r.stage, 'nothing-to-release');
  assert.match(r.next, /1\.0\.1 rollout: ACTIVE, day 3 of 7/);
});

test('tag pointing at a different commit than the approved build is reported', () => {
  const r = decideStage(
    git({ mainVersion: '1.0', tagCommits: { 'v1.0.0': 'dddd4444' } }),
    { versions: [live10], builds: [build(32, 'eeee5555')] },
  );
  assert.match(r.next, /v1\.0\.0 points at dddd4444 but build 32 came from eeee5555/);
});

test('tag on the approved build commit is not flagged', () => {
  const r = decideStage(
    git({ mainVersion: '1.0', tagCommits: { 'v1.0.0': 'eeee5555' } }),
    { versions: [live10], builds: [build(32, 'eeee5555')] },
  );
  assert.doesNotMatch(r.next, /points at/);
  assert.doesNotMatch(r.next, /Tag the commit/);
});

test('mismatched MARKETING_VERSION → version-conflict', () => {
  assert.equal(stageOf(git({ mainVersion: null, mainVersionConflict: ['1.0', '1.0.1'] }), {}), 'version-conflict');
});
