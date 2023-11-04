import SwiftSyntax
import SwiftSyntaxBuilder

enum SyntaxUtils { }

extension SyntaxUtils {
    static func accessControl(decl: DeclGroupSyntax) -> AccessControl? {
        decl
            .modifiers
            .compactMap {
                $0.as(DeclModifierSyntax.self)
                    .flatMap {
                        AccessControl(rawValue: $0.name.text)
                    }
            }
            .first
    }

    static func isMissingConformanceToDecodable(conformances protocols: [TypeSyntax]) -> Bool {
        protocols.first { $0.as(IdentifierTypeSyntax.self)?.name.text == "Decodable" } != nil
    }
}

extension SyntaxUtils {
    static func extractOptionalType(
        from type: TypeSyntax
    ) -> TypeSyntax? {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return optional.wrappedType
        }

        return extractSingleGeneric(
            named: "Optional",
            from: type
        )
    }

    static func extractArrayType(
        from type: TypeSyntax
    ) -> TypeSyntax? {
        if let array = type.as(ArrayTypeSyntax.self) {
            return array.element
        }

        return extractSingleGeneric(
            named: "Array",
            from: type
        )
    }

    static func extractSetType(
        from type: TypeSyntax
    ) -> TypeSyntax? {
        return extractSingleGeneric(
            named: "Set",
            from: type
        )
    }

    static func extractDictionayTypes(
        from type: TypeSyntax
    ) -> (keyType: TypeSyntax, valueType: TypeSyntax)? {
        if let dictionary = type.as(DictionaryTypeSyntax.self) {
            return (dictionary.key, dictionary.value)
        }

        if
            let type = type.as(IdentifierTypeSyntax.self),
            type.name.text == "Dictionary",
            type.genericArgumentClause?.arguments.count == 2,
            let keyType = type.genericArgumentClause?.arguments.first?.argument,
            let valueType = type.genericArgumentClause?.arguments.last?.argument
        {
            return (keyType, valueType)
        }

        return nil
    }

    static func extractSingleGeneric(
        named genericTypeName: String,
        from type: TypeSyntax
    ) -> TypeSyntax? {
        if
            let type = type.as(IdentifierTypeSyntax.self),
            type.name.text == genericTypeName,
            type.genericArgumentClause?.arguments.count == 1
        {
            return type.genericArgumentClause?.arguments.first?.argument
        }

        return nil
    }
}
