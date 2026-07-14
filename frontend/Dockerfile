# Frontend Dockerfile for Messy UI
FROM node:20-alpine AS builder

WORKDIR /app

# Install yarn
RUN corepack enable

# Copy package files
COPY package.json yarn.lock* ./

# Install dependencies
RUN yarn install --frozen-lockfile || yarn install

# Copy application files
COPY . .

# Create empty .env if missing (vite config reads it)
RUN touch .env

# Build the application
RUN yarn build

# Production stage
FROM node:20-alpine

RUN apk add --no-cache bash

WORKDIR /app

# Copy built assets and necessary files for vite preview
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/vite.config.ts ./
COPY --from=builder /app/env.sh ./
# Seed .env with keys so env.sh can override from container env vars
RUN printf 'MESSY_API_URL=\nCORS_DOMAIN=\nPOSTHOG_KEY=\nPOSTHOG_HOST=\nTURNSTILE_SITE_KEY=\n' > .env

ENV NODE_ENV=production

# Run as the non-root user shipped in the node image. It needs to write
# env-config.js into dist/ at startup (env.sh) and rewrite .env, so hand it
# ownership of the app dir.
RUN chown -R node:node /app
USER node

EXPOSE 5000

CMD ["npm", "run", "start-prod"]
