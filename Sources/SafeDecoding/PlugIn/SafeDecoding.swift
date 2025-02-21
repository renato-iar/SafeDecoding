import Foundation

@attached(
    extension,
    conformances: Decodable,
    names:
        named(CodingKeys),
        named(SafeDecodable),
        named(Decodable),
        named(init(from:)),
        named(encode(to:))
)
public macro SafeDecoding(
    reporter: SafeDecodingReporter? = nil,
    shouldImplementEncoding: Bool = false
) = #externalMacro(
    module: "SafeDecodingMacros",
    type: "ClassOrStructSafeDecodingMacro"
)

@attached(
    extension,
    conformances: Decodable,
    names: arbitrary
)
public macro SafeDecoding(
    decodingStrategy: EnumCaseDecodingStrategy,
    shouldImplementEncoding: Bool = false,
    reporter: SafeDecodingReporter? = nil
) = #externalMacro(
    module: "SafeDecodingMacros",
    type: "EnumSafeDecodingMacro"
)
