# Torus Session Manager Swift

> Web3Auth is where passwordless auth meets non-custodial key infrastructure for Web3 apps and wallets. By aggregating OAuth (Google, Twitter, Discord) logins, different wallets and innovative Multi Party Computation (MPC) - Web3Auth provides a seamless login experience to every user on your application.

Torus Session Manager Swift is the SDK that gives you two session modules:

1. **StorageManager** — legacy encrypted metadata storage with a server-backed hex session ID.
2. **AuthSessionManager + HttpClient** — token-based sessions with refresh, logout, and authenticated HTTP.

## Features

- Multi network support
- Keychain Support
- Build on async await
- Per-instance session server URL (no static global)
- Optional local session-data cache
- Authenticated HTTP client with 401 retry and refresh deduplication

## Requirements

- iOS 14 or above is required
- macOS 11 or above for Swift Package tests

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/Web3Auth/session-manager-swift.git", from: "7.0.0")
```

### CocoaPods

```ruby
pod 'TorusSessionManager', '~> 7.0.0'
```

## Storage Manager

`StorageManager` creates, authorizes, updates, and invalidates server-backed sessions using a hex session ID.

`sessionServerBaseUrl` is **required**. Use the documented constant `SESSION_SERVER_API_URL` (`https://api.web3auth.io/session-service`) unless you host your own session service. The base URL is the **root only** — paths `/v2/store/set`, `/v2/store/get`, and `/v2/store/update` are appended for you. Do not include a `/v2/` suffix.

```swift
import SessionManager

let storage = StorageManager<MySessionData>(
    sessionServerBaseUrl: SESSION_SERVER_API_URL,
    sessionNamespace: "my-app",
    sessionId: try StorageManager<MySessionData>.generateRandomSessionKey(),
    useLocalStorage: false
)

let sessionId = try await storage.createSession(data: MySessionData(userId: "123"))
let sessionData = try await storage.authorizeSession(origin: "")
try await storage.updateSession(data: MySessionData(userId: "123"))
_ = try await storage.invalidateSession()
```

`invalidateSession()` clears the optional local cache and resets the in-memory session ID.

## Auth Session Manager

`AuthSessionManager` stores access / refresh / ID tokens, refreshes them, and decrypts `session_data`.

```swift
import SessionManager

let session = AuthSessionManager<MySessionData>(
    apiClientConfig: ApiClientConfig(baseURL: "https://auth.example.com")
)

try await session.setTokens(AuthTokens(
    sessionId: sessionId,
    accessToken: accessToken,
    refreshToken: refreshToken,
    idToken: idToken
))

if let sessionData = try await session.authorize() {
    print(session.isAuthenticated()) // true
}

try await session.logout()
```

Tokens are stored with key format `{storageKeyPrefix}:{STORAGE_KEYS.*}` (default prefix `"w3a"`). By default all tokens use `KeychainStorageAdapter`. For tests, pass `MemoryStorageAdapter`.

## HttpClient

`HttpClient` attaches a Bearer token when `authenticated` is true and retries once on 401 after a deduplicated refresh.

```swift
let http = HttpClient(session)

let users: [User] = try await http.get("https://api.example.com/users", options: HttpClientRequestOptions(authenticated: true))
let created: User = try await http.post("https://api.example.com/users", data: payload, options: HttpClientRequestOptions(authenticated: true))
```

Unauthenticated requests omit the Authorization header and do not retry 401s.

## Migration from SessionManager (v6)

| v6 | v7 |
| --- | --- |
| `SessionManager` | `StorageManager<T>` (`typealias SessionManager` is deprecated) |
| Optional `sessionServerBaseUrl` defaulting to `https://session.web3auth.io/v2/` | **Required** `sessionServerBaseUrl` (root URL, no `/v2/` suffix) |
| Paths relative to `/v2/` | SDK appends `/v2/store/set`, `/v2/store/get`, `/v2/store/update` |
| No `updateSession` | `updateSession(data:)` via `PUT /v2/store/update` |
| `invalidateSession()` leaves `sessionId` set | Clears local cache and resets `_sessionId` |
| `generateRandomSessionID()` unprefixed hex | `generateRandomSessionKey()` returns `0x`-prefixed 32-byte hex |
| Static `Router.baseURL` | Per-instance URL; multiple managers can use different hosts |

```swift
// v6
let session = SessionManager(sessionId: id, sessionNamespace: "sfa")

// v7
let session = StorageManager<MyData>(
    sessionServerBaseUrl: SESSION_SERVER_API_URL,
    sessionNamespace: "sfa",
    sessionId: id
)
```

## 🩹 Examples

Checkout the examples for your preferred blockchain and platform in
our [example repository](https://github.com/Web3Auth/session-manager-swift/tree/master/Example)

## 💬 Troubleshooting and Discussions

- Have a look at
  our [GitHub Discussions](https://github.com/Web3Auth/Web3Auth/discussions?discussions_q=sort%3Atop)
  to see if anyone has any questions or issues you might be having.
- Checkout our [Troubleshooting Documentation Page](https://web3auth.io/docs/troubleshooting) to
  know the common issues and solutions
- Join our [Discord](https://discord.gg/web3auth) to join our community and get private integration
  support or help with your integration.
