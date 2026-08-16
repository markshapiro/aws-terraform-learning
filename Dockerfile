# ---- Build stage ----
FROM node:22-alpine AS build
WORKDIR /app

# Install deps (including dev deps needed to compile TypeScript)
COPY package.json package-lock.json ./
RUN npm ci

# Compile TypeScript to dist/
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Drop dev dependencies so we copy only production node_modules forward
RUN npm prune --omit=dev

# ---- Runtime stage ----
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

# Run as the built-in non-root user
USER node

COPY --chown=node:node --from=build /app/node_modules ./node_modules
COPY --chown=node:node --from=build /app/dist ./dist
COPY --chown=node:node package.json ./

EXPOSE 3000
CMD ["node", "dist/server.js"]
