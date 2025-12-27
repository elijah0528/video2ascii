import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
    plugins: [
        react(),
        {
            name: 'glsl',
            transform(code, id) {
                if (id.endsWith('.glsl')) {
                    return `export default ${JSON.stringify(code)}`
                }
            }
        }
    ],
    resolve: {
        alias: {
            '@': path.resolve(__dirname, '../src')
        }
    }
})
