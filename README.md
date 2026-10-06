# Swaply

Swaply is a tiny web app for listing just about anything you like. It's similar to Craigslist, but more ✨ asethetic ✨.

## Why?

This was a project for me to learn Gleam! If you want to take a look at what a small multi-user web app with a Flask backend and a Gleam frontend looks like, feel free to take a look at the code. :)

## Developing

If you're using VS Code, just open the folder in a devcontainer running through your Dockerfile-compatible container manager of choice. If not, I reccomend developing in a container using the provided Dockerfile.

This project uses [`uv`](https://github.com/astral-sh/uv) for Python dependency and version management, and [`mise`](https://mise.jdx.dev/) for NodeJS and NPM version management. It also requires the [Gleam](https://gleam.run/) toolchain to be installed to compile the frontend code.
