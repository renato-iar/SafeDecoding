import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/**
 Implements safe decoding for `struct`s

 The `SafeDecodingMacro` will add conformance to `Decodable` and custom-implement
 its initializer. For all properties suitable properties it will implement custom, safe decoding.
 Suitable properties will are typed `Array`, `Dictionary` and `Optional`, for any decodable type.

 Error reporting can be added to the macro declaration; the reporter must conform to the `SafeDecodingReporter` protocol.

 Individual properties can be decorated with macros to enhance decoding. Namely:
    - `IgnoreSafeDecoding` will prevent safe decoding to be applyed to a property
    - `@FallbackDecoding` will add a fallback value for the decoding process that will be used if decoding/retries fail
    - `@RetryDecoding` adds retries, where decoding will be performed for the specified type and then mapped to the property's type, if possible
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

        let accessModifier = if let accessControl = Self.accessControl(decl: declaration) {
            accessControl.rawValue + " "
        } else {
            ""
        }
        let typeProperties: [(PatternBindingListSyntax.Element, Bool, [Retry], SyntaxProtocol?)] = memberBlock
            .members
            .compactMap {
                $0.decl.as(VariableDeclSyntax.self)
            }
            .flatMap { decl in
                let shouldIgnoreProperty = shouldIgnore(property: decl)
                let retries = shouldIgnoreProperty ? [] : retries(for: decl)
                let fallback = shouldIgnoreProperty ? nil : fallback(for: decl)

                return decl.bindings.map { ($0, shouldIgnoreProperty, retries, fallback) }
            }

        let notComputedNonInitializedTypeProperties = typeProperties.filter { !$0.0.isComputed && !$0.0.isInitialized }
        let reporter = node.as(AttributeSyntax.self)?.arguments?.as(LabeledExprListSyntax.self)?.first?.expression

        let initializer = try InitializerDeclSyntax("\(raw: accessModifier)init(from decoder: Decoder) throws") {
            if !notComputedNonInitializedTypeProperties.isEmpty {
                CodeBlockItemSyntax(
                    """
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    """
                )
            }

            for (property, shouldIgnoreProperty, retries, fallback) in notComputedNonInitializedTypeProperties {
                if
                    let pattern = property.pattern.as(IdentifierPatternSyntax.self),
                    let propertyType = property.typeAnnotation?.type
                {
                    if shouldIgnoreProperty {
                        standardDecoderSyntax(
                            for: pattern,
                            of: propertyType,
                            reporter: reporter,
                            container: type,
                            with: [],
                            fallback: nil
                        )
                    }
                    else if let optionalElementType = extractOptionalType(from: propertyType) {
                        optionalDecoderSyntax(
                            for: pattern,
                            elementType: optionalElementType,
                            reporter: reporter,
                            container: type,
                            with: retries,
                            fallback: fallback
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
                            of: propertyType,
                            reporter: reporter,
                            container: type,
                            with: retries,
                            fallback: fallback
                        )
                    }
                }
            }
        }

        let codingKeys = try EnumDeclSyntax("private enum CodingKeys: CodingKey") {
            for (property, _, _, _) in typeProperties
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
    struct Retry {
        let type: SyntaxProtocol
        let mapper: SyntaxProtocol

        init(
            type: SyntaxProtocol,
            mapper: SyntaxProtocol
        ) {
            self.type = type
            self.mapper = mapper
        }

        init?(from syntax: SyntaxProtocol) {
            guard
                let attribute = syntax.as(AttributeSyntax.self),
                attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "RetryDecoding",
                let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
                arguments.count == 2,
                let type = arguments.first?.as(LabeledExprSyntax.self)?.expression,
                let mapper = arguments.last?.as(LabeledExprSyntax.self)?.expression
            else {
                return nil
            }

            self.type = type
            self.mapper = mapper
        }
    }

    static func retries(for declaration: VariableDeclSyntax) -> [Retry] {
        declaration
            .attributes
            .compactMap(Retry.init(from:))
    }
}

private extension SafeDecodingMacro {
    static func fallback(for declaration: VariableDeclSyntax) -> SyntaxProtocol? {
        let fallbacks = declaration
            .attributes
            .compactMap { syntax -> SyntaxProtocol? in
                guard
                    let attribute = syntax.as(AttributeSyntax.self),
                    attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "FallbackDecoding",
                    let fallback = attribute.arguments?.as(LabeledExprListSyntax.self)?.first
                else {
                    return nil
                }
                return fallback
            }

        return fallbacks.first
    }
}

private extension SafeDecodingMacro {
    enum AccessControl: String {
        case `open`
        case `public`
        case `package`
        case `internal`
        case `private`
    }

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
        of type: TypeSyntax,
        reporter: ExprSyntax?,
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol?
    ) -> CodeBlockItemSyntax {
        return if let reporter {
            standardDecoderSyntaxWithReporting(
                for: pattern,
                of: type,
                reporter: reporter,
                container: container,
                with: retries,
                fallback: fallback
            )
        } else {
            standardDecoderSyntaxNoReporting(
                for: pattern,
                of: type,
                container: container,
                with: retries,
                fallback: fallback
            )
        }
    }

    static func standardDecoderSyntaxNoReporting(
        for pattern: IdentifierPatternSyntax,
        of type: TypeSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol?
    ) -> CodeBlockItemSyntax {
        return if let fallback {
            standardDecoderSyntaxNoReportingWithFallback(
                for: pattern,
                of: type,
                container: container,
                with: retries,
                fallback: fallback
            )
        } else {
            standardDecoderSyntaxNoReportingNoFallback(
                for: pattern,
                of: type,
                container: container,
                with: retries
            )
        }
    }

    static func standardDecoderSyntaxWithReporting(
        for pattern: IdentifierPatternSyntax,
        of type: TypeSyntax,
        reporter: ExprSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol?
    ) -> CodeBlockItemSyntax {
        return if let fallback {
            standardDecoderSyntaxWithReportingWithFallback(
                for: pattern,
                of: type,
                reporter: reporter,
                container: container,
                with: retries,
                fallback: fallback
            )
        } else {
            standardDecoderSyntaxWithReportingNoFallback(
                for: pattern,
                of: type,
                reporter: reporter,
                container: container,
                with: retries
            )
        }
    }

    static func standardDecoderSyntaxNoReportingNoFallback(
        for pattern: IdentifierPatternSyntax,
        of type: TypeSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry]
    ) -> CodeBlockItemSyntax {
        return if retries.isEmpty {
            """
            self.\(pattern.identifier) = try container.decode(\(type).self, forKey: .\(pattern.identifier))
            """
        } else {
            """
            do {
                self.\(pattern.identifier) = try container.decode(\(type).self, forKey: .\(pattern.identifier))
            } catch {
                if let retry = \(raw: retries.map { "(try? container.decode(\($0.type), forKey: .\(pattern.identifier))).flatMap(\($0.mapper))" }.joined(separator: " ?? ")) {
                    self.\(pattern.identifier) = retry
                } else {
                    throw error
                }
            }
            """
        }
    }

    static func standardDecoderSyntaxNoReportingWithFallback(
        for pattern: IdentifierPatternSyntax,
        of type: TypeSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol
    ) -> CodeBlockItemSyntax {
        return if retries.isEmpty {
            """
            do {
                self.\(pattern.identifier) = try container.decode(\(type).self, forKey: .\(pattern.identifier))
            } catch {
                self.\(pattern.identifier) = \(fallback)
            }
            """
        } else {
            """
            do {
                self.\(pattern.identifier) = try container.decode(\(type).self, forKey: .\(pattern.identifier))
            } catch {
                self.\(pattern.identifier) = \(raw: retries.map { "(try? container.decode(\($0.type), forKey: .\(pattern.identifier))).flatMap(\($0.mapper)) ?? " }.joined()) \(fallback)
            }
            """
        }
    }

    static func standardDecoderSyntaxWithReportingNoFallback(
        for pattern: IdentifierPatternSyntax,
        of type: TypeSyntax,
        reporter: ExprSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry]
    ) -> CodeBlockItemSyntax {
        return if retries.isEmpty {
            """
            self.\(pattern.identifier) = try container.decode(\(type).self, forKey: .\(pattern.identifier))
            """
        } else {
            """
            do {
                self.\(pattern.identifier) = try container.decode(\(type).self, forKey: .\(pattern.identifier))
            } catch {
                if let retry = \(raw: retries.map { "(try? container.decode(\($0.type), forKey: .\(pattern.identifier))).flatMap(\($0.mapper))" }.joined(separator: " ?? ")) {
                    self.\(pattern.identifier) = retry
                    \(reporter).report(error: error, of: "\(raw: pattern.identifier.description)", decoding: \(type).self, in: (\(container)).self)
                } else {
                    throw error
                }
            }
            """
        }
    }

    static func standardDecoderSyntaxWithReportingWithFallback(
        for pattern: IdentifierPatternSyntax,
        of type: TypeSyntax,
        reporter: ExprSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol
    ) -> CodeBlockItemSyntax {
        return if retries.isEmpty {
            """
            do {
                self.\(pattern.identifier) = try container.decode(\(type).self, forKey: .\(pattern.identifier))
            } catch {
                self.\(pattern.identifier) = \(fallback)
                \(reporter).report(error: error, of: "\(raw: pattern.identifier.description)", decoding: \(type).self, in: (\(container)).self)
            }
            """
        } else {
            """
            do {
                self.\(pattern.identifier) = try container.decode(\(type).self, forKey: .\(pattern.identifier))
            } catch {
                self.\(pattern.identifier) = \(raw: retries.map { "(try? container.decode(\($0.type), forKey: .\(pattern.identifier))).flatMap(\($0.mapper)) ?? " }.joined()) \(fallback)
                \(reporter).report(error: error, of: "\(raw: pattern.identifier.description)", decoding: \(type).self, in: (\(container)).self)
            }
            """
        }
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
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol?
    ) -> CodeBlockItemSyntax {
        return if let reporter {
            optionalDecoderSyntaxWithReporting(
                for: pattern,
                elementType: elementType,
                reporter: reporter,
                container: container,
                with: retries,
                fallback: fallback)
        } else {
            optionalDecoderSyntaxNoReporting(
                for: pattern,
                elementType: elementType,
                container: container,
                with: retries,
                fallback: fallback
            )
        }
    }

    static func optionalDecoderSyntaxNoReporting(
        for pattern: IdentifierPatternSyntax,
        elementType: IdentifierTypeSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol?
    ) -> CodeBlockItemSyntax {
        return if let fallback {
            optionalDecoderSyntaxNoReportingWithFallback(
                for: pattern,
                of: elementType,
                container: container,
                with: retries,
                fallback: fallback
            )
        } else {
            optionalDecoderSyntaxNoReportingNoFallback(
                for: pattern,
                of: elementType,
                container: container,
                with: retries
            )
        }
    }

    static func optionalDecoderSyntaxWithReporting(
        for pattern: IdentifierPatternSyntax,
        elementType: IdentifierTypeSyntax,
        reporter: ExprSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol?
    ) -> CodeBlockItemSyntax {
        return if let fallback {
            optionalDecoderSyntaxWithReportingWithFallback(
                for: pattern,
                of: elementType,
                reporter: reporter,
                container: container,
                with: retries,
                fallback: fallback
            )
        } else {
            optionalDecoderSyntaxWithReportingNoFallback(
                for: pattern,
                of: elementType,
                reporter: reporter,
                container: container,
                with: retries
            )
        }
    }

    static func optionalDecoderSyntaxNoReportingNoFallback(
        for pattern: IdentifierPatternSyntax,
        of type: IdentifierTypeSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry]
    ) -> CodeBlockItemSyntax {
        """
        self.\(pattern.identifier) = try? container.decode(\(type).self, forKey: .\(pattern.identifier)) \(raw: retries.map { " ?? (try? container.decode(\($0.type), forKey: .\(pattern.identifier))).flatMap(\($0.mapper))" }.joined())
        """
    }

    static func optionalDecoderSyntaxNoReportingWithFallback(
        for pattern: IdentifierPatternSyntax,
        of type: IdentifierTypeSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol
    ) -> CodeBlockItemSyntax {
        """
        self.\(pattern.identifier) = try? container.decode(\(type).self, forKey: .\(pattern.identifier)) \(raw: retries.map { " ?? (try? container.decode(\($0.type), forKey: .\(pattern.identifier))).flatMap(\($0.mapper))" }.joined()) ?? \(fallback)
        """
    }

    static func optionalDecoderSyntaxWithReportingNoFallback(
        for pattern: IdentifierPatternSyntax,
        of type: IdentifierTypeSyntax,
        reporter: ExprSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry]
    ) -> CodeBlockItemSyntax {
        """
        do {
            self.\(pattern.identifier) = try container.decodeIfPresent(\(type).self, forKey: .\(pattern.identifier))
        } catch {
            self.\(pattern.identifier) = \(raw: retries.map { "(try? container.decode(\($0.type), forKey: .\(pattern.identifier))).flatMap(\($0.mapper)) ?? " }.joined())nil
            \(reporter).report(error: error, of: "\(raw: pattern.identifier.description)", decoding: \(type)?.self, in: (\(container)).self)
        }
        """
    }

    static func optionalDecoderSyntaxWithReportingWithFallback(
        for pattern: IdentifierPatternSyntax,
        of type: IdentifierTypeSyntax,
        reporter: ExprSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol
    ) -> CodeBlockItemSyntax {
        """
        do {
            self.\(pattern.identifier) = try container.decode(\(type).self, forKey: .\(pattern.identifier))
        } catch {
            self.\(pattern.identifier) = \(raw: retries.map { "(try? container.decode(\($0.type), forKey: .\(pattern.identifier))).flatMap(\($0.mapper)) ?? " }.joined())\(fallback)
            \(reporter).report(error: error, of: "\(raw: pattern.identifier.description)", decoding: \(type)?.self, in: (\(container)).self)
        }
        """
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
                let decodedArray = try container.decode([SafeDecodable<\(elementType)>].self, forKey: .\(pattern.identifier))
                var items: [\(elementType)] = []

                for (index, item) in decodedArray.enumerated() {
                    if let decoded = item.decoded {
                        items.append(decoded)
                    } else if let error = item.error {
                        \(reporter).report(error: error, decoding: \(elementType).self, at: index, of: "\(raw: pattern.identifier.description)", in: (\(container)).self)
                    }
                }

                self.\(pattern.identifier) = items
            } catch {
                self.\(pattern.identifier) = []
                \(reporter).report(error: error, of: "\(raw: pattern.identifier.description)", decoding: [\(elementType)].self, in: (\(container)).self)
            }
            """
        } else {
            """
            self.\(pattern.identifier) = ((try? container.decode([SafeDecodable<\(elementType)>].self, forKey: .\(pattern.identifier))) ?? []).compactMap { $0.decoded }
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
                let decodedItems = try container.decode([SafeDecodable<\(elementType)>].self, forKey: .\(pattern.identifier))
                var items: Set<\(elementType)> = []

                for item in decodedItems {
                    if let decoded = item.decoded {
                        items.insert(decoded)
                    } else if let error = item.error {
                        \(reporter).report(error: error, decoding: \(elementType).self, of: "\(raw: pattern.identifier.description)", in: (\(container)).self)
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
            self.\(pattern.identifier) = ((try? container.decode([SafeDecodable<\(elementType)>].self, forKey: .\(pattern.identifier))) ?? []).reduce(into: Set<\(elementType)>()) { set, safe in _ = safe.decoded.flatMap { value in set.insert(value) } }
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
                let decodedItems = try container.decode([\(keyType): SafeDecodable<\(valueType)>].self, forKey: .\(pattern.identifier))
                var items: [\(keyType): \(valueType)] = [:]

                for (key, value) in decodedItems {
                    if let decoded = value.decoded {
                        items[key] = decoded
                    } else if let error = value.error {
                        \(reporter).report(error: error, decoding: \(valueType).self, forKey: key, of: "\(raw: pattern.identifier.description)", in: (\(container)).self)
                    }
                }

                self.\(pattern.identifier) = items
            } catch {
                self.\(pattern.identifier) = [:]
                \(reporter).report(error: error, of: "\(raw: pattern.identifier.description)", decoding: [\(keyType): SafeDecodable<\(valueType)>].self, in: (\(container)).self)
            }
            """
        } else {
            """
            self.\(pattern.identifier) = ((try? container.decode([\(keyType): SafeDecodable<\(valueType)>].self, forKey: .\(pattern.identifier))) ?? [:]).reduce(into: [:]) { $0[$1.key] = $1.value.decoded }
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
