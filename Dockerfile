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

# Ensure module is properly set up
RUN echo "Setting up Go module..."
RUN go mod tidy
RUN go mod verify

# Verify packages can be found
RUN echo "Verifying packages can be found..."
RUN go list ./build
RUN go list ./server
RUN go list .
RUN echo "All packages verified"

# Build the application with verbose output
RUN echo "Building application..."
RUN go build -v -o ios-safari-remote-debug .
RUN ls -lh ios-safari-remote-debug
RUN echo "Build successful!"

# Build the debugger (you may want to customize the tag)
RUN ./ios-safari-remote-debug build -t releases/Apple/Safari-17.5-macOS-14.5

# Expose port
EXPOSE 8924

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8924/ || exit 1

# Run the server (proxy-host can be overridden via command in docker-compose)
CMD ["./ios-safari-remote-debug", "serve", "--address", "0.0.0.0:8924", "--proxy-host", "127.0.0.1:9221"]

