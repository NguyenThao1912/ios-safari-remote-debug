# Build stage
FROM golang:1.21.6-alpine AS builder

# Install git and dependencies for building
RUN apk add --no-cache git ca-certificates

# Set Go environment variables
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOSUMDB=sum.golang.org
ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Verify and download dependencies
RUN go mod verify && \
    go mod download && \
    go mod tidy

# Copy source code
COPY . .

# Verify Go module and dependencies
RUN go mod verify && \
    go list -m all

# Build the application with verbose output
RUN echo "Building application..." && \
    go build -v -o ios-safari-remote-debug . && \
    ls -lh ios-safari-remote-debug && \
    echo "Build successful!"

# Build the debugger (you may want to customize the tag)
RUN ./ios-safari-remote-debug build -t releases/Apple/Safari-17.5-macOS-14.5

# Runtime stage
FROM alpine:latest

# Install ca-certificates and wget (for healthcheck)
RUN apk --no-cache add ca-certificates wget

WORKDIR /app

# Copy built binary and dist folder from builder
COPY --from=builder /app/ios-safari-remote-debug .
COPY --from=builder /app/dist ./dist

# Verify files are copied
RUN ls -la && \
    test -f ios-safari-remote-debug && \
    test -d dist && \
    echo "All files copied successfully"

# Expose port
EXPOSE 8924

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8924/ || exit 1

# Run the server (proxy-host can be overridden via command in docker-compose)
CMD ["./ios-safari-remote-debug", "serve", "--address", "0.0.0.0:8924", "--proxy-host", "127.0.0.1:9221"]

