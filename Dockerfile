FROM --platform=${BUILDPLATFORM} node:20-alpine

FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS builder
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Set environment variables for the build
ENV NEXT_PUBLIC_HOSTED=1 \
    NEXT_TELEMETRY_DISABLED=1

COPY . .

RUN npm install --install-links --include=peer && \
    mkdir -p src/web/nextui/out && \
    npm run build

FROM base AS server

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

# Make Python version configurable with a default of 3.12
ARG PYTHON_VERSION=3.12

# Install Python for python providers, prompts, asserts, etc.
RUN apk add --no-cache python3~=${PYTHON_VERSION} py3-pip py3-setuptools curl && \
    ln -sf python3 /usr/bin/python && \
    npm link promptfoo

ENV API_PORT=3000
ENV HOST=0.0.0.0

EXPOSE 3000

# Set up healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "dist/src/server/index.js"]
