# Stage 1: Build Vue frontend
FROM node:20-alpine AS vue-builder

WORKDIR /app/vue_client

# Copy Vue package files
COPY vue_client/package*.json ./

# Install Vue dependencies
RUN npm install

# Copy Vue source
COPY vue_client/ ./

# Build Vue app
RUN npm run build


# Stage 2: Production server
FROM node:20-alpine

WORKDIR /app

# Copy server package files
COPY package*.json ./

# Install production dependencies only
RUN npm install --omit=dev

# Copy server code
COPY server/ ./server/

# Copy built Vue app from builder stage
COPY --from=vue-builder /app/vue_client/dist ./vue_client/dist

# Create data directory
RUN mkdir -p /app/data

# Expose port
EXPOSE 8005

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8005

# Start the server
CMD ["node", "server/server.js"]
