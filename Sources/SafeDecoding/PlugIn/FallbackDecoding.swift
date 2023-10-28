import Foundation

@attached(peer)
public macro FallbackDecoding<Fallback>(_ value: Fallback) = #externalMacro(
    module: "SafeDecodingMacros",
    type: "FallbackDecodingMacro"
)
