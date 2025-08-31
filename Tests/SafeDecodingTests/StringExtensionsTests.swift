import Foundation
@testable import SafeDecodingMacros
import Testing

struct StringExtensionsTests {
    @Test(
        "Test camel casing conversion",
        arguments: zip(
            ["HTTPClient", "httpClient", "userId", "user_id", "user-id", "user id"],
            ["HTTPClient", "httpClient", "userId", "userId", "userId", "userId"]
        )
    )
    func testCamelCasing(input: String, output: String) throws {
        #expect(input.camelCased == output)
    }

    @Test(
        "Test snake casing conversion",
        arguments: zip(
            ["HTTPClient", "httpClient", "userId", "user_id", "user-id", "user id"],
            ["http_client", "http_client", "user_id", "user_id", "user_id", "user_id"]
        )
    )
    func testSnakeCasing(input: String, output: String) throws {
        #expect(input.snakeCased == output)
    }

    @Test(
        "Test snake uppercase casing conversion",
        arguments: zip(
            ["HTTPClient", "httpClient", "userId", "user_id", "user-id", "user id"],
            ["HTTP_CLIENT", "HTTP_CLIENT", "USER_ID", "USER_ID", "USER_ID", "USER_ID"]
        )
    )
    func testSnakeUppercaseCasing(input: String, output: String) throws {
        #expect(input.snakeUppercased == output)
    }

    @Test(
        "Test snake casing conversion",
        arguments: zip(
            ["HTTPClient", "httpClient", "userId", "user_id", "user-id", "user id"],
            ["http-client", "http-client", "user-id", "user-id", "user-id", "user-id"]
        )
    )
    func testKebabCasing(input: String, output: String) throws {
        #expect(input.kebabCased == output)
    }

    @Test(
        "Test snake casing conversion",
        arguments: zip(
            ["HTTPClient", "httpClient", "userId", "user_id", "user-id", "user id"],
            ["HTTP-CLIENT", "HTTP-CLIENT", "USER-ID", "USER-ID", "USER-ID", "USER-ID"]
        )
    )
    func testKebabUppercaseCasing(input: String, output: String) throws {
        #expect(input.kebabUppercased == output)
    }
}
