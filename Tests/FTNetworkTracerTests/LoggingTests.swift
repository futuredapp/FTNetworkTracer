// swiftlint:disable force_unwrapping non_optional_string_data_conversion
@testable import FTNetworkTracer
import XCTest

class FormattingTests: XCTestCase {
    // MARK: - FormatterConfiguration Tests

    func testFormatterConfigurationDefaults() {
        let config = FormatterConfiguration.default
        XCTAssertTrue(config.includeHeaders)
        XCTAssertTrue(config.includeBody)
        XCTAssertNil(config.maxBodyLength)
    }

    func testFormatterConfigurationCompact() {
        let config = FormatterConfiguration.compact
        XCTAssertFalse(config.includeHeaders)
        XCTAssertFalse(config.includeBody)
    }

    func testFormatterConfigurationVerbose() {
        let config = FormatterConfiguration.verbose
        XCTAssertTrue(config.includeHeaders)
        XCTAssertTrue(config.includeBody)
        XCTAssertNil(config.maxBodyLength)
    }

    func testFormatterConfigurationDataDecoder() {
        let jsonData = """
        {"name": "test", "value": 123}
        """.data(using: .utf8)!

        let prettyJSON = FormatterConfiguration.defaultDataDecoder(jsonData)
        XCTAssertNotNil(prettyJSON)
        XCTAssertTrue(prettyJSON!.contains("\n")) // Should be pretty printed

        let utf8Data = "simple text".data(using: .utf8)!
        let utf8Result = FormatterConfiguration.utf8DataDecoder(utf8Data)
        XCTAssertEqual(utf8Result, "simple text")

        let sizeResult = FormatterConfiguration.sizeOnlyDataDecoder(utf8Data)
        XCTAssertEqual(sizeResult, "<11 bytes>")
    }

    // MARK: - NetworkTraceFormatter Tests

    func testFormatRequest() {
        let entry = NetworkTraceEntry(
            type: .request(method: "POST", url: "https://api.example.com/users"),
            headers: ["Content-Type": "application/json"],
            body: "{\"username\": \"test\"}".data(using: .utf8)!,
            requestId: "abc12345"
        )

        let message = NetworkTraceFormatter.format(entry)
        XCTAssertTrue(message.contains("[REQUEST]"))
        XCTAssertTrue(message.contains("POST"))
        XCTAssertTrue(message.contains("https://api.example.com/users"))
        XCTAssertTrue(message.contains("Headers:"))
        XCTAssertTrue(message.contains("Body:"))
    }

    func testFormatResponse() {
        let entry = NetworkTraceEntry(
            type: .response(method: "POST", url: "https://api.example.com/users", statusCode: 201),
            headers: ["Content-Type": "application/json"],
            body: "{\"id\": 123}".data(using: .utf8)!,
            duration: 0.5,
            requestId: "abc12345"
        )

        let message = NetworkTraceFormatter.format(entry)
        XCTAssertTrue(message.contains("[RESPONSE]"))
        XCTAssertTrue(message.contains("201"))
        XCTAssertTrue(message.contains("500.00ms"))
    }

    func testFormatError() {
        let entry = NetworkTraceEntry(
            type: .error(method: "POST", url: "https://api.example.com/users", error: "Network error"),
            body: "{\"error\": \"Connection failed\"}".data(using: .utf8)!,
            requestId: "abc12345"
        )

        let message = NetworkTraceFormatter.format(entry)
        XCTAssertTrue(message.contains("[ERROR]"))
        XCTAssertTrue(message.contains("ERROR"))
        XCTAssertTrue(message.contains("Network error"))
        XCTAssertTrue(message.contains("Data:"))
    }

    func testFormatGraphQLRequest() {
        let query = """
        query GetUser($id: ID!) {
            user(id: $id) {
                name
                email
            }
        }
        """

        let variables: [String: any Sendable] = ["id": "123"]

        let entry = NetworkTraceEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            requestId: "test-id",
            operationName: "GetUser",
            query: query,
            variables: variables
        )

        let message = NetworkTraceFormatter.format(entry)
        XCTAssertTrue(message.contains("[REQUEST]"))
        XCTAssertTrue(message.contains("Operation"))
        XCTAssertTrue(message.contains("GetUser"))
        XCTAssertTrue(message.contains("Query:"))
        XCTAssertTrue(message.contains("Variables:"))
    }

    func testFormatWithCompactConfiguration() {
        let entry = NetworkTraceEntry(
            type: .request(method: "GET", url: "https://api.example.com/users"),
            headers: ["Authorization": "Bearer token"],
            body: "{\"data\": \"value\"}".data(using: .utf8)!,
            requestId: "test-123"
        )

        let message = NetworkTraceFormatter.format(entry, configuration: .compact)
        XCTAssertTrue(message.contains("[REQUEST]"))
        XCTAssertTrue(message.contains("GET"))
        // Compact mode should not include headers or body
        XCTAssertFalse(message.contains("Headers:"))
        XCTAssertFalse(message.contains("Body:"))
    }

    func testFormatWithMaxBodyLength() {
        let longBody = String(repeating: "A", count: 1000).data(using: .utf8)!

        let config = FormatterConfiguration(
            includeHeaders: true,
            includeBody: true,
            maxBodyLength: 100
        )

        let entry = NetworkTraceEntry(
            type: .request(method: "POST", url: "https://api.example.com"),
            body: longBody,
            requestId: "test-123"
        )

        let message = NetworkTraceFormatter.format(entry, configuration: config)
        XCTAssertTrue(message.contains("truncated"))
    }

    // MARK: - NetworkTraceEntry Tests

    func testNetworkTraceEntryConvenienceProperties() {
        let requestEntry = NetworkTraceEntry(
            type: .request(method: "GET", url: "https://api.example.com/users"),
            requestId: "test-123"
        )
        XCTAssertEqual(requestEntry.method, "GET")
        XCTAssertEqual(requestEntry.url, "https://api.example.com/users")
        XCTAssertNil(requestEntry.statusCode)
        XCTAssertNil(requestEntry.error)
        XCTAssertFalse(requestEntry.isGraphQL)

        let responseEntry = NetworkTraceEntry(
            type: .response(method: "POST", url: "https://api.example.com/users", statusCode: 200),
            requestId: "test-123"
        )
        XCTAssertEqual(responseEntry.statusCode, 200)
        XCTAssertNil(responseEntry.error)

        let errorEntry = NetworkTraceEntry(
            type: .error(method: "POST", url: "https://api.example.com/users", error: "Network error"),
            requestId: "test-123"
        )
        XCTAssertEqual(errorEntry.error, "Network error")
        XCTAssertNil(errorEntry.statusCode)
    }

    func testNetworkTraceEntryIsGraphQL() {
        let restEntry = NetworkTraceEntry(
            type: .request(method: "GET", url: "https://api.example.com/users"),
            requestId: "test-123"
        )
        XCTAssertFalse(restEntry.isGraphQL)

        let graphQLEntry = NetworkTraceEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            requestId: "test-123",
            operationName: "GetUser"
        )
        XCTAssertTrue(graphQLEntry.isGraphQL)

        let graphQLWithQueryEntry = NetworkTraceEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            requestId: "test-123",
            query: "query { user { name } }"
        )
        XCTAssertTrue(graphQLWithQueryEntry.isGraphQL)
    }
}
