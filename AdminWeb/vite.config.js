import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
    plugins: [react()],
    // When built, output goes into ../Backend/admin/dist
    // to be served as static files by FastAPI at /admin
    build: {
        outDir: '../Backend/admin/dist',
        emptyOutDir: true,
    },
    server: {
        port: 5173,
        proxy: {
            '/api': {
                target: 'http://192.168.1.115:8000',
                changeOrigin: true,
            },
        },
    },
})
