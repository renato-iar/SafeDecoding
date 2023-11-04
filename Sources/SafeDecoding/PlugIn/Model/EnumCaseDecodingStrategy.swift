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
