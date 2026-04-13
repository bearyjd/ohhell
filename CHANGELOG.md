# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Modern indigo/amber color palette with Nunito font (family-friendly card game theme)
- Redesigned card widget: larger size (72×100), colored suit accent strip, modern card back
- Fade-in animation on splash screen with ♠♥♦♣ suit fan motif
- Full-width Create Game CTA on home screen with suit fan motif

### Changed
- Polish game screen score display with pill-shaped chips
- Celebratory winner banner with gradient and trophy emoji on score screen
- Extract shared `SuitSymbolsRow` widget from splash and home screens

### Fixed
- Prevent duplicate bid dialogs opening on game screen when Riverpod providers rebuild

## [0.1.2] - 2026-04-12

### Fixed
- Correct web client port in RUNBOOK health check commands (8888, not 80)

## [0.1.1] - 2026-04-12

### Changed
- Sync CONTRIBUTING and RUNBOOK documentation with current codebase state

## [0.1.0] - 2026-04-12

### Added
- Single-phone scorekeeper mode: track bids and tricks for 3–7 players without a server
- Scorekeeper screens: setup, bidding, tricks entry, and leaderboard with share support
- Native share of final scores via share_plus (iOS and Android)

## [0.0.2] - 2026-04-12

### Added
- Scorekeeper feature design specification

## [0.0.1] - 2026-04-12

### Added
- Game engine (`ohhell_engine`) with full Oh Hell rules: dealing, bidding, trick evaluation, scoring
- `PositionalBot` (medium difficulty) and `TrackingBot` (hard difficulty) with `BotDifficulty` enum
- Shared WebSocket protocol package (`ohhell_protocol`) with JSON wire types
- Dart shelf WebSocket game server
- Flutter client with WebSocket integration: host/join rooms, real-time multiplayer
- Platform configuration for Android (cleartext + INTERNET permissions), iOS (local networking), and Web
- Docker Compose setup with multi-stage AOT server build and Flutter web nginx image
- GitHub Actions CI pipeline with auto-tag on merge to main and release artifact builds
- Contributing guide and runbook documentation

### Changed
- Remap Docker web service to port 8888 for rootless Podman compatibility

### Fixed
- Docker build compatibility for workspace monorepo context
- Remove unused codegen dependencies that caused build errors
