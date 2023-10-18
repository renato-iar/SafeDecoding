public protocol SafeDecodingReporter {
    func report<Container, Property>(
        error: Error,
        of propertyName: String,
        decoding propertyType: Property.Type,
        in containerType: Container.Type
    )

    func report<Container, Item>(
        error: Error,
        decoding itemType: Item.Type,
        at index: Int,
        of propertyName: String,
        in containerType: Container.Type
    )

    func report<Container, Item>(
        error: Error,
        decoding itemType: Item.Type,
        of propertyName: String,
        in containerType: Container.Type
    )

    func report<Container, Key: Hashable, Item>(
        error: Error,
        decoding itemType: Item.Type,
        forKey key: Key,
        of propertyName: String,
        in containerType: Container.Type
    )
}
