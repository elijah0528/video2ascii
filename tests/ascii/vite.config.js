import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      'video2ascii': path.resolve(__dirname, '../../dist/index.mjs')
    }
  }
})
