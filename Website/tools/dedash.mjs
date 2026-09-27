/**
 * Reports every em dash left in visitor-facing copy.
 *
 *   node tools/dedash.mjs
 *
 * Rewriting the sentences is a judgement call and stays manual — a blind swap
 * to a comma or a hyphen reads worse than the dash did. This only finds them,
 * and it skips code comments, which nobody visiting the site ever sees.
 */
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';

const ROOTS = ['src', 'index.html'];
const SKIP_DIRS = new Set(['node_modules', 'dist', 'dist-portable']);

function walk(p, out = []) {
  if (statSync(p).isDirectory()) {
    if (SKIP_DIRS.has(path.basename(p))) return out;
    readdirSync(p).forEach((f) => walk(path.join(p, f), out));
    return out;
  }
  if (/\.(jsx?|html|css)$/.test(p)) out.push(p);
  return out;
}

/** Strip block and line comments so only real copy is reported. */
function stripComments(src, file) {
  let s = src.replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, ' '));
  if (!file.endsWith('.css')) {
    s = s.replace(/(^|[^:])\/\/[^\n]*/g, (m, p1) => p1 + ' '.repeat(m.length - p1.length));
  }
  s = s.replace(/<!--[\s\S]*?-->/g, (m) => m.replace(/[^\n]/g, ' '));
  return s;
}

const files = ROOTS.flatMap((r) => walk(r));
let total = 0;

for (const file of files) {
  const raw = readFileSync(file, 'utf8');
  const clean = stripComments(raw, file);
  clean.split('\n').forEach((line, i) => {
    if (!line.includes('—')) return;
    total += 1;
    console.log(`${file}:${i + 1}`);
    console.log(`   ${raw.split('\n')[i].trim().slice(0, 150)}`);
  });
}

console.log(total ? `\n${total} line(s) still contain an em dash.` : '\nNo em dashes in visitor-facing copy.');
process.exit(total ? 1 : 0);
