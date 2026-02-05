import "./styles/main.css"


import { main } from "./src/app.gleam"

document.addEventListener("DOMContentLoaded", () => {
    const dispatch = main({})
})
