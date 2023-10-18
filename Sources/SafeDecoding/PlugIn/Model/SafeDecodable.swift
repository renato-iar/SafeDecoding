import Foundation

public struct SafeDecodable<T: Decodable>: Decodable {
    public let decoded: T?
    public let error: Error?

    public init(from decoder: Decoder) throws {
        do {
            self.decoded = try T(from: decoder)
            self.error = nil
        } catch {
            self.decoded = nil
            self.error = error
        }
    }
}
