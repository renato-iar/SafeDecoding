import Foundation
import SafeDecoding

@SafeDecoding(reporter: MockReporter.shared)
struct TestModel {
    let optionalInteger: Int?
    let integerArray: [Int]
    let integerSet: Set<Int>
    let stringToIntDictionary: [String: Int]
}
