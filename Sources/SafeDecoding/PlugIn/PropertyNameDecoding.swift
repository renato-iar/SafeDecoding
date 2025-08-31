@attached(peer)
public macro PropertyNameDecoding(_: StaticString) = #externalMacro(
    module: "SafeDecodingMacros",
    type: "PropertyNameDecodingMacro"
)

@attached(peer)
public macro PropertyNameDecoding(casing: PropertyNameCasingStrategy) = #externalMacro(
    module: "SafeDecodingMacros",
    type: "PropertyNameDecodingMacro"
)
