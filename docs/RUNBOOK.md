# Runbook

## Deployment

### Docker Compose (recommended)

```bash
# Pull latest and restart
git pull
docker compose build --no-cache
docker compose up -d

# Verify
curl http://localhost/         # web client
curl http://localhost:8080/health   # server health
```

### Manual (server only)

```bash
dart compile exe server/bin/server.dart -o server/bin/server
PORT=8080 ./server/bin/server
```

## Health checks

| Check | Command | Expected |
|-------|---------|---------|
| Server health | `curl http://localhost:8080/health` | `ok` (200) |
| WebSocket | Connect to `ws://localhost:8080/ws`, send `{"type":"join_room","payload":{"playerName":"test"}}` | Receives `room_joined` |
| Web client | `curl -s http://localhost/ \| grep '<title>'` | `<title>Oh Hell</title>` |

Docker Compose runs the health check every 30 seconds; the web service waits for `server` to be healthy before starting.

## Common issues

### Server won't start — port already in use

```bash
# Find what's using 8080
ss -tlnp | grep 8080
# Kill it or change PORT env var
PORT=9000 dart run server/bin/server.dart
```

### Client can't connect to WebSocket

1. Verify the server is running: `curl http://localhost:8080/health`
2. Check the host field in the app matches the server address
3. On Android emulator, use `10.0.2.2:8080` instead of `localhost`
4. On iOS simulator, `localhost` works; for device use the LAN IP

### Docker build fails — workspace context error

The Dockerfiles require being built from the **repo root**, not the subdirectory:

```bash
# Correct
docker build -f server/Dockerfile -t ohhell-server .

# Wrong (missing workspace context)
cd server && docker build -t ohhell-server .
```

### Flutter analyze reports missing generated files

```bash
dart pub get
dart run build_runner build --delete-conflicting-outputs -C client
```

## Rollback

```bash
# Find the previous working image
docker images ohhell-server

# Roll back to a specific tag
docker compose down
docker tag ohhell-server:previous ohhell-server:latest
docker compose up -d
```

Or revert to a previous git tag and rebuild:

```bash
git checkout v1.0.0
docker compose build
docker compose up -d
```

## Releasing

1. Ensure all tests pass on `main`
2. Tag the release:
   ```bash
   git tag v1.2.0
   git push --tags
   ```
3. GitHub Actions automatically builds:
   - Android APK (`app-release.apk`)
   - Linux binary (`ohhell-linux-x64.tar.gz`)
   - Windows binary (`ohhell-windows-x64.zip`)
   - Web build (Docker image artifact)
4. Review the auto-generated release notes on GitHub and publish

## CI jobs

| Job | Trigger | What it does |
|-----|---------|-------------|
| `engine-tests` | push/PR to main | `dart test packages/ohhell_engine` |
| `protocol-tests` | push/PR to main | `dart test packages/ohhell_protocol` |
| `server-tests` | push/PR to main | `dart test server` |
| `flutter-analyze` | push/PR to main | `flutter analyze client` |
| `flutter-test` | push/PR to main | `flutter test client` |
| `build-android` | tag `v*` | `flutter build apk --release` |
| `build-linux` | tag `v*` | `flutter build linux --release` |
| `build-windows` | tag `v*` | `flutter build windows --release` |
| `build-web` | tag `v*` | `flutter build web --release` |
| `release` | after all builds | Upload artifacts to GitHub Release |
