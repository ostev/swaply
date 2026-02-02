import { defineConfig } from "vite"

import gleam from "vite-gleam"

export default defineConfig({
    server: {
        port: 3000,
        strictPort: true
    },

    resolve: {
        alias: {
            "@": "/src"
        }
    },

    plugins: [ gleam()]
})
