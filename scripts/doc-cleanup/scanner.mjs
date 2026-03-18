// scripts/doc-cleanup/scanner.mjs
import { readdir, stat, readFile, writeFile } from 'node:fs/promises'
import { join, basename as pathBasename, relative, dirname as pathDirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { existsSync } from 'node:fs'

const __filename = fileURLToPath(import.meta.url)

const SCAN_DIRS = ['planning', 'docs', 'archived-docs']

// Prefixes: skip any file whose relPath starts with one of these
const SKIP_DIR_PREFIXES = [
  'docs/history/',
  'docs/superpowers/specs/',
  '.claude/',
  'node_modules/',
  '.git/',
  '.nuxt/',
]

// Root-level filenames that are always protected
const SKIP_ROOT_FILES = new Set([
  'CLAUDE.md',
  'CLAUDE.local.md',
  'README.md',
  'SECRETS.md',
  'COMPLETED_WORK.md',
])

// Regex patterns matched against relative path
const SKIP_PATH_PATTERNS = [
  /^planning\/lessons\.md$/i,
]

// Matched against basename (case-insensitive)
const AUTO_DELETE_BASENAME_PATTERNS = [
  /^HANDOFF/i,
  /.*[-_]handoff/i,
  /^FIX_PLAN_/i,
  /.*_RECAP_/i,
  /^DIAGNOSTIC_/i,
  /^FAILURE_/i,
  /^MOCK_/i,
  /^CONTEXT_READY\.md$/i,
  /^NEXT_SESSION_GUIDE\.md$/i,
  /^SESSION_COMPLETION_SUMMARY\.md$/i,
  /^EXECUTION_STATUS_/i,
  /^REVIEW_SUMMARY\.md$/i,
  /^TEST_COVERAGE_REPORT\.md$/i,
  /^COMMIT_MESSAGE\.md$/i,
  /^.*_IMPLEMENTATION_COMPLETE\.md$/i,
  /^.*_IMPLEMENTATION_STATUS\.md$/i,
  /^.*_IMPLEMENTATION_PLAN\.md$/i,
  /^AGENT_TEAM_.*\.md$/i,
]

// Top-level ## Status: heading — must be a markdown H2
const COMPLETION_MARKER_RE = /^##\s+Status:\s*(Complete|Done|Merged|Implemented)\s*$/im

const SIX_WEEKS_MS = 6 * 7 * 24 * 60 * 60 * 1000
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000
const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000

// ─── Core logic (exported for testing) ───────────────────────────────────────

export function isSkipped(relPath, base, mtime) {
  // Directory prefix check
  for (const prefix of SKIP_DIR_PREFIXES) {
    if (relPath.startsWith(prefix)) return true
  }
  // Root-level protected files (no slash in relPath = root level)
  if (!relPath.includes('/') && SKIP_ROOT_FILES.has(base)) return true
  // Path pattern check
  for (const re of SKIP_PATH_PATTERNS) {
    if (re.test(relPath)) return true
  }
  // 7-day recency buffer
  if (Date.now() - mtime < SEVEN_DAYS_MS) return true
  return false
}

export function isAutoDelete(relPath, base, mtime) {
  if (relPath.startsWith('test-results/')) return true
  if (relPath.startsWith('archived-docs/') && Date.now() - mtime > THIRTY_DAYS_MS + 1000) return true
  for (const re of AUTO_DELETE_BASENAME_PATTERNS) {
    if (re.test(base)) return true
  }
  return false
}

export async function isCompress(relPath, base, mtime, fullPath) {
  if (relPath.startsWith('planning/IOS_SPEC')) {
    return { compress: true, reason: 'ios-spec' }
  }
  if (relPath.startsWith('docs/phases/')) {
    return { compress: true, reason: 'phase-doc' }
  }
  if (/^PHASE_[0-9]_/i.test(base)) {
    return { compress: true, reason: 'phase-doc' }
  }
  // Date-stamped + old + top-level completion marker
  const hasDate = /^\d{4}-\d{2}-\d{2}-/.test(base)
  if (hasDate && Date.now() - mtime > SIX_WEEKS_MS) {
    const content = await readFile(fullPath, 'utf8')
    if (COMPLETION_MARKER_RE.test(content)) {
      return { compress: true, reason: 'date+completion' }
    }
  }
  return { compress: false }
}

export function detectPairs(items) {
  // Normalize a basename to a canonical slug by stripping -design / -plan suffixes
  const toSlug = (base) =>
    base
      .replace(/-design\.md$/i, '.md')
      .replace(/-plan\.md$/i, '.md')

  const groups = new Map()
  for (const item of items) {
    const dir = pathDirname(item.relPath)
    const slug = toSlug(item.basename)
    const key = `${dir}/${slug}`
    if (!groups.has(key)) groups.set(key, [])
    groups.get(key).push(item)
  }

  return Array.from(groups.values()).map((group) => ({
    paths: group.map((i) => i.relPath),
    reason: group.length > 1 ? 'paired-date+completion' : group[0].reason,
  }))
}

// ─── Filesystem walker ────────────────────────────────────────────────────────

async function walkDir(dir, repoRoot) {
  const files = []
  if (!existsSync(dir)) return files
  const entries = await readdir(dir, { withFileTypes: true })
  for (const entry of entries) {
    const fullPath = join(dir, entry.name)
    if (entry.isDirectory()) {
      files.push(...(await walkDir(fullPath, repoRoot)))
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      files.push({
        fullPath,
        relPath: relative(repoRoot, fullPath),
        basename: entry.name,
      })
    }
  }
  return files
}

// ─── Main scan ────────────────────────────────────────────────────────────────

export async function scan(repoRoot, repoName) {
  const files = []

  // Scan target directories
  for (const dir of SCAN_DIRS) {
    files.push(...(await walkDir(join(repoRoot, dir), repoRoot)))
  }

  // Scan root *.md files
  const rootEntries = await readdir(repoRoot, { withFileTypes: true }).catch(() => [])
  for (const entry of rootEntries) {
    if (entry.isFile() && entry.name.endsWith('.md')) {
      files.push({
        fullPath: join(repoRoot, entry.name),
        relPath: entry.name,
        basename: entry.name,
      })
    }
  }

  const autoDelete = []
  const compressRaw = []
  const review = []

  for (const file of files) {
    const { mtimeMs } = await stat(file.fullPath)

    if (isSkipped(file.relPath, file.basename, mtimeMs)) continue
    if (isAutoDelete(file.relPath, file.basename, mtimeMs)) {
      autoDelete.push(file.relPath)
      continue
    }

    const { compress, reason } = await isCompress(
      file.relPath,
      file.basename,
      mtimeMs,
      file.fullPath,
    )
    if (compress) {
      compressRaw.push({ ...file, reason })
      continue
    }

    review.push(file.relPath)
  }

  const compress = detectPairs(compressRaw)
  const manifest = {
    scannedAt: new Date().toISOString().split('T')[0],
    repo: repoName,
    autoDelete,
    compress,
    review,
  }

  await writeFile(
    join(repoRoot, '.doc-cleanup-manifest.json'),
    JSON.stringify(manifest, null, 2),
  )

  console.log(`\n✓ Doc scan complete — ${repoName}`)
  console.log(`  Auto-delete : ${autoDelete.length} files`)
  console.log(`  Compress    : ${compressRaw.length} files → ${compress.length} history entries`)
  console.log(`  Review      : ${review.length} files`)
  console.log(`  Manifest    → .doc-cleanup-manifest.json\n`)

  return manifest
}

// ─── CLI entry point ──────────────────────────────────────────────────────────

const isMain = process.argv[1] === fileURLToPath(import.meta.url)
if (isMain) {
  const repoName = process.argv[2] || 'recruiting-compass-ios'
  scan(process.cwd(), repoName).catch((err) => {
    console.error(err)
    process.exit(1)
  })
}
