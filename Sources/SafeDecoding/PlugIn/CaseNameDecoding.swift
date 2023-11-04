@attached(peer)
public macro CaseNameDecoding(_: StaticString) = #externalMacro(
    module: "SafeDecodingMacros",
    type: "CaseNameDecodingMacro"
)
