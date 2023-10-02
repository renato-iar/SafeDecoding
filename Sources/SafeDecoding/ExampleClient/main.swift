import Foundation
import SafeDecoding

@SafeDecoding
struct SubModel {
    let strings: Set<String>
}

@SafeDecoding
struct Model {
    let integer: Int
    @IgnoreSafeDecoding
    let integerArray: [Int]
    let genericArray: Array<String>
    let string: String
    let dictionary: [String: Int]
    let optionalInteger: Int?
    let subModel: SubModel?
    var numberOfIntegersInArray: Int { integerArray.count }
    //let constantInt: Int = 0
    //let constantInferred = 0
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
            Model.self,
            from: data
        )

        dump(model)
    } else {
        print("===> data conversion failed")
    }
} catch {
    print("===> failed: \(error)")
}
