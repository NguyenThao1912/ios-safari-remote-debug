# Build stage
FROM golang:1.21.6-alpine AS builder

# Install git and dependencies for building
RUN apk add --no-cache git

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN go build -o ios-safari-remote-debug .

# Build the debugger (you may want to customize the tag)
RUN ./ios-safari-remote-debug build -t releases/Apple/Safari-17.5-macOS-14.5

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /app

# Copy built binary and dist folder from builder
COPY --from=builder /app/ios-safari-remote-debug .
COPY --from=builder /app/dist ./dist

# Expose port
EXPOSE 8924

# Run the server (proxy-host can be overridden via command in docker-compose)
CMD ["./ios-safari-remote-debug", "serve", "--address", "0.0.0.0:8924", "--proxy-host", "127.0.0.1:9221"]

