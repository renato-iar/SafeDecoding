import Foundation
import SafeDecoding

class SafeDecodingErrorReporter: SafeDecodingReporter {
    func report<Container, Property>(
        error: Error,
        of propertyName: String,
        decoding propertyType: Property.Type,
        in container: Container.Type
    ) {
        print("===> decoding error {\(container).\(propertyName): \(propertyType)}: \(error.localizedDescription)")
    }

    func report<Container, Item>(
        error: Error,
        decoding itemType: Item.Type,
        at index: Int,
        of propertyName: String,
        in containerType: Container.Type
    ) {
        print("===> decoding error {\(containerType).\(propertyName): [\(itemType)]} at index \(index): \(error.localizedDescription)")
    }

    func report<Container, Item>(
        error: Error,
        decoding itemType: Item.Type,
        of propertyName: String,
        in containerType: Container.Type
    ) {
        print("===> decoding error: {\(containerType).\(propertyName): \(itemType)}: \(error.localizedDescription)")
    }

    func report<Container, Key, Item>(
        error: Error,
        decoding itemType: Item.Type,
        forKey key: Key,
        of propertyName: String,
        in containerType: Container.Type
    ) where Key : Hashable {
        print("===> decoding error: {\(containerType).\(propertyName)[\(key)]: \(itemType)}: \(error.localizedDescription)")
    }

    static let shared = SafeDecodingErrorReporter()
}

@SafeDecoding(reporter: SafeDecodingErrorReporter.shared)
struct SubModel {
    let strings: Array<String>
}

@SafeDecoding
struct NonReportedModel {
    let integer: Int
    @IgnoreSafeDecoding
    let integerArray: [Int]
    let genericArray: Array<String>
    let string: String
    let dictionary: [String: Int]
    let optionalInteger: Int?
    let subModel: SubModel?
    var numberOfIntegersInArray: Int { integerArray.count }
    let set: Set<Int>
    let constantInt: Int = 0
    let constantInferred = 0
}

@SafeDecoding(reporter: SafeDecodingErrorReporter.shared)
struct ReportedModel {
    let integer: Int
    @IgnoreSafeDecoding
    let integerArray: [Int]
    let genericArray: Array<String>
    let string: String
    let dictionary: [String: Int]
    let optionalInteger: Int?
    let subModel: SubModel?
    var numberOfIntegersInArray: Int { integerArray.count }
    let set: Set<Int>
    let constantInt: Int = 0
    let constantInferred = 0
}

let input = """
{
    "integerArray": [1, 2, 3],
    "integer": 0,
    "string": "hello",
    "dictionary": {
        "a": 1,
        "b": 2
    },
    "optionalInteger": "1",
    "subModel": {
        "strings": ["1", 2, "3"]
    }
}
"""

do {
    if let data = input.data(using: .utf8) {
        let model = try JSONDecoder().decode(
            ReportedModel.self,
            from: data
        )

        dump(model)
    } else {
        print("===> data conversion failed")
    }
} catch {
    print("===> failed: \(error)")
}
