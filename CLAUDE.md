# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FTNetworkTracer is a Swift Package Manager library for formatting and masking network trace data. It provides:
1. **Formatting** - Human-readable console output from network trace entries
2. **Masking** - Privacy-safe data transformation for analytics

The library supports both REST and GraphQL requests with specialized handling for each.

## Common Commands

### Building
```bash
swift build
```

### Running Tests
```bash
# Run all tests
swift test

# Run specific tests
swift test --filter FormattingTests
swift test --filter MaskingTests
swift test --filter GraphQLFormatterTests
swift test --filter RESTFormatterTests
```

### Cleaning Build Artifacts
```bash
swift package clean
```

## Architecture

### Core Components

**NetworkTraceEntry** (`NetworkTraceEntry.swift`) - Core data structure
- Unified entry type for request, response, and error events
- Contains: type, headers, body, timestamp, duration, requestId
- GraphQL-specific: operationName, query, variables
- Convenience properties: method, url, statusCode, error, isGraphQL

**EntryType** (`EntryType.swift`) - Type-safe network event representation
- `.request(method:url:)` - Outgoing request
- `.response(method:url:statusCode:)` - Server response
- `.error(method:url:error:)` - Network error

### Formatting System

Located in `Sources/FTNetworkTracer/Formatting/`

**NetworkTraceFormatter** - Main formatting API
- `format(_ entry:)` - Format with default configuration
- `format(_ entry:configuration:)` - Format with custom configuration
- Produces aligned, human-readable output with method, URL, timestamp, headers, body

**FormatterConfiguration** - Formatting options
- `dataDecoder` - How to decode body data (default: pretty JSON with UTF8 fallback)
- `includeHeaders` - Whether to show headers
- `includeBody` - Whether to show body
- `maxBodyLength` - Truncate bodies longer than this
- Presets: `.default`, `.compact`, `.verbose`

**GraphQLFormatter** - GraphQL-specific formatting
- `formatQuery(_ query:)` - Pretty-prints GraphQL queries with proper indentation
- `formatVariables(_ variables:)` - Pretty-prints variables as JSON
- Removes `__typename` noise from queries

**RESTFormatter** - REST body formatting
- `formatBody(_ body:decoder:label:)` - Formats body data with custom decoder

### Masking System

Located in `Sources/FTNetworkTracer/Masking/`

**MaskingUtilities** - Main masking API
- `mask(_ entry:configuration:)` - Returns new entry with masked data
- Individual functions: `maskURL`, `maskHeaders`, `maskBody`, `maskVariables`, `maskQuery`
- Masked value constant: `***`

**MaskingConfiguration** - Masking rules
- `privacy` - MaskingPrivacy level
- `maskQueryLiterals` - Whether to mask literals in GraphQL queries (default: true)
- `unmaskedHeaders` - Header keys to NOT mask (case-insensitive)
- `unmaskedUrlQueries` - URL query params to NOT mask (case-insensitive)
- `unmaskedBodyParams` - Body/variable keys to NOT mask (case-insensitive)
- Presets: `.none`, `.private`, `.sensitive`

**MaskingPrivacy** - Privacy levels
- `.none` - No masking (development only)
- `.private` - Selective masking with exceptions
- `.sensitive` - Aggressive masking (recommended for production)

**QueryLiteralMasker** - GraphQL query literal masking
- Masks string literals (`"admin"` → `"***"`) and number literals (`123` → `***`)
- Preserves: query structure, field names, variable references (`$userId`), booleans, nulls, enums

### Data Flow

1. Consumer creates `NetworkTraceEntry` with network event data
2. For display: `NetworkTraceFormatter.format(entry)` → Human-readable string
3. For analytics: `MaskingUtilities.mask(entry, configuration:)` → Privacy-masked entry

### Key Design Patterns

**Associated Values for Type Safety**
- `EntryType` uses associated values instead of optionals
- Eliminates impossible states (e.g., request can't have status code)
- Access via computed properties on `NetworkTraceEntry`

**Dual-Mode Formatters**
- GraphQL detected by presence of `operationName`, `query`, or `variables`
- REST formatting used otherwise
- Both types share same entry structure but use different formatters

**Privacy by Design**
- All masking happens via `MaskingUtilities`
- Masking is irreversible - once masked, original data is gone
- GraphQL query masking secure by default (`maskQueryLiterals: true`)
- Removes literal values from queries while preserving structure

## Platform Support

- iOS 14+
- macOS 11+
- tvOS 14+
- watchOS 7+
- Swift 6.1+

## Code Conventions

- Use `@Sendable` for closures that cross concurrency boundaries
- All public types conform to `Sendable` for Swift 6 strict concurrency
- Privacy-sensitive data uses consistent `***` replacement string
- GraphQL query formatting removes `__typename` as noise in logs
