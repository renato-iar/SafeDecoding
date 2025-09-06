import SwiftCompilerPlugin
import SwiftSyntaxMacros

// MARK: - Plug-in -

@main
struct SafeDecodingPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ClassOrStructSafeDecodingMacro.self,
        EnumSafeDecodingMacro.self,
        IgnoreSafeDecodingMacro.self,
        RetryDecodingMacro.self,
        FallbackDecodingMacro.self,
        CaseNameDecodingMacro.self,
        OptionalDecodingMacro.self,
        PropertyNameDecodingMacro.self,
        FallbackCaseDecodingMacro.self
    ]
}
