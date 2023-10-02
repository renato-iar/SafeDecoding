import Foundation

public struct SafeDecodable<T: Decodable>: Decodable {
    public let decoded: T?

    public init(from decoder: Decoder) throws {
        self.decoded = try? T(from: decoder)
    }
}
