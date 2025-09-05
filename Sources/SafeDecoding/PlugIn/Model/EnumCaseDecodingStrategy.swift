/**
 Determines how decoding of individual cases is performed for enum

 When using `SafeDecoding` on `enum`s, a decoding strategy must be specified:
 - `caseByObjectProperty`: cases will be identified by matching a property in the decoded object.
 - `caseByNestedObject`: cases will be identified by being wrapped in a single-property object keyed by the case name
 */
public enum EnumCaseDecodingStrategy {
    /**
     For some enum:

     ```
     @SafeDecoding(decodingStrategy: .natural)
     enum Chirality {
        case left
        @CaseNameDecoding("rght")
        case right
     }
     ```

     Expects a JSON payload that either matches:
     - the raw value associated with the case, if one is provided
     - the raw string matching the readable case name
     - the name provided by ``CaseNameDecoding``, as a raw string

     ```
     "left"
     ```

     Will be decoded into `Chirality.left`.

     ```
     "rght"
     ```

     Will be decoded into `Chirality.right`.

     ```
     "right"
     ```

     Will fail decoding.

     If the enumeration is `RawRepresentable`,
     A single value matching the `Chirality.RawValue` will be
     decoded and matched against each of the `case`'s `.rawValue`s.
     If `Chirality` is `RawRepresentable`:

     ```
     @SafeDecodable(decodingStrategy: .natural)
     enum Chirality: Int {
        case left
        case right
     }
     ```

     Then decoding will always take place matching decoded value against each case's `.rawValue`:

     ```
     init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Self.RawValue.self)

        switch rawValue {
            case Self.left.rawValue:
                self = .left
            case Self.right.rawValue:
                self = .right
            default:
                throw ...
        }
     }
     ```
     */
    case natural

    /**
     For some enum:

     ```
     @SafeDecoding(decodingStrategy: .caseByObjectProperty("type"))
     enum Sample {
        case one(id: String, title: String, ...)
        case two(id: String, title: String, ...)
        case three(id: String, title: String, ...)
     }
     ```

     Expects a JSON payload where the case is identified by an object property named `type`:

     ```
     {
        "type": "one",
        "id": "...",
        "title": "..."
        ...
     }
     ```

     Where `type` will be used to determine the case being decoded
     */
    case caseByObjectProperty(String)

    /**
     For some enum:

     ```
     @SafeDecoding(decodingStrategy: .caseByObjectProperty("type"))
     enum Sample {
        case one(id: String, title: String, ...)
        case two(id: String, title: String, ...)
        case three(id: String, title: String, ...)
     }
     ```

     Expects a JSON payload where the actual object data is nested in a single-value object, keyed by the names of the cases:

     ```
     {
        "one": {
            "id": "...",
            "title": "...",
            ...
        }
     }
     ```
     */
    case caseByNestedObject
}
