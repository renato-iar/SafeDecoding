import Foundation

enum DecodingUtils {
    static func decode<T: Decodable>(
        _ type: T.Type,
        input: String
    ) throws -> T? {
        try input
            .data(using: .utf8)
            .flatMap {
                try JSONDecoder()
                    .decode(type, from: $0)
            }
    }
}
