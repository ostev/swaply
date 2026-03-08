# Swaply

Swaply is a tiny web app for listing just about anything you like. It's similar to Craigslist, but more ✨ asethetic ✨.

## Developing

If you're using VS Code, just open the folder in a devcontainer running through your Dockerfile-compatible container manager of choice. If not, I reccomend developing in a container using the provided Dockerfile.

This project uses [`uv`](https://github.com/astral-sh/uv) for Python dependency and version management, and [`mise`](https://mise.jdx.dev/) for NodeJS and NPM version management. It also requires the [Gleam](https://gleam.run/) toolchain to be installed to compile the frontend code.
