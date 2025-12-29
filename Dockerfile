# Single-stage Dockerfile (đơn giản hơn, dùng 1 image Go)
# Nếu muốn image nhỏ hơn, có thể dùng multi-stage build (xem Dockerfile.multi-stage)
FROM golang:1.23-alpine

# Install dependencies
RUN apk add --no-cache git ca-certificates wget

# Set Go environment variables
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOSUMDB=sum.golang.org
ENV CGO_ENABLED=0

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Verify all required directories and files exist
RUN echo "Checking source files..." && \
    ls -la && \
    test -f main.go || (echo "main.go not found!" && exit 1) && \
    test -d build || (echo "build/ not found!" && exit 1) && \
    test -d server || (echo "server/ not found!" && exit 1) && \
    test -d injectedCode || (echo "injectedCode/ not found!" && exit 1) && \
    test -d views || (echo "views/ not found!" && exit 1) && \
    echo "All source directories present"

# Ensure module is properly set up and verify packages can be found
RUN echo "Setting up Go module..." && \
    go mod tidy && \
    go mod verify && \
    echo "Verifying packages can be found..." && \
    go list ./build && \
    go list ./server && \
    go list . && \
    echo "All packages verified"

# Build the application with verbose output
RUN echo "Building application..." && \
    go build -v -o ios-safari-remote-debug . && \
    ls -lh ios-safari-remote-debug && \
    echo "Build successful!"

# Build the debugger (you may want to customize the tag)
RUN ./ios-safari-remote-debug build -t releases/Apple/Safari-17.5-macOS-14.5

# Expose port
EXPOSE 8924

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8924/ || exit 1

# Run the server (proxy-host can be overridden via command in docker-compose)
CMD ["./ios-safari-remote-debug", "serve", "--address", "0.0.0.0:8924", "--proxy-host", "127.0.0.1:9221"]

