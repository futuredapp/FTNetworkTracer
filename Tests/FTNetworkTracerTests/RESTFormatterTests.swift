import XCTest
@testable import FTNetworkTracer

class RESTFormatterTests: XCTestCase {

    func testFormatRequestBodyWithJSON() {
        let jsonData = """
        {"username": "john", "email": "john@example.com"}
        """.data(using: .utf8)!

        let decoder: @Sendable (Data) -> String? = { data in
            String(data: data, encoding: .utf8)
        }

        let type = EntryType.request(method: "POST", url: "https://example.com")
        let formatted = RESTFormatter.formatBody(jsonData, decoder: decoder, type: type)

        XCTAssertTrue(formatted.contains("Body:"))
        XCTAssertTrue(formatted.contains("username"))
        XCTAssertTrue(formatted.contains("john"))
        XCTAssertTrue(formatted.contains("email"))
    }

    func testFormatResponseBodyWithJSON() {
        let jsonData = """
        {"id": 123, "status": "success"}
        """.data(using: .utf8)!

        let decoder: @Sendable (Data) -> String? = { data in
            String(data: data, encoding: .utf8)
        }

        let type = EntryType.response(method: "POST", url: "https://example.com", statusCode: 200)
        let formatted = RESTFormatter.formatBody(jsonData, decoder: decoder, type: type)

        XCTAssertTrue(formatted.contains("Body:"))
        XCTAssertTrue(formatted.contains("id"))
        XCTAssertTrue(formatted.contains("123"))
        XCTAssertTrue(formatted.contains("status"))
        XCTAssertTrue(formatted.contains("success"))
    }

    func testFormatErrorBodyWithData() {
        let errorData = """
        {"error": "Not found"}
        """.data(using: .utf8)!

        let decoder: @Sendable (Data) -> String? = { data in
            String(data: data, encoding: .utf8)
        }

        let type = EntryType.error(method: "GET", url: "https://example.com", error: "404")
        let formatted = RESTFormatter.formatBody(errorData, decoder: decoder, type: type)

        XCTAssertTrue(formatted.contains("Data:"))
        XCTAssertTrue(formatted.contains("error"))
        XCTAssertTrue(formatted.contains("Not found"))
    }

    func testFormatBodyWithNilData() {
        let decoder: @Sendable (Data) -> String? = { data in
            String(data: data, encoding: .utf8)
        }

        let type = EntryType.request(method: "GET", url: "https://example.com")
        let formatted = RESTFormatter.formatBody(nil, decoder: decoder, type: type)

        XCTAssertEqual(formatted, "")
    }

    func testFormatBodyWithDecoderReturningNil() {
        let data = Data([0xFF, 0xFE]) // Invalid UTF-8

        let decoder: @Sendable (Data) -> String? = { _ in
            return nil
        }

        let type = EntryType.request(method: "POST", url: "https://example.com")
        let formatted = RESTFormatter.formatBody(data, decoder: decoder, type: type)

        XCTAssertEqual(formatted, "")
    }

    func testFormatBodyWithPrettyPrintedJSON() {
        let jsonData = """
        {"username": "john", "email": "john@example.com"}
        """.data(using: .utf8)!

        // Use the default decoder that pretty prints JSON
        let decoder: @Sendable (Data) -> String? = { data in
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
               let prettyJSON = String(data: prettyData, encoding: .utf8) {
                return prettyJSON
            }
            return String(data: data, encoding: .utf8)
        }

        let type = EntryType.request(method: "POST", url: "https://example.com")
        let formatted = RESTFormatter.formatBody(jsonData, decoder: decoder, type: type)

        XCTAssertTrue(formatted.contains("Body:"))
        // Pretty printed JSON should contain newlines
        XCTAssertTrue(formatted.contains("\n"))
    }

    func testFormatBodyWithPlainText() {
        let textData = "Simple text response".data(using: .utf8)!

        let decoder: @Sendable (Data) -> String? = { data in
            String(data: data, encoding: .utf8)
        }

        let type = EntryType.response(method: "GET", url: "https://example.com", statusCode: 200)
        let formatted = RESTFormatter.formatBody(textData, decoder: decoder, type: type)

        XCTAssertTrue(formatted.contains("Body:"))
        XCTAssertTrue(formatted.contains("Simple text response"))
    }

    func testFormatBodyPrefixDiffersByType() {
        let data = "test".data(using: .utf8)!
        let decoder: @Sendable (Data) -> String? = { data in
            String(data: data, encoding: .utf8)
        }

        let requestFormatted = RESTFormatter.formatBody(data, decoder: decoder, type: .request(method: "POST", url: ""))
        XCTAssertTrue(requestFormatted.contains("Body:"))

        let responseFormatted = RESTFormatter.formatBody(data, decoder: decoder, type: .response(method: "POST", url: "", statusCode: 200))
        XCTAssertTrue(responseFormatted.contains("Body:"))

        let errorFormatted = RESTFormatter.formatBody(data, decoder: decoder, type: .error(method: "POST", url: "", error: "error"))
        XCTAssertTrue(errorFormatted.contains("Data:"))

        // Verify they use different prefixes
        XCTAssertNotEqual(errorFormatted, requestFormatted)
    }

    func testFormatBodyWithSizeOnlyDecoder() {
        let data = "Lorem ipsum dolor sit amet".data(using: .utf8)!

        let decoder: @Sendable (Data) -> String? = { data in
            "<\(data.count) bytes>"
        }

        let type = EntryType.request(method: "POST", url: "https://example.com")
        let formatted = RESTFormatter.formatBody(data, decoder: decoder, type: type)

        XCTAssertTrue(formatted.contains("Body:"))
        XCTAssertTrue(formatted.contains("bytes"))
        XCTAssertFalse(formatted.contains("Lorem"))
    }
}
