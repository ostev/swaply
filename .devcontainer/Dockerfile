ARG VARIANT=3.23
FROM alpine:${VARIANT} AS base
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8


ARG CONTAINER_USER=dev
ARG CONTAINER_GROUP=dev

# Update packages
RUN apk update

# Install dependencies
RUN apk add nodejs npm gleam git curl zsh sqlite openssl

# Set users
RUN adduser --disabled-password --gecos "" ${CONTAINER_USER} -s /bin/zsh
USER ${CONTAINER_USER}
WORKDIR /home/${CONTAINER_USER}

# Disable npm scripts
RUN npm config set ignore-scripts true

# Install uv
COPY --from=ghcr.io/astral-sh/uv:0.9.17 /uv /uvx /bin/ 

# Install python
RUN uv python install 3.14 --default
