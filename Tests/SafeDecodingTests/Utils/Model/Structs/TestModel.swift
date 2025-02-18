import Foundation
import SafeDecoding

@SafeDecoding(
    reporter: MockReporter.shared,
    shouldImplementEncoding: true
)
struct TestModel: Hashable, Encodable {
    let optionalInteger: Int?
    let integerArray: [Int]
    let integerSet: Set<Int>
    let stringToIntDictionary: [String: Int]
}
