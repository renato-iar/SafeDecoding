import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/**
 Implements safe decoding for `struct`s

 The `SafeDecodingMacro` will add conformance to `Decodable` and custom-implement
 its initializer. For all properties suitable properties it will implement custom, safe decoding.
 Suitable properties will are typed `Array`, `Dictionary` and `Optional`, for any decodable type.
 */
public enum SafeDecodingMacro {}

// MARK: - ExtensionMacro

extension SafeDecodingMacro: ExtensionMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let memberBlock: MemberBlockSyntax

        if let structDecl = declaration.as(StructDeclSyntax.self) {
            memberBlock = structDecl.memberBlock
        } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
            memberBlock = classDecl.memberBlock
        } else {
            context.addDiagnostics(
                from: SafeDecodingMacro.Errors.onlyApplicableToStructOrClassTypes,
                node: node
            )

            return []
        }

        let typeProperties: [(PatternBindingListSyntax.Element, Bool)] = memberBlock
            .members
            .compactMap {
                $0.decl.as(VariableDeclSyntax.self)
            }
            .flatMap { decl in
                let shouldIgnoreProperty = shouldIgnore(property: decl)
                return decl.bindings.map { ($0, shouldIgnoreProperty) }
            }

        let notComputedNonInitializedTypeProperties = typeProperties.filter { !$0.0.isComputed && !$0.0.isInitialized }
        let reporter = node.as(AttributeSyntax.self)?.arguments?.as(LabeledExprListSyntax.self)?.first?.expression

        let initializer = try InitializerDeclSyntax("public init(from decoder: Decoder) throws") {
            if !notComputedNonInitializedTypeProperties.isEmpty {
                CodeBlockItemSyntax(
                """
                let container = try decoder.container(keyedBy: CodingKeys.self)
                """
                )
            }

            for (property, shouldIgnoreProperty) in notComputedNonInitializedTypeProperties {
                if
                    let pattern = property.pattern.as(IdentifierPatternSyntax.self),
                    let propertyType = property.typeAnnotation?.type
                {
                    if shouldIgnoreProperty {
                        standardDecoderSyntax(
                            for: pattern,
                            of: propertyType
                        )
                    }
                    else if let optionalElementType = extractOptionalType(from: propertyType) {
                        optionalDecoderSyntax(
                            for: pattern,
                            elementType: optionalElementType,
                            reporter: reporter,
                            container: type
                        )
                    } else if let arrayElementType = extractArrayType(from: propertyType) {
                        arrayDecoderSyntax(
                            for: pattern,
                            elementType: arrayElementType,
                            reporter: reporter,
                            container: type
                        )
                    } else if let setElementType = extractSetType(from: propertyType) {
                        setDecoderSyntax(
                            for: pattern,
                            elementType: setElementType,
                            reporter: reporter,
                            container: type
                        )
                    } else if let (keyType, valueType) = extractDictionayTypes(from: propertyType) {
                        dictionaryDecoderSyntax(
                            for: pattern,
                            keyType: keyType,
                            valueType: valueType,
                            reporter: reporter,
                            container: type
                        )
                    } else {
                        standardDecoderSyntax(
                            for: pattern,
                            of: propertyType
                        )
                    }
                }
            }
        }

        let codingKeys = try EnumDeclSyntax("private enum CodingKeys: CodingKey") {
            for (property, _) in typeProperties
            where !property.isComputed && !property.isInitialized
            {
                if let pattern = property.pattern.as(IdentifierPatternSyntax.self) {
                    """
                    case \(pattern.identifier)
                    """
                }
            }
        }

        let extensionDecl = try ExtensionDeclSyntax(
            isMissingConformanceToDecodable(conformances: protocols) ?
                "extension \(type): Decodable" :
                "extension \(type)"
        ) {
            codingKeys
            initializer
        }

        return [
            extensionDecl
        ]
    }
}

// MARK: - Utils

private extension SafeDecodingMacro {
    static func shouldIgnore(property decl: VariableDeclSyntax) -> Bool {
        [
            decl
                .attributes
                .compactMap { attribute in
                    attribute
                        .as(AttributeSyntax.self)?
                        .attributeName.as(IdentifierTypeSyntax.self)?
                        .name.text == "IgnoreSafeDecoding"
                }.any,

            decl
                .bindings
                .compactMap { binding in
                    binding.accessorBlock?.accessors.as(AccessorDeclListSyntax.self)?.first { accessor in
                        if let accessorSpecifier = accessor.as(AccessorDeclSyntax.self)?.accessorSpecifier {
                            return accessorSpecifier.text != "didSet" && accessorSpecifier.text != "willSet"
                        }

                        return false
                    } != nil
                }.any
        ].any
    }

    static func isMissingConformanceToDecodable(conformances protocols: [TypeSyntax]) -> Bool {
        protocols.first { $0.as(IdentifierTypeSyntax.self)?.name.text == "Decodable" } != nil
    }
}

private extension SafeDecodingMacro {
    static func standardDecoderSyntax(
        for pattern: IdentifierPatternSyntax,
        of type: TypeSyntax
    ) -> CodeBlockItemSyntax {
        return CodeBlockItemSyntax(
                    """
                    self.\(pattern.identifier) = try container.decode((\(type)).self, forKey: .\(pattern.identifier))
                    """
        )
    }
}

private extension SafeDecodingMacro {
    static func extractOptionalType(
        from type: TypeSyntax
    ) -> IdentifierTypeSyntax? {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return optional.wrappedType.as(IdentifierTypeSyntax.self)
        }

        return extractSingleGeneric(
            named: "Optional",
            from: type
        )
    }

    static func optionalDecoderSyntax(
        for pattern: IdentifierPatternSyntax,
        elementType: IdentifierTypeSyntax,
        reporter: ExprSyntax?,
        container: TypeSyntaxProtocol
    ) -> CodeBlockItemSyntax {
        return if let reporter {
            """
            do {
                self.\(pattern.identifier) = try container.decode((\(elementType)).self, forKey: .\(pattern.identifier))
            } catch {
                self.\(pattern.identifier) = nil
                \(reporter).report(error: error, of: "\(raw: pattern.identifier.description)", decoding: (Optional<\(elementType)>).self, in: (\(container)).self)
            }
            """
        } else {
            """
            self.\(pattern.identifier) = try? container.decode((Optional<\(elementType)>).self, forKey: .\(pattern.identifier))
            """
        }
    }
}

private extension SafeDecodingMacro {
    static func extractArrayType(
        from type: TypeSyntax
    ) -> IdentifierTypeSyntax? {
        if let array = type.as(ArrayTypeSyntax.self) {
            return array.element.as(IdentifierTypeSyntax.self)
        }

        return extractSingleGeneric(
            named: "Array",
            from: type
        )
    }

    static func arrayDecoderSyntax(
        for pattern: IdentifierPatternSyntax,
        elementType: IdentifierTypeSyntax,
        reporter: ExprSyntax?,
        container: TypeSyntaxProtocol
    ) -> CodeBlockItemSyntax {
        return if let reporter {
            """
            do {
                let decodedArray = try container.decode((Array<SafeDecodable<\(elementType)>>).self, forKey: .\(pattern.identifier))
                var items: [\(elementType)] = []

                for (index, item) in decodedArray.enumerated() {
                    if let decoded = item.decoded {
                        items.append(decoded)
                    } else if let error = item.error {
                        \(reporter).report(error: error, decoding: (\(elementType)).self, at: index, of: "\(raw: pattern.identifier.description)", in: (\(container)).self)
                    }
                }

                self.\(pattern.identifier) = items
            } catch {
                self.\(pattern.identifier) = []
                \(reporter).report(error: error, of: "\(raw: pattern.identifier.description)", decoding: Array<\(elementType)>.self, in: (\(container)).self)
            }
            """
        } else {
            """
            self.\(pattern.identifier) = ((try? container.decode((Array<SafeDecodable<\(elementType)>>).self, forKey: .\(pattern.identifier))) ?? []).compactMap { $0.decoded }
            """
        }
    }
}

private extension SafeDecodingMacro {
    static func extractSetType(
        from type: TypeSyntax
    ) -> IdentifierTypeSyntax? {
        return extractSingleGeneric(
            named: "Set",
            from: type
        )
    }

    static func setDecoderSyntax(
        for pattern: IdentifierPatternSyntax,
        elementType: IdentifierTypeSyntax,
        reporter: ExprSyntax?,
        container: TypeSyntaxProtocol
    ) -> CodeBlockItemSyntax {
        return if let reporter {
            """
            do {
                let decodedItems = try container.decode((Array<SafeDecodable<\(elementType)>>).self, forKey: .\(pattern.identifier))
                var items: Set<\(elementType)> = []

                for item in decodedItems {
                    if let decoded = item.decoded {
                        items.insert(decoded)
                    } else if let error = item.error {
                        \(reporter).report(error: error, decoding: (\(elementType)).self, of: "\(raw: pattern.identifier.description)", in: (\(container)).self)
                    }
                }

                self.\(pattern.identifier) = items
            } catch {
                self.\(pattern.identifier) = []
                \(reporter).report(error: error, of: "\(raw: pattern.identifier.description)", decoding: Set<\(elementType)>.self, in: (\(container)).self)
            }
            """
        } else {
            """
            self.\(pattern.identifier) = ((try? container.decode((Array<SafeDecodable<\(elementType)>>).self, forKey: .\(pattern.identifier))) ?? []).reduce(into: Set<\(elementType)>()) { set, safe in _ = safe.decoded.flatMap { value in set.insert(value) } }
            """
        }
    }
}

private extension SafeDecodingMacro {
    static func extractDictionayTypes(
        from type: TypeSyntax
    ) -> (keyType: IdentifierTypeSyntax, valueType: IdentifierTypeSyntax)? {
        if
            let dictionary = type.as(DictionaryTypeSyntax.self),
            let keyType = dictionary.key.as(IdentifierTypeSyntax.self),
            let valueType = dictionary.value.as(IdentifierTypeSyntax.self)
        {
            return (keyType, valueType)
        }

        if
            let type = type.as(IdentifierTypeSyntax.self),
            type.name.text == "Dictionary",
            type.genericArgumentClause?.arguments.count == 2,
            let keyType = type.genericArgumentClause?.arguments.first?.argument.as(IdentifierTypeSyntax.self),
            let valueType = type.genericArgumentClause?.arguments.last?.argument.as(IdentifierTypeSyntax.self)
        {
            return (keyType, valueType)
        }

        return nil
    }

    static func dictionaryDecoderSyntax(
        for pattern: IdentifierPatternSyntax,
        keyType: IdentifierTypeSyntax,
        valueType: IdentifierTypeSyntax,
        reporter: ExprSyntax?,
        container: TypeSyntaxProtocol
    ) -> CodeBlockItemSyntax {
        return if let reporter {
            """
            do {
                let decodedItems = try container.decode((Dictionary<\(keyType), SafeDecodable<\(valueType)>>).self, forKey: .\(pattern.identifier))
                var items: Dictionary<\(keyType), \(valueType)> = [:]

                for (key, value) in decodedItems {
                    if let decoded = value.decoded {
                        items[key] = decoded
                    } else if let error = value.error {
                        \(reporter).report(error: error, decoding: (\(valueType)).self, forKey: key, of: "\(raw: pattern.identifier.description)", in: (\(container)).self)
                    }
                }

                self.\(pattern.identifier) = items
            } catch {
                self.\(pattern.identifier) = [:]
                \(reporter).report(error: error, of: "\(raw: pattern.identifier.description)", decoding: (Dictionary<\(keyType), SafeDecodable<\(valueType)>>).self, in: (\(container)).self)
            }
            """
        } else {
            """
            self.\(pattern.identifier) = ((try? container.decode((Dictionary<\(keyType), SafeDecodable<\(valueType)>>).self, forKey: .\(pattern.identifier))) ?? [:]).reduce(into: [:]) { $0[$1.key] = $1.value.decoded }
            """
        }
    }
}

extension SafeDecodingMacro {
    static func extractSingleGeneric(
        named genericTypeName: String,
        from type: TypeSyntax
    ) -> IdentifierTypeSyntax? {
        if
            let type = type.as(IdentifierTypeSyntax.self),
            type.name.text == genericTypeName,
            type.genericArgumentClause?.arguments.count == 1
        {
            return type.genericArgumentClause?.arguments.first?.argument.as(IdentifierTypeSyntax.self)
        }

        return nil
    }
}

// MARK: - Errors

extension SafeDecodingMacro {
    enum Errors: Error, CustomStringConvertible {
        case onlyApplicableToStructOrClassTypes

        var description: String {
            switch self {
            case .onlyApplicableToStructOrClassTypes: "SafeDecodingMacro is only applicable to structs or classes"
            }
        }
    }
}
