import Foundation
import SafeDecoding

@SafeDecoding(reporter: MockReporter.shared)
struct TestModelWithRetriesAndFallbacks {
    let optionalInteger: Int?
    @RetryDecoding(String.self, map: { Int($0, radix: 10) })
    @RetryDecoding(Double.self, map: { Int($0) })
    let integerWithRetries: Int
    @FallbackDecoding("fallback")
    let stringWithFallback: String
    @RetryDecoding(String.self, map: { $0.lowercased() == "true" })
    @RetryDecoding(Int.self, map: { $0 != 0 })
    @FallbackDecoding(false)
    let booleanWithFallbackAndRetries: Bool
    let integerArray: [Int]
    let integerSet: Set<Int>
    let stringToIntDictionary: [String: Int]
}
