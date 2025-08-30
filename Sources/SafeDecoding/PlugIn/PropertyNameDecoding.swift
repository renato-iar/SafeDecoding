@attached(peer)
public macro PropertyNameDecoding(_: StaticString) = #externalMacro(
    module: "SafeDecodingMacros",
    type: "PropertyNameDecodingMacro"
)
