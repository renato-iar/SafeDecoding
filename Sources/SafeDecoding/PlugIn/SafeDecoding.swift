@attached(
    extension,
    conformances: Decodable,
    names:
        named(CodingKeys),
        named(SafeDecodable),
        named(Decodable),
        named(init(from:))
)
public macro SafeDecoding() = #externalMacro(
    module: "SafeDecodingMacros",
    type: "SafeDecodingMacro"
)
