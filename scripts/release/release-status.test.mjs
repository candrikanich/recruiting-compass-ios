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

test('mismatched MARKETING_VERSION → version-conflict', () => {
  assert.equal(stageOf(git({ mainVersion: null, mainVersionConflict: ['1.0', '1.0.1'] }), {}), 'version-conflict');
});
