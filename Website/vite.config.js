import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

/**
 * VITE_ARTIFACT=1 produces a portable build: relative asset URLs and hash
 * routing, so the same site works when it is served from a sub-path on a host
 * with no single-page fallback. The default build is the one you deploy to
 * balajiautomobiles.in — absolute paths and clean URLs.
 */
const portable = !!process.env.VITE_ARTIFACT;

export default defineConfig({
  base: portable ? './' : '/',
  plugins: [react()],
  server: { port: 5173, host: '127.0.0.1' },
  preview: { port: 4173, host: '127.0.0.1' },
  build: {
    outDir: portable ? 'dist-portable' : 'dist',
    assetsDir: 'build',
    sourcemap: false,
    target: 'es2020',
  },
});
