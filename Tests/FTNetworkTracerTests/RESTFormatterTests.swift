// swiftlint:disable force_unwrapping non_optional_string_data_conversion
@testable import FTNetworkTracer
import XCTest

class RESTFormatterTests: XCTestCase {
    func testFormatRequestBodyWithJSON() {
        let jsonData = """
        {"username": "john", "email": "john@example.com"}
        """.data(using: .utf8)!

        let decoder: @Sendable (Data) -> String? = { data in
            String(data: data, encoding: .utf8)
        }

        let formatted = RESTFormatter.formatBody(jsonData, decoder: decoder, label: "Body")

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

        let formatted = RESTFormatter.formatBody(jsonData, decoder: decoder, label: "Body")

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

        let formatted = RESTFormatter.formatBody(errorData, decoder: decoder, label: "Data")

        XCTAssertTrue(formatted.contains("Data:"))
        XCTAssertTrue(formatted.contains("error"))
        XCTAssertTrue(formatted.contains("Not found"))
    }

    func testFormatBodyWithNilData() {
        let decoder: @Sendable (Data) -> String? = { data in
            String(data: data, encoding: .utf8)
        }

        let formatted = RESTFormatter.formatBody(nil, decoder: decoder, label: "Body")

        XCTAssertEqual(formatted, "")
    }

    func testFormatBodyWithDecoderReturningNil() {
        let data = Data([0xFF, 0xFE]) // Invalid UTF-8

        let decoder: @Sendable (Data) -> String? = { _ in
            nil
        }

        let formatted = RESTFormatter.formatBody(data, decoder: decoder, label: "Body")

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

        let formatted = RESTFormatter.formatBody(jsonData, decoder: decoder, label: "Body")

        XCTAssertTrue(formatted.contains("Body:"))
        // Pretty printed JSON should contain newlines
        XCTAssertTrue(formatted.contains("\n"))
    }

    func testFormatBodyWithPlainText() {
        let textData = "Simple text response".data(using: .utf8)!

        let decoder: @Sendable (Data) -> String? = { data in
            String(data: data, encoding: .utf8)
        }

        let formatted = RESTFormatter.formatBody(textData, decoder: decoder, label: "Body")

        XCTAssertTrue(formatted.contains("Body:"))
        XCTAssertTrue(formatted.contains("Simple text response"))
    }

    func testFormatBodyPrefixDiffersByLabel() {
        let data = "test".data(using: .utf8)!
        let decoder: @Sendable (Data) -> String? = { data in
            String(data: data, encoding: .utf8)
        }

        let bodyFormatted = RESTFormatter.formatBody(data, decoder: decoder, label: "Body")
        XCTAssertTrue(bodyFormatted.contains("Body:"))

        let dataFormatted = RESTFormatter.formatBody(data, decoder: decoder, label: "Data")
        XCTAssertTrue(dataFormatted.contains("Data:"))

        let responseFormatted = RESTFormatter.formatBody(data, decoder: decoder, label: "Response")
        XCTAssertTrue(responseFormatted.contains("Response:"))

        // Verify they use different prefixes
        XCTAssertNotEqual(dataFormatted, bodyFormatted)
    }

    func testFormatBodyWithSizeOnlyDecoder() {
        let data = "Lorem ipsum dolor sit amet".data(using: .utf8)!

        let decoder: @Sendable (Data) -> String? = { data in
            "<\(data.count) bytes>"
        }

        let formatted = RESTFormatter.formatBody(data, decoder: decoder, label: "Body")

        XCTAssertTrue(formatted.contains("Body:"))
        XCTAssertTrue(formatted.contains("bytes"))
        XCTAssertFalse(formatted.contains("Lorem"))
    }
}
