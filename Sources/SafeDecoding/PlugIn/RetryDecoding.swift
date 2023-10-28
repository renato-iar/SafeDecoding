import Foundation

@attached(peer)
public macro RetryDecoding<Alternative: Decodable, T>(_: Alternative.Type, map: (Alternative) -> T?) = #externalMacro(
    module: "SafeDecodingMacros",
    type: "RetryDecodingMacro"
)
