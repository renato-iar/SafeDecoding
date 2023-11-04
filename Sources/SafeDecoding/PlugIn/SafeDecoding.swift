import Foundation

@attached(
    extension,
    conformances: Decodable,
    names:
        named(CodingKeys),
        named(SafeDecodable),
        named(Decodable),
        named(init(from:))
)
public macro SafeDecoding(reporter: SafeDecodingReporter? = nil) = #externalMacro(
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
    reporter: SafeDecodingReporter? = nil
) = #externalMacro(
    module: "SafeDecodingMacros",
    type: "EnumSafeDecodingMacro"
)
