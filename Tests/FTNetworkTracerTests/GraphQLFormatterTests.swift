@testable import FTNetworkTracer
import XCTest

class GraphQLFormatterTests: XCTestCase {
    func testSimpleQuery() {
        let query = "query GetUser { user { name email } }"
        let formatted = GraphQLFormatter.formatQuery(query)

        // Just check that key elements are present, regardless of exact formatting
        XCTAssertTrue(formatted.contains("GetUser"))
        XCTAssertTrue(formatted.contains("user"))
        XCTAssertTrue(formatted.contains("name"))
        XCTAssertTrue(formatted.contains("email"))
    }

    func testQueryWithVariables() {
        let query = """
        query GetUser($id: ID!) {
            user(id: $id) {
                name
                email
            }
        }
        """

        let formatted = GraphQLFormatter.formatQuery(query)

        XCTAssertTrue(formatted.contains("GetUser"))
        XCTAssertTrue(formatted.contains("$id"))
        XCTAssertTrue(formatted.contains("user"))
        XCTAssertTrue(formatted.contains("name"))
        XCTAssertTrue(formatted.contains("email"))
    }

    func testNestedQuery() {
        let query = """
        query GetUserWithPosts {
            user {
                name
                posts {
                    title
                    comments {
                        text
                    }
                }
            }
        }
        """

        let formatted = GraphQLFormatter.formatQuery(query)

        XCTAssertTrue(formatted.contains("user {"))
        XCTAssertTrue(formatted.contains("posts {"))
        XCTAssertTrue(formatted.contains("comments {"))
    }

    func testQueryRemovesTypename() {
        let query = "query GetUser { user { __typename name email } }"
        let formatted = GraphQLFormatter.formatQuery(query)

        XCTAssertFalse(formatted.contains("__typename"))
        XCTAssertTrue(formatted.contains("name"))
        XCTAssertTrue(formatted.contains("email"))
    }

    func testFragmentQuery() {
        let query = """
        query GetUser {
            user {
                ...UserFields
            }
        }
        fragment UserFields on User {
            name
            email
        }
        """

        let formatted = GraphQLFormatter.formatQuery(query)

        XCTAssertTrue(formatted.contains("GetUser"))
        XCTAssertTrue(formatted.contains("fragment"))
        XCTAssertTrue(formatted.contains("UserFields"))
        XCTAssertTrue(formatted.contains("name"))
        XCTAssertTrue(formatted.contains("email"))
    }

    func testMutationQuery() {
        let query = """
        mutation CreateUser($name: String!) {
            createUser(name: $name) {
                id
                name
            }
        }
        """

        let formatted = GraphQLFormatter.formatQuery(query)

        XCTAssertTrue(formatted.contains("createUser(name: $name) {"))
        XCTAssertTrue(formatted.contains("id"))
        XCTAssertTrue(formatted.contains("name"))
    }

    func testFormatVariablesSimple() {
        let variables: [String: any Sendable] = [
            "id": "123",
            "name": "John"
        ]

        let formatted = GraphQLFormatter.formatVariables(variables)

        XCTAssertTrue(formatted.contains("id"))
        XCTAssertTrue(formatted.contains("123"))
        XCTAssertTrue(formatted.contains("name"))
        XCTAssertTrue(formatted.contains("John"))
    }

    func testFormatVariablesNested() {
        let userDict: [String: any Sendable] = [
            "name": "John",
            "age": 30
        ]
        let variables: [String: any Sendable] = [
            "id": "123",
            "user": userDict
        ]

        let formatted = GraphQLFormatter.formatVariables(variables)

        XCTAssertTrue(formatted.contains("id"))
        XCTAssertTrue(formatted.contains("user"))
        XCTAssertTrue(formatted.contains("name"))
        XCTAssertTrue(formatted.contains("John"))
    }

    func testFormatVariablesWithArray() {
        let variables: [String: any Sendable] = [
            "ids": ["123", "456", "789"] as [String]
        ]

        let formatted = GraphQLFormatter.formatVariables(variables)

        XCTAssertTrue(formatted.contains("ids"))
        XCTAssertTrue(formatted.contains("123"))
        XCTAssertTrue(formatted.contains("456"))
        XCTAssertTrue(formatted.contains("789"))
    }

    func testFormatVariablesEmpty() {
        let variables: [String: any Sendable] = [:]

        let formatted = GraphQLFormatter.formatVariables(variables)

        // Empty variables should produce an empty object
        XCTAssertTrue(formatted.contains("{"))
        XCTAssertTrue(formatted.contains("}"))
    }

    func testComplexQueryWithMultipleFields() {
        let query = """
        query GetUserData($userId: ID!, $includeProfile: Boolean!) {
            user(id: $userId) {
                id
                name
                email
                profile @include(if: $includeProfile) {
                    avatar
                    bio
                    interests {
                        category
                        items
                    }
                }
            }
        }
        """

        let formatted = GraphQLFormatter.formatQuery(query)

        XCTAssertTrue(formatted.contains("query GetUserData"))
        XCTAssertTrue(formatted.contains("user(id: $userId) {"))
        XCTAssertTrue(formatted.contains("profile"))
        XCTAssertTrue(formatted.contains("interests {"))
    }
}
