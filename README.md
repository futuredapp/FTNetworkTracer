# FTNetworkTracer

A Swift library for formatting and masking network trace data with privacy-first design.

[![Swift](https://img.shields.io/badge/Swift-6.1.0+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS-lightgrey.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager)

## Features

- **Privacy-first design**: Configurable data masking with three privacy levels
- **REST & GraphQL support**: Specialized formatting for both API types
- **GraphQL query masking**: Automatic literal masking for privacy-safe analytics
- **Type-safe**: Associated values eliminate impossible states
- **Zero dependencies**: Pure Swift implementation
- **Fully tested**: 45 tests covering formatting, masking, and privacy
- **Swift 6 ready**: Strict concurrency compliant with `Sendable` support

## Requirements

- iOS 14.0+ / macOS 11.0+ / tvOS 14.0+ / watchOS 7.0+
- Swift 6.1.0+
- Xcode 15.0+

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/futuredapp/FTNetworkTracer.git", from: "1.0.0")
```

## Quick Start

```swift
import FTNetworkTracer

// Create a network trace entry
let entry = NetworkTraceEntry(
    type: .request(method: "GET", url: "https://api.example.com/users"),
    headers: ["Authorization": "Bearer token"],
    requestId: UUID().uuidString
)

// Format for console output
let formatted = NetworkTraceFormatter.format(entry)
print(formatted)

// Mask for analytics
let masked = MaskingUtilities.mask(entry, configuration: .private)
```

## Usage

### Creating Entries

```swift
// REST request
let requestEntry = NetworkTraceEntry(
    type: .request(method: "POST", url: "https://api.example.com/users"),
    headers: ["Content-Type": "application/json"],
    body: jsonData,
    requestId: requestId
)

// REST response
let responseEntry = NetworkTraceEntry(
    type: .response(method: "POST", url: "https://api.example.com/users", statusCode: 201),
    headers: responseHeaders,
    body: responseData,
    duration: Date().timeIntervalSince(startTime),
    requestId: requestId
)

// Error
let errorEntry = NetworkTraceEntry(
    type: .error(method: "POST", url: "https://api.example.com/users", error: "Connection timeout"),
    requestId: requestId
)
```

### GraphQL Entries

```swift
let query = """
query GetUser($id: ID!) {
    user(id: $id) {
        name
        email
    }
}
"""

let graphQLEntry = NetworkTraceEntry(
    type: .request(method: "POST", url: "https://api.example.com/graphql"),
    headers: ["Authorization": "Bearer token"],
    requestId: requestId,
    operationName: "GetUser",
    query: query,
    variables: ["id": "123"]
)
```

## Configuration

### Formatter Configuration

Control how entries are formatted for display:

```swift
// Default configuration (headers + body, pretty JSON)
let output = NetworkTraceFormatter.format(entry)

// Compact (no headers or body)
let compact = NetworkTraceFormatter.format(entry, configuration: .compact)

// Custom configuration
let custom = FormatterConfiguration(
    dataDecoder: FormatterConfiguration.defaultDataDecoder,
    includeHeaders: true,
    includeBody: false,
    maxBodyLength: 1000
)
let customOutput = NetworkTraceFormatter.format(entry, configuration: custom)
```

**Preset Configurations:**
- `.default` - Headers, body, and pretty-printed JSON
- `.compact` - Only basic request/response info (no headers or body)
- `.verbose` - Everything with unlimited body length

**Data Decoders:**
- `defaultDataDecoder` - Pretty-prints JSON with UTF8 fallback
- `utf8DataDecoder` - Simple UTF8 string without JSON formatting
- `sizeOnlyDataDecoder` - Shows only data size (e.g., `<1024 bytes>`)

### Masking Configuration

Control how sensitive data is masked for analytics:

```swift
// Sensitive mode (recommended for production)
let masked = MaskingUtilities.mask(entry, configuration: .sensitive)

// Private mode with exceptions
let config = MaskingConfiguration(
    privacy: .private,
    maskQueryLiterals: true,
    unmaskedHeaders: ["Content-Type", "Accept"],
    unmaskedUrlQueries: ["page", "limit"],
    unmaskedBodyParams: ["operationType"]
)
let customMasked = MaskingUtilities.mask(entry, configuration: config)

// No masking (development only)
let unmasked = MaskingUtilities.mask(entry, configuration: .none)
```

**Preset Configurations:**
- `.none` - No masking (development only)
- `.private` - Selective masking with configurable exceptions
- `.sensitive` - Aggressive masking (production recommended)

### Privacy Levels

| Level | Headers | URL Queries | Body | GraphQL Query | GraphQL Variables |
|-------|---------|-------------|------|---------------|-------------------|
| **`.none`** | Preserved | Preserved | Preserved | Literals masked* | Preserved |
| **`.private`** | Masked (with exceptions) | Masked (with exceptions) | Masked (with exceptions) | Literals masked* | Masked (with exceptions) |
| **`.sensitive`** | All `***` | Removed | `nil` | `nil` | `nil` |

\* GraphQL query literal masking is **enabled by default** (`maskQueryLiterals: true`). Can be disabled if needed.

## Privacy & Security

### What Gets Masked

MaskingUtilities automatically masks sensitive data:

- **Headers**: All values masked (exceptions configurable)
- **URL Parameters**: Query parameters masked or removed
- **Body Fields**: All JSON values masked (exceptions configurable)
- **GraphQL Variables**: All values masked (exceptions configurable)
- **GraphQL Query Literals**: String and number literals in queries
  - `"admin"` → `"***"`
  - `123` → `***`
  - Variable references like `$userId` are preserved
  - Query structure is preserved for complexity analysis

### Masking is Irreversible

Once data is masked with `***`, the original value **cannot be recovered**. This ensures sensitive data never leaves your application.

### Case-Insensitive Matching

Unmasked parameter lists use case-insensitive matching:

```swift
// These are all treated as the same key:
unmaskedHeaders: ["content-type"]
// Matches: "Content-Type", "CONTENT-TYPE", "content-type"
```

## Output Examples

### REST Request
```
[REQUEST] [abc12345]
	Method       POST
	URL          https://api.example.com/users
	Timestamp    2025-11-04 15:42:30.123
Headers:
	Content-Type application/json
Body:
 {
  "username": "john",
  "email": "john@example.com"
}
```

### GraphQL Request
```
[REQUEST] [xyz67890]
	Method       POST
	URL          https://api.example.com/graphql
	Timestamp    2025-11-04 15:42:31.456
	Operation    GetUser
Headers:
	Authorization Bearer ***
Query:
	query GetUser($id: ID!) {
	  user(id: $id) {
	    name
	    email
	  }
	}
Variables:
	{
	  "id": "123"
	}
```

### GraphQL Query Masking

When masking for analytics, GraphQL queries have literals automatically masked:

**Original Query:**
```graphql
query GetUser($userId: ID!) {
  user(id: $userId, role: "admin", minAge: 18) {
    name
    email
  }
}
```

**Masked Query:**
```graphql
query GetUser($userId: ID!) {
  user(id: $userId, role: "***", minAge: ***) {
    name
    email
  }
}
```

**Preserved**: Query structure, field selections, variable references (`$userId`), boolean literals, null literals, enum values
**Masked**: String literals, number literals

## Architecture

```
┌──────────────────────┐
│  NetworkTraceEntry   │
└──────────┬───────────┘
           │
     ┌─────┴─────┐
     │           │
     ▼           ▼
┌─────────────┐ ┌─────────────┐
│ Formatter   │ │  Masking    │
│ Utilities   │ │  Utilities  │
└─────────────┘ └─────────────┘
     │                │
     ▼                ▼
Human-readable    Privacy-masked
   output            entry
```

### Key Components

- **`NetworkTraceEntry`**: Core data structure for network events (request/response/error)
- **`EntryType`**: Type-safe enum with associated values (method, URL, status code, error)
- **`NetworkTraceFormatter`**: Formats entries into human-readable strings
- **`FormatterConfiguration`**: Controls formatting options (headers, body, data decoder)
- **`GraphQLFormatter`**: Specialized GraphQL query and variables formatting
- **`RESTFormatter`**: REST body formatting utilities
- **`MaskingUtilities`**: Privacy masking for entries and individual components
- **`MaskingConfiguration`**: Masking rules, privacy level, and exceptions
- **`MaskingPrivacy`**: Privacy levels (none, private, sensitive)

### Design Principles

- **Privacy by Design**: Masking is irreversible once applied
- **Type Safety**: Associated values eliminate impossible states
- **Composable**: Format and mask independently based on needs
- **Configurable**: Presets for common cases, full customization available

## Test Coverage

- **FormattingTests** (12 tests): Entry formatting, configuration presets
- **GraphQLFormatterTests** (11 tests): Query and variable formatting
- **MaskingTests** (13 tests): Privacy levels, query masking, recursive masking
- **RESTFormatterTests** (9 tests): Body formatting with decoders

**Total: 45 tests**

## Integration Example

### NetworkObserver Pattern

```swift
class NetworkLogger {
    func logRequest(_ entry: NetworkTraceEntry) {
        let formatted = NetworkTraceFormatter.format(entry)
        print(formatted)
    }

    func trackRequest(_ entry: NetworkTraceEntry) {
        let masked = MaskingUtilities.mask(entry, configuration: .private)
        analyticsService.track(
            method: masked.method,
            url: masked.url,
            headers: masked.headers,
            body: masked.body
        )
    }
}
```

### URLSession Integration

```swift
class NetworkClient {
    let logger = NetworkLogger()

    func fetch(url: URL) async throws -> Data {
        let requestId = UUID().uuidString
        let request = URLRequest(url: url)
        let startTime = Date()

        // Create and log request entry
        let requestEntry = NetworkTraceEntry(
            type: .request(method: request.httpMethod ?? "GET", url: url.absoluteString),
            headers: request.allHTTPHeaderFields,
            body: request.httpBody,
            requestId: requestId
        )
        logger.logRequest(requestEntry)
        logger.trackRequest(requestEntry)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            // Create and log response entry
            let responseEntry = NetworkTraceEntry(
                type: .response(
                    method: request.httpMethod ?? "GET",
                    url: url.absoluteString,
                    statusCode: httpResponse?.statusCode
                ),
                headers: httpResponse?.allHeaderFields as? [String: String],
                body: data,
                duration: Date().timeIntervalSince(startTime),
                requestId: requestId
            )
            logger.logRequest(responseEntry)
            logger.trackRequest(responseEntry)

            return data
        } catch {
            // Create and log error entry
            let errorEntry = NetworkTraceEntry(
                type: .error(
                    method: request.httpMethod ?? "GET",
                    url: url.absoluteString,
                    error: error.localizedDescription
                ),
                requestId: requestId
            )
            logger.logRequest(errorEntry)
            logger.trackRequest(errorEntry)
            throw error
        }
    }
}
```

## Best Practices

### 1. Use Appropriate Privacy Levels

- **Development**: `.none` or `.private`
- **Staging**: `.private` with specific unmasked fields
- **Production**: `.sensitive`

### 2. Generate Unique Request IDs

```swift
let requestId = UUID().uuidString
// Use the same requestId for request, response, and error entries
```

### 3. Track Response Times

```swift
let startTime = Date()
// Make request...
let responseEntry = NetworkTraceEntry(
    ...,
    duration: Date().timeIntervalSince(startTime),
    ...
)
```

### 4. Be Conservative with Exceptions

Only unmask fields that are truly non-sensitive:
```swift
let config = MaskingConfiguration(
    privacy: .private,
    unmaskedHeaders: ["Content-Type", "Accept"],  // Safe metadata
    unmaskedUrlQueries: ["page", "limit"],        // Pagination only
    unmaskedBodyParams: []                        // Be cautious with body
)
```

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Review the [CLAUDE.md](CLAUDE.md) for architecture details

---

**Made with care by Futured**
