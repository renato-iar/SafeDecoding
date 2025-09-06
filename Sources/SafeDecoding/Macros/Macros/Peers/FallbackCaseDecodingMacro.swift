import SwiftSyntax
import SwiftSyntaxMacros

public enum FallbackCaseDecodingMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if let enumCaseDecl = declaration.as(EnumCaseDeclSyntax.self) {
            if let enumCase = enumCaseDecl.elements.first {
                if !(enumCase.parameterClause?.parameters.isEmpty != false) {
                    context.addDiagnostics(
                        from: Errors.onlyEmptyEnumCasesSupported,
                        node: declaration
                    )
                }
            }
        } else {
            context.addDiagnostics(
                from: Errors.onlyEnumCasesSupported,
                node: declaration
            )
        }

        return []
    }
}

private extension FallbackCaseDecodingMacro {
    enum Errors: Error, CustomStringConvertible {
        case onlyEnumCasesSupported
        case onlyEmptyEnumCasesSupported

        var description: String {
            switch self {
            case .onlyEnumCasesSupported: "Only enumeration cases are supported by @FallbackCaseDecoding"
            case .onlyEmptyEnumCasesSupported: "Only empty enumeration cases are suported by @FallbackCaseDecoding"
            }
        }
    }
}
