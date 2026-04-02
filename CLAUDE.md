# CLAUDE.md — Ghostenger

This file provides guidance for AI assistants working in this codebase.

## Project Overview

**Ghostenger** is a secure iOS messenger application built with privacy as a first principle. All messages are end-to-end encrypted (E2EE) using the Signal Protocol (X3DH key exchange + Double Ratchet algorithm), meaning the server never has access to plaintext message content. Transport is additionally protected by TLS.

**Core security guarantee**: A Ghostenger server operator cannot read user messages, even with full database access.

---

## Repository Structure

```
Ghostenger/
├── iOS/                          # Xcode project (SwiftUI iOS app)
│   ├── Ghostenger.xcodeproj
│   ├── Ghostenger/
│   │   ├── App/                  # App entry point, scene lifecycle, DI root
│   │   ├── Features/             # Feature modules (vertical slices)
│   │   │   ├── Auth/             # Registration, login, key generation
│   │   │   ├── Chat/             # Conversation list, message thread, composer
│   │   │   ├── Contacts/         # Contact discovery, adding contacts
│   │   │   └── Settings/         # Profile, security settings, sessions
│   │   ├── Core/                 # Shared infrastructure
│   │   │   ├── Crypto/           # E2EE: X3DH, Double Ratchet, key storage
│   │   │   ├── Network/          # WebSocket client, REST API client
│   │   │   ├── Storage/          # Encrypted local DB (CoreData + SQLCipher)
│   │   │   └── Models/           # Shared Swift value types / DTOs
│   │   └── Resources/            # Assets, localization strings
│   └── GhostengerTests/          # Unit and integration tests (XCTest)
├── Server/                       # Vapor backend (Swift)
│   ├── Package.swift
│   ├── Sources/
│   │   └── App/
│   │       ├── Controllers/      # Thin route handlers — no business logic
│   │       ├── Models/           # Fluent ORM models (PostgreSQL)
│   │       ├── Migrations/       # Versioned Fluent migrations
│   │       ├── Services/         # Business logic, orchestration
│   │       └── WebSocket/        # Real-time WebSocket message handlers
│   └── Tests/                    # Vapor app tests (XCTest)
├── Shared/
│   └── Protocol/                 # JSON message format specs (language-agnostic)
├── docker-compose.yml            # PostgreSQL + Redis for local development
└── CLAUDE.md                     # This file
```

---

## Tech Stack

| Component | Technology | Notes |
|---|---|---|
| iOS UI | SwiftUI | Target iOS 16+, use `async/await` throughout |
| Backend | Swift + Vapor 4 | All routes `async throws` |
| Real-time | WebSockets (Vapor) | One persistent connection per client session |
| Primary DB | PostgreSQL 15 | Via Fluent ORM — no raw SQL in app code |
| Cache / PubSub | Redis 7 | Sessions, online presence, message fanout |
| Encryption | Signal Protocol | X3DH (key agreement) + Double Ratchet (messaging) |
| Transport | TLS 1.3 | All HTTP and WebSocket connections |
| Local storage | CoreData + SQLCipher | On-device encrypted message database |
| Linting | SwiftLint | Enforced via Xcode build phase and CI |

---

## Development Setup

### Prerequisites

- Xcode 15+
- Swift 5.9+
- Docker + Docker Compose
- `swift` CLI (for server development without Xcode)

### Start the backend dependencies

```bash
docker-compose up -d   # starts PostgreSQL and Redis
```

### Run the Vapor server

```bash
cd Server
swift run App serve --hostname 0.0.0.0 --port 8080
```

### Run migrations

```bash
cd Server
swift run App migrate
```

### iOS app

Open `iOS/Ghostenger.xcodeproj` in Xcode. Select a simulator or device and run. The app connects to `localhost:8080` in debug builds (configured via `Config/debug.xcconfig`).

### Environment variables (Server)

| Variable | Description | Default |
|---|---|---|
| `DATABASE_URL` | PostgreSQL connection string | `postgres://ghost:ghost@localhost:5432/ghostenger` |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379` |
| `APP_ENV` | `development` / `production` | `development` |
| `JWT_SECRET` | Secret for signing auth tokens | — (required in prod) |

---

## Architecture

### Authentication Flow

1. Client generates an identity key pair (Ed25519) locally — **private key never leaves the device**
2. Client registers with server, uploading: username, public identity key, signed prekey bundle (for X3DH)
3. Server issues a JWT for subsequent REST/WebSocket authentication
4. Client stores private keys in the iOS Keychain (not CoreData, not UserDefaults)

### End-to-End Encryption (E2EE)

Ghostenger uses a simplified Signal Protocol implementation:

- **X3DH** (Extended Triple Diffie-Hellman): Establishes a shared secret between two parties without the server learning it
- **Double Ratchet**: Derives per-message encryption keys; provides forward secrecy and break-in recovery
- The server stores and delivers **prekey bundles** (public keys only) to facilitate session establishment
- The server stores **ciphertext only** — it cannot decrypt messages

**Rule for AI assistants**: Never suggest code that sends private keys, session keys, or ratchet state to the server. These must remain on-device at all times.

### WebSocket Protocol

Each authenticated client opens a single WebSocket connection at `/ws`. Messages are JSON-encoded envelopes:

```json
{
  "type": "message.send" | "message.ack" | "presence.update" | "typing" | ...,
  "id": "<uuid>",
  "payload": { ... }
}
```

The server fans out messages to recipient connections via Redis PubSub (so multiple server instances work correctly).

### Database Overview

**PostgreSQL models** (Fluent ORM):

| Table | Description |
|---|---|
| `users` | User accounts, public identity key |
| `prekey_bundles` | One-time prekeys and signed prekeys for X3DH |
| `conversations` | Metadata: participants, created_at |
| `messages` | Ciphertext, sender, timestamp, conversation_id |
| `devices` | User devices and their push notification tokens |
| `sessions` | Server-side session metadata (NOT crypto sessions) |

**Redis key patterns** (`ghost:{entity}:{id}:{field}`):

| Key | Value | TTL |
|---|---|---|
| `ghost:session:{userId}:{deviceId}` | JWT / session data | 30 days |
| `ghost:presence:{userId}` | `online` / `offline` + last seen | 5 min |
| `ghost:typing:{conversationId}:{userId}` | `1` | 5 sec |
| `ghost:pubsub:user:{userId}` | Redis channel for message fanout | — |

---

## Key Conventions

### Swift (iOS + Server)

- **Indentation**: 4 spaces (no tabs)
- **Types**: Prefer `final class`; use `struct` for value types/DTOs
- **Concurrency**: `async/await` everywhere — no completion handlers, no Combine for async work
- **Error handling**: Define domain-specific `Error` enums; never swallow errors silently
- **Naming**: Swift API Design Guidelines — `camelCase` for vars/funcs, `PascalCase` for types
- **Imports**: No unused imports; group as: stdlib → third-party → internal modules
- **SwiftLint**: Fix all warnings before committing; do not suppress rules without a comment explaining why

### iOS Feature Modules (SwiftUI)

Each feature in `Features/` follows this structure:

```
Features/Chat/
├── ChatView.swift          # SwiftUI view
├── ChatViewModel.swift     # @Observable or ObservableObject
├── ChatService.swift       # Business logic, calls Core/ infrastructure
└── Models/                 # Feature-local types
```

- Views are dumb — no business logic, no direct network calls
- ViewModels own state and coordinate with Services
- Services call `Core/Network/` or `Core/Storage/` — never URLSession directly

### Vapor Controllers

Controllers are thin — they validate input, call a Service, and return a response:

```swift
// Good
func sendMessage(req: Request) async throws -> MessageResponse {
    let dto = try req.content.decode(SendMessageDTO.self)
    return try await messageService.send(dto, for: req.auth.require(User.self))
}

// Bad — business logic in controller
func sendMessage(req: Request) async throws -> MessageResponse {
    // ... 50 lines of logic ...
}
```

### Migrations

- Every schema change = a new `AsyncMigration` struct in `Server/Sources/App/Migrations/`
- Named with a timestamp prefix: `CreateUsers_20240101`, `AddDeviceTable_20240215`
- Never modify an existing migration — always add a new one
- Always implement `revert(on:)` for rollback support

---

## Security Rules for AI Assistants

These are hard constraints — do not suggest code that violates them:

1. **Private keys never leave the device.** Identity keys, ratchet keys, and session state are stored only in the iOS Keychain or in-memory. Never serialize them to disk unencrypted or send them over the network.
2. **Server stores ciphertext only.** The `messages` table stores encrypted payloads. Never add server-side decryption logic.
3. **No key derivation on the server.** Shared secrets are derived client-side via X3DH. The server is not involved in key derivation.
4. **Validate all JWT claims server-side** before processing any authenticated request.
5. **Sanitize all user input** — particularly any content that could be used in push notification payloads or stored metadata.
6. **No logging of message content** — server logs must never include plaintext payloads or key material.
7. **TLS required** — all non-localhost connections must use TLS 1.3. Never disable certificate validation.

---

## Testing

### iOS (XCTest)

```bash
# From Xcode: Cmd+U
# Or via xcodebuild:
xcodebuild test -project iOS/Ghostenger.xcodeproj -scheme Ghostenger -destination 'platform=iOS Simulator,name=iPhone 15'
```

- Unit test `Core/Crypto/` exhaustively — correctness of E2EE is critical
- Test ViewModels with mock Services
- Use `XCTestExpectation` / `async` test methods for async code

### Server (XCTest + Vapor's `XCTVapor`)

```bash
cd Server
swift test
```

- Test each Controller endpoint with `app.test(.POST, "/api/messages", ...)`
- Test Service logic with mock repositories
- Test migrations apply and revert cleanly

---

## Git Workflow

### Branches

| Pattern | Purpose |
|---|---|
| `feature/<short-description>` | New features |
| `fix/<short-description>` | Bug fixes |
| `chore/<short-description>` | Tooling, dependencies, CI |
| `claude/<description>` | AI-assisted work |

### Commit Messages (Conventional Commits)

```
feat(chat): add message delivery receipts
fix(crypto): correct ratchet step on out-of-order messages
chore(deps): update Vapor to 4.92.0
```

Types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `ci`

- Scope is optional but encouraged: `(chat)`, `(auth)`, `(crypto)`, `(server)`, `(ios)`
- Keep subject line under 72 characters
- Add body for non-obvious changes

### Pull Requests

- All PRs require passing CI (build + tests) before merge
- Include a brief description of the security implications of any change touching `Core/Crypto/` or server auth

---

## CI / CD (Planned)

- **GitHub Actions**: Build and test on every PR
- iOS: `xcodebuild test` on macOS runner
- Server: `swift build` + `swift test` on Linux runner
- Docker image built and pushed on merge to `main`
