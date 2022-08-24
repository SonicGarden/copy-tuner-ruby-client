import { defineConfig } from 'vite'

// https://vitejs.dev/config/
export default defineConfig({
  build: {
    outDir: './app/assets',
    lib: {
      entry: 'src/main.ts',
      formats: ['es'],
    },
    rollupOptions: {
      output: {
        entryFileNames: `javascripts/copytuner.js`,
        assetFileNames: `stylesheets/copytuner.[ext]`,
      },
    },
  },
})
