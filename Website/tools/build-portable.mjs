/* Cross-platform wrapper: sets VITE_ARTIFACT then runs the normal Vite build. */
import { spawnSync } from 'node:child_process';

const r = spawnSync('npx', ['vite', 'build'], {
  stdio: 'inherit',
  shell: true,
  env: { ...process.env, VITE_ARTIFACT: '1' },
});
process.exit(r.status ?? 1);
