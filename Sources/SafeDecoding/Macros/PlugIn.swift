import SwiftCompilerPlugin
import SwiftSyntaxMacros

// MARK: - Plug-in -

@main
struct SafeDecodingPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SafeDecodingMacro.self,
        IgnoreSafeDecodingMacro.self,
        RetryDecodingMacro.self,
        FallbackDecodingMacro.self
    ]
}
