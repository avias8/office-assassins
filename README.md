# Office Assassins (iOS Game Starter)

Realtime 2D multiplayer game starter built with:
- SwiftUI client (`client-swift`)
- SpacetimeDB module in Rust (`spacetimedb`)

This repo is a standalone template for building an iOS-first realtime multiplayer game.

## Prerequisites

- Xcode 16+ (iOS 17 SDK)
- Swift 6.2+
- Rust + Cargo
- SpacetimeDB CLI (`spacetime`)

## Quick Start

From repo root:

```bash
./scripts/bootstrap.sh
./scripts/publish-prod.sh
```

Or with `make`:

```bash
make bootstrap
make run
```

Then open the client in Xcode:

```bash
cd client-swift
open Package.swift
```

Run `OfficeAssassinsClient` on an iOS simulator/device.

## Daily Dev Workflow

1. Publish latest module to production DB:

```bash
./scripts/publish-prod.sh
```

2. Run the app from Xcode (`OfficeAssassinsClient`).
3. Confirm environment is `Prod DB` in the title screen (now default).
4. Iterate on game logic:
- Client/UI code: `client-swift/Sources/OfficeAssassinsClient`
- Authoritative multiplayer logic: `spacetimedb/src/lib.rs`

## Project Layout

- `client-swift/`: SwiftUI game client and generated SpacetimeDB bindings.
- `spacetimedb/`: Rust tables/reducers for multiplayer state and gameplay rules.
- `scripts/bootstrap.sh`: one-time validation/build setup.
- `scripts/publish-prod.sh`: publish module to `maincloud` production DB.
- `scripts/run-local.sh`: optional local-only server + publish workflow for development testing.

## Verification Commands

```bash
# Client
cd client-swift && swift build

# Server module
cd spacetimedb && cargo check
```

Or:

```bash
make build-client
make check-server
```

## Notes

- Production publish target is `maincloud` with DB name `officeassassins` (override in `./scripts/publish-prod.sh <db_name>`).
- App default connection environment is `Prod DB`.
- Local server endpoint remains available at `http://127.0.0.1:3000` for optional local testing.
- If you plan to re-theme/rename the game, start by updating app-facing names and assets in `client-swift/Sources/OfficeAssassinsClient/Resources`.
