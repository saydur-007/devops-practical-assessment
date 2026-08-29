# Service A multi-stage Dockerfile
# Builder stage: use official Node.js image to build and install production deps
FROM node:20-alpine AS builder
WORKDIR /app

# Copy package manifests first to leverage Docker layer caching
COPY package.json package-lock.json ./

# Install production dependencies only
ENV NODE_ENV=production
RUN npm ci --only=production

# Copy only application files needed at runtime
COPY server.js ./

# Final stage: use Distroless Node runtime for minimal attack surface
## Use a minimal official runtime as a pragmatic fallback when a distroless
## Node runtime tag is unavailable in the registry/environment. This runtime
## is smaller than full images and suitable for production, while keeping the
## final image simple. If distroless is required in your environment, replace
## this FROM with the appropriate distroless nodejs tag.
FROM node:20-slim
WORKDIR /app

# Copy application from builder
COPY --from=builder /app /app

# Expose the application port
ENV PORT=8080
EXPOSE 8080

# Run as non-root numeric user (distroless images do not have user creation tools)
# We set the numeric UID to 10001 as required; the image will run the process with that UID.
USER 10001

# Start the Node.js application. Use node directly since distroless has no shell.
ENTRYPOINT ["node", "server.js"]
