@attached(peer)
public macro IgnoreSafeDecoding() = #externalMacro(
    module: "SafeDecodingMacros",
    type: "IgnoreSafeDecodingMacro"
)
