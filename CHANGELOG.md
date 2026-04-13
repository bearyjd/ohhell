# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Single-phone scorekeeper feature (track bids and tricks without a server)
- `PositionalBot` (medium difficulty) and `TrackingBot` (hard difficulty) with `BotDifficulty` enum
- Platform configuration for Android, iOS, and Web (cleartext rules, permissions, manifest)
- Docker Compose setup with multi-stage server AOT build and Flutter web nginx image
- GitHub Actions CI pipeline with auto-tag on merge to main and release artifact builds
- Flutter client WebSocket integration connecting to the game server
- Shared WebSocket protocol package (`ohhell_protocol`) with JSON wire types
- Dart shelf WebSocket game server
- Game engine (`ohhell_engine`) with pure Dart game logic and Flutter UI foundation

### Changed
- Remap Docker web service to port 8888 (rootless Podman cannot bind port 80)

### Fixed
- Docker build compatibility for workspace monorepo context
- Remove unused codegen dependencies that caused build errors
