import XCTest
@testable import FTNetworkTracer

class LoggingTests: XCTestCase {

    func testLoggerConfigurationInitialization() {
        let configuration = LoggerConfiguration(
            subsystem: "com.test",
            category: "test"
        )
        XCTAssertNotNil(configuration)
        XCTAssertEqual(configuration.subsystem, "com.test")
        XCTAssertEqual(configuration.category, "test")
    }

    func testLoggerConfigurationDataDecoder() {
        let jsonData = """
        {"name": "test", "value": 123}
        """.data(using: .utf8)!

        let prettyJSON = LoggerConfiguration.defaultDataDecoder(jsonData)
        XCTAssertNotNil(prettyJSON)
        XCTAssertTrue(prettyJSON!.contains("\n")) // Should be pretty printed

        let utf8Data = "simple text".data(using: .utf8)!
        let utf8Result = LoggerConfiguration.utf8DataDecoder(utf8Data)
        XCTAssertEqual(utf8Result, "simple text")

        let sizeResult = LoggerConfiguration.sizeOnlyDataDecoder(utf8Data)
        XCTAssertEqual(sizeResult, "<11 bytes>")
    }

    func testLogEntryBuildMessage() {
        let configuration = LoggerConfiguration(
            subsystem: "com.test",
            category: "test"
        )

        // Test request message
        let requestEntry = LogEntry(
            type: .request(method: "POST", url: "https://api.example.com/users"),
            headers: ["Content-Type": "application/json"],
            body: "{\"username\": \"test\"}".data(using: .utf8)!,
            requestId: "abc12345"
        )

        let requestMessage = requestEntry.buildMessage(configuration: configuration)
        XCTAssertTrue(requestMessage.contains("[REQUEST]"))
        XCTAssertTrue(requestMessage.contains("POST"))
        XCTAssertTrue(requestMessage.contains("https://api.example.com/users"))
        XCTAssertTrue(requestMessage.contains("Headers:"))
        XCTAssertTrue(requestMessage.contains("Body:"))

        // Test response message
        let responseEntry = LogEntry(
            type: .response(method: "POST", url: "https://api.example.com/users", statusCode: 201),
            headers: ["Content-Type": "application/json"],
            body: "{\"id\": 123}".data(using: .utf8)!,
            duration: 0.5,
            requestId: "abc12345"
        )

        let responseMessage = responseEntry.buildMessage(configuration: configuration)
        XCTAssertTrue(responseMessage.contains("[RESPONSE]"))
        XCTAssertTrue(responseMessage.contains("201"))
        XCTAssertTrue(responseMessage.contains("500.00ms"))

        // Test error message
        let errorEntry = LogEntry(
            type: .error(method: "POST", url: "https://api.example.com/users", error: "Network error"),
            body: "{\"error\": \"Connection failed\"}".data(using: .utf8)!,
            requestId: "abc12345"
        )

        let errorMessage = errorEntry.buildMessage(configuration: configuration)
        XCTAssertTrue(errorMessage.contains("[ERROR]"))
        XCTAssertTrue(errorMessage.contains("ERROR"))
        XCTAssertTrue(errorMessage.contains("Network error"))
        XCTAssertTrue(errorMessage.contains("Data:"))
    }

    func testGraphQLLogEntry() {
        let configuration = LoggerConfiguration(
            subsystem: "com.test",
            category: "test"
        )

        let query = """
        query GetUser($id: ID!) {
            user(id: $id) {
                name
                email
            }
        }
        """

        let variables: [String: any Sendable] = ["id": "123"]

        let entry = LogEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            requestId: "test-id",
            operationName: "GetUser",
            query: query,
            variables: variables
        )

        let message = entry.buildMessage(configuration: configuration)
        XCTAssertTrue(message.contains("[REQUEST]"))
        XCTAssertTrue(message.contains("Operation"))
        XCTAssertTrue(message.contains("GetUser"))
        XCTAssertTrue(message.contains("Query:"))
        XCTAssertTrue(message.contains("Variables:"))
    }
}
