/**
 The ``OptionalDecoding(_:)`` macros allow for optional decoding
 to be performed in class/struct properties.
 This is only applicable to optional types, where:
 - if the condition evaluates to `true`, standard decoding rules apply
 - if the condition evaluates to `false`, the property will directly be set to `nil`
 */

@attached(peer)
public macro OptionalDecoding(_ condition: @escaping () -> Bool) = #externalMacro(
    module: "SafeDecodingMacros",
    type: "OptionalDecodingMacro"
)

@attached(peer)
public macro OptionalDecoding(_ condition: Bool) = #externalMacro(
    module: "SafeDecodingMacros",
    type: "OptionalDecodingMacro"
)
