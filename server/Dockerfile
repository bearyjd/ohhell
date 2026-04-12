# Build stage — compile AOT binary
FROM dart:stable AS build

WORKDIR /app

# Copy workspace pubspec files first for layer caching
COPY pubspec.yaml ./
COPY packages/ohhell_engine/pubspec.yaml packages/ohhell_engine/
COPY packages/ohhell_protocol/pubspec.yaml packages/ohhell_protocol/
COPY server/pubspec.yaml server/
COPY client/pubspec.yaml client/

# Copy source packages
COPY packages/ohhell_engine/lib packages/ohhell_engine/lib
COPY packages/ohhell_protocol/lib packages/ohhell_protocol/lib
COPY server/lib server/lib
COPY server/bin server/bin

RUN dart pub get
RUN dart compile exe server/bin/server.dart -o server/bin/server

# Runtime stage — slim Debian image (supports curl healthcheck)
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/server/bin/server ./server
COPY --from=build /runtime/ /

ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["./server"]
