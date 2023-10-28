/**
 Types conforming to `SafeDecodingReporter` can be used alongside the `@SafeDecoding` macro to report decoding errors.
 */
public protocol SafeDecodingReporter {
    /**
     Called when the decoder recovers from an error

     This method will be called when the decoder recovers from decoding an `Optional`
     or a non-optional type by means of `@RetryDecoding` or `@FallbackDecoding`

     - parameters:
        - error: The error thrown during decoding
        - propertyName: The name of the property being decoded
        - propertyType: The type of the property being decoded
        - containerType: The type that contained the property
     */
    func report<Container, Property>(
        error: Error,
        of propertyName: String,
        decoding propertyType: Property.Type,
        in containerType: Container.Type
    )

    /**
     Called when an error is found while decoding an item in an `Array`

     When performing safe decoding of an `Array`, errors that occur while decoding individual items are reported.

     - parameters:
        - error: The error thrown during decoding
        - itemType: The type of the array items being decoded
        - index: The index in the originally decoded array where the error occurred
        - propertyName: The name of the property being decoded
        - containerType: The type that contained the property
     */
    func report<Container, Item>(
        error: Error,
        decoding itemType: Item.Type,
        at index: Int,
        of propertyName: String,
        in containerType: Container.Type
    )

    /**
     Called when an error is found while decoding an item in an `Array`, that will be mapped into a `Set`

     When performing safe decoding of a `Set`, decoding is performed through an `Array` that will then
     be mapped to the `Set`; errors that occur while decoding individual items are reported.

     - parameters:
        - error: The error thrown during decoding
        - itemType: The type of the array items being decoded (the array will be mapped to a set)
        - propertyName: The name of the property being decoded
        - containerType: The type that contained the property
     */
    func report<Container, Item>(
        error: Error,
        decoding itemType: Item.Type,
        of propertyName: String,
        in containerType: Container.Type
    )

    /**
     Called when an error is found while decoding an item of a `Dictionary`

     When performing safe decoding of an `Dictionary`, errors that occur while decoding individual items are reported.

     - parameters:
        - error: The error thrown during decoding
        - itemType: The type of the array items being decoded (the array will be mapped to a set)
        - key: The key for which the decoding of the item failed
        - propertyName: The name of the property being decoded
        - containerType: The type that contained the property
     */
    func report<Container, Key: Hashable, Item>(
        error: Error,
        decoding itemType: Item.Type,
        forKey key: Key,
        of propertyName: String,
        in containerType: Container.Type
    )
}
