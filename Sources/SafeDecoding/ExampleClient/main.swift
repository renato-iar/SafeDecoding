import Foundation
import SafeDecoding

/// Sample error reporter
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

@SafeDecoding(reporter: SafeDecodingErrorReporter.shared, shouldImplementEncoding: true)
struct SubModel: Codable {
    let strings: Array<String>
}

// Expand macro to see code generated for the base usage of @SafeDecoding

@SafeDecoding(reporter: SafeDecodingErrorReporter.shared, shouldImplementEncoding: true)
struct ModelStandardExample {
    let integer: Int
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

enum FeatureFlag {
    case someFeature
}

struct Features {
    func isEnabled(_ feature: FeatureFlag) -> Bool {
        true
    }

    private init() { }

    static let shared = Features()
}

// Expand macro to see code generated for extended usage of @SafeDecoding
// using the reporter, as well as @RetryDecoding, @FallbackDecoding and @IgnoreSafeDecoding
// macros as decorators

@SafeDecoding(reporter: SafeDecodingErrorReporter.shared, shouldImplementEncoding: true)
struct ModelFullExample {
    @PropertyNameDecoding("custon-double")
    let double: Double
    @RetryDecoding(String.self, map: { Int($0, radix: 10) })
    @RetryDecoding(Double.self, map: { Int($0) })
    let integer: Int
    @IgnoreSafeDecoding
    let integerArray: [Int]
    let genericArray: Array<String>
    @FallbackDecoding(UUID().uuidString)
    let string: String
    let dictionary: [String: Int]
    @OptionalDecoding(Features.shared.isEnabled(.someFeature))
    @FallbackDecoding(0)
    @RetryDecoding(String.self, map: { Int($0, radix: 10) })
    @RetryDecoding(Double.self, map: { Int($0) })
    let optionalInteger: Int?
    @FallbackDecoding(SubModel(strings: []))
    let subModel: SubModel?
    var numberOfIntegersInArray: Int { integerArray.count }
    let set: Set<Int>
    let constantInt: Int = 0
    let constantInferred = 0
}

// Decoding tests

func testDecoding<T: Decodable>(_: T.Type, input: String) {
    do {
        if let data = input.data(using: .utf8) {
            let model = try JSONDecoder().decode(
                T.self,
                from: data
            )

            dump(model)
        } else {
            print("===> data conversion failed for type \(T.self)")
        }
    } catch {
        print("===> error for type \(T.self): \(error)")
    }
}

testDecoding(
    ModelFullExample.self,
    input:
            """
            {
                "integerArray": [1, 2, 3],
                "integer": "101",
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
)

@SafeDecoding(
    decodingStrategy: .caseByNestedObject,
    shouldImplementEncoding: true,
    reporter: SafeDecodingErrorReporter.shared
)
enum MediaAssetNested {
    @CaseNameDecoding("ASSET/PROGRAMME")
    case vod(String?, String)
    @CaseNameDecoding("ASSET/SERIES")
    case series(id: [String], Set<String>)
    @CaseNameDecoding("ASSET/EPISODE")
    case episode(id: String, title: String, arguments: [String: Double])
    case placeholder
}

testDecoding(
    MediaAssetNested.self,
    input:
        """
        {
            "ASSET/SERIES": {
                "id": "vod-id",
                "_1": "vod title"
            }
        }
        """
)

@SafeDecoding(decodingStrategy: .caseByObjectProperty("type"), reporter: SafeDecodingErrorReporter.shared)
enum MediaAssetKeyed {
    @CaseNameDecoding("ASSET/PROGRAMME")
    case vod(String?, String)
    @CaseNameDecoding("ASSET/SERIES")
    case series(id: [String], Set<String>)
    @CaseNameDecoding("ASSET/EPISODE")
    case episode(id: String, title: String, arguments: [String: Double])
    @CaseNameDecoding("ASSET/PLACEHOLDER")
    case placeholder
}

testDecoding(
    MediaAssetKeyed.self,
    input:
        """
        {
            "type": "ASSET/EPISODE",
            "id": "vod-id",
            "title": "vod title",
            "arguments": {
                "sample": 0
            }
        }
        """
)
