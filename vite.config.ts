import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

const REQUIRED_PRODUCTION_ENV = [
  'VITE_SUPABASE_URL',
  'VITE_SUPABASE_ANON_KEY',
  'VITE_PUBLIC_SITE_URL',
] as const;

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');

  if (mode === 'production') {
    const missing = REQUIRED_PRODUCTION_ENV.filter((key) => !(env[key] ?? '').trim());
    if (missing.length > 0) {
      throw new Error(
        `[LINK-LAND admin] Missing required environment variables: ${missing.join(', ')}. ` +
          'Set them in Netlify > Site configuration > Environment variables with the Builds scope (or All), then clear cache and redeploy.',
      );
    }
  }

  return {
    plugins: [react()],
    server: { port: 5174 },
    build: {
      outDir: 'dist',
      sourcemap: false,
      chunkSizeWarningLimit: 900,
    },
  };
});
