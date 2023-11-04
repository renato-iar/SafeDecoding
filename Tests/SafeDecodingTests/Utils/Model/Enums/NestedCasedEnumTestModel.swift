import Foundation
import SafeDecoding

@SafeDecoding(decodingStrategy: .caseByNestedObject, reporter: MockReporter.shared)
enum NestedCasedEnumTestModel {
    case elementWithOptionalStringParameter(optionalString: String?)
    case elementWithStringArrayParameter(stringArray: [String])
    case elementWithStringSetParameter(stringSet: Set<String>)
    case elementWithStringToIntDictionaryParameter(stringToIntDictionary: [String: Int])
}
