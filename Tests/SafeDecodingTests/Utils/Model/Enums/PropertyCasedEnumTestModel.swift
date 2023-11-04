import Foundation
import SafeDecoding

@SafeDecoding(decodingStrategy: .caseByObjectProperty("type"), reporter: MockReporter.shared)
enum PropertyCasedEnumTestModel {
    case elementWithOptionalStringParameter(optionalString: String?)
    case elementWithStringArrayParameter(stringArray: [String])
    case elementWithStringSetParameter(stringSet: Set<String>)
    case elementWithStringToIntDictionaryParameter(stringToIntDictionary: [String: Int])
}
