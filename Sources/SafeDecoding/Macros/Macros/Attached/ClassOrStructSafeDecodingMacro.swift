import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/**
 Implements safe decoding for `struct`s, `class`es and `actor`s.

 This implementation covers types that have a fixed property storage layout. Enums, which have a variable
 storage layout (depending on the case) will be covered by the ``EnumSafeDecodingMacro``.

 The `ClassOrStructSafeDecodingMacro` will add conformance to `Decodable` and custom-implement
 its initializer. For all properties suitable properties it will implement custom, safe decoding.
 Suitable properties will are typed `Array`, `Dictionary` and `Optional`, for any decodable type.

 Error reporting can be added to the macro declaration; the reporter must conform to the `SafeDecodingReporter` protocol.

 Individual properties can be decorated with macros to enhance decoding. Namely:
    - `IgnoreSafeDecoding` will prevent safe decoding to be applyed to a property
    - `@FallbackDecoding` will add a fallback value for the decoding process that will be used if decoding/retries fail
    - `@RetryDecoding` adds retries, where decoding will be performed for the specified type and then mapped to the property's type, if possible
 */
public enum ClassOrStructSafeDecodingMacro {}

// MARK: - ExtensionMacro

extension ClassOrStructSafeDecodingMacro: ExtensionMacro {
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
        } else if let actorDecl = declaration.as(ActorDeclSyntax.self) {
            memberBlock = actorDecl.memberBlock
        } else {
            context.addDiagnostics(
                from: ClassOrStructSafeDecodingMacro.Errors.onlyApplicableToStructOrClassTypes,
                node: node
            )

            return []
        }

        let accessModifier = if let accessControl = SyntaxUtils.accessControl(decl: declaration) {
            accessControl.rawValue + " "
        } else {
            ""
        }
        let typeProperties: [(PatternBindingListSyntax.Element, codingKeyName: String?, ignore: Bool, retries: [Retry], fallback: SyntaxProtocol?, condition: SyntaxProtocol?)] = memberBlock
            .members
            .compactMap {
                $0.decl.as(VariableDeclSyntax.self)
            }
            .flatMap { (decl: VariableDeclSyntax) in
                let shouldIgnoreProperty = shouldIgnore(property: decl)
                let retries = shouldIgnoreProperty ? [] : retries(for: decl)
                let fallback = shouldIgnoreProperty ? nil : fallback(for: decl)
                let conditional: SyntaxProtocol? = shouldIgnoreProperty ? nil : condition(for: decl)
                let codingKeyName = Self.propertyNameOverride(for: decl)

                return decl.bindings.map { ($0, codingKeyName, shouldIgnoreProperty, retries, fallback, conditional) }
            }

        let notComputedNonInitializedTypeProperties = typeProperties.filter { !$0.0.isComputed && !$0.0.isInitialized }
        let reporter = node.arguments?.as(LabeledExprListSyntax.self)?.first { $0.label?.text == "reporter" }?.expression

        let initializer = try InitializerDeclSyntax("\(raw: accessModifier)init(from decoder: Decoder) throws") {
            if !notComputedNonInitializedTypeProperties.isEmpty {
                CodeBlockItemSyntax(
                    """
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    """
                )
            }

            for (property, codingKeyName, shouldIgnoreProperty, retries, fallback, condition) in notComputedNonInitializedTypeProperties {
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
                    } else if let optionalElementType = SyntaxUtils.extractOptionalType(from: propertyType) {
                        optionalDecoderSyntax(
                            for: pattern,
                            elementType: optionalElementType,
                            reporter: reporter,
                            container: type,
                            with: retries,
                            fallback: fallback,
                            condition: condition
                        )
                    } else if let arrayElementType = SyntaxUtils.extractArrayType(from: propertyType) {
                        arrayDecoderSyntax(
                            for: pattern,
                            elementType: arrayElementType,
                            reporter: reporter,
                            container: type
                        )
                    } else if let setElementType = SyntaxUtils.extractSetType(from: propertyType) {
                        setDecoderSyntax(
                            for: pattern,
                            elementType: setElementType,
                            reporter: reporter,
                            container: type
                        )
                    } else if let (keyType, valueType) = SyntaxUtils.extractDictionayTypes(from: propertyType) {
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

        let codingKeys = try EnumDeclSyntax("private enum CodingKeys: String, CodingKey") {
            for (property, codingKeyName, _, _, _, _) in typeProperties
            where !property.isComputed && !property.isInitialized
            {
                if let pattern = property.pattern.as(IdentifierPatternSyntax.self) {
                    """
                    case \(pattern.identifier)\(raw: (codingKeyName.flatMap { name in " = \"\(name)\"" } ?? ""))
                    """
                }
            }
        }

        let decoderExtensionDecl = try ExtensionDeclSyntax(
            SyntaxUtils.isMissingConformanceToDecodable(conformances: protocols) ?
            "extension \(type): Decodable" :
                "extension \(type)"
        ) {
            codingKeys
            initializer
        }

        if Self.shouldImplementEncoding(for: node) {
            let encoderExtensionDecl = try Self.encode(
                providingExtensionsOf: type,
                notComputedNonInitializedTypeProperties: notComputedNonInitializedTypeProperties,
                accessModifier: accessModifier,
                context: context
            )

            return [
                decoderExtensionDecl,
                encoderExtensionDecl
            ]
        } else {
            return [
                decoderExtensionDecl
            ]
        }
    }
}

// MARK: - Utils -

private extension ClassOrStructSafeDecodingMacro {
    static func retries(for declaration: VariableDeclSyntax) -> [Retry] {
        declaration
            .attributes
            .compactMap(Retry.init(from:))
    }

    static func propertyNameOverride(
        for case: VariableDeclSyntax
    ) -> String? {
        `case`
            .attributes
            .first { attribute in
                attribute
                    .as(AttributeSyntax.self)?
                    .attributeName
                    .as(IdentifierTypeSyntax.self)?
                    .name
                    .text == "PropertyNameDecoding"
            }
            .flatMap { attribute in
                attribute
                    .as(AttributeSyntax.self)?
                    .arguments?
                    .as(LabeledExprListSyntax.self)?
                    .first?
                    .expression
                    .as(StringLiteralExprSyntax.self)?
                    .segments
                    .first?
                    .as(StringSegmentSyntax.self)?
                    .content
                    .text
            }
    }
}

private extension ClassOrStructSafeDecodingMacro {
    static func attribute(_ name: String, for declaration: VariableDeclSyntax) -> SyntaxProtocol? {
        let attributes = declaration
            .attributes
            .compactMap { syntax -> SyntaxProtocol? in
                guard
                    let attribute = syntax.as(AttributeSyntax.self),
                    attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == name,
                    let arg = attribute.arguments?.as(LabeledExprListSyntax.self)?.first
                else {
                    return nil
                }
                return arg
            }

        return attributes.first
    }

    static func fallback(for declaration: VariableDeclSyntax) -> SyntaxProtocol? {
        attribute("FallbackDecoding", for: declaration)
    }

    static func condition(for declaration: VariableDeclSyntax) -> SyntaxProtocol? {
        attribute("OptionalDecoding", for: declaration)
    }
}

private extension ClassOrStructSafeDecodingMacro {
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
                        let accessorSpecifier = accessor.accessorSpecifier
                        return accessorSpecifier.text != "didSet" && accessorSpecifier.text != "willSet"
                    } != nil
                }.any
        ].any
    }
}

private extension ClassOrStructSafeDecodingMacro {
    static func shouldImplementEncoding(for attribute: AttributeSyntax) -> Bool {
        if let shouldImplementEncoding = attribute
            .arguments?
            .as(LabeledExprListSyntax.self)?
            .compactMap({ argument -> Bool? in
                if
                    argument.label?.text == "shouldImplementEncoding",
                    argument
                        .expression
                        .as(BooleanLiteralExprSyntax.self)?
                        .literal
                        .text == "true"
                {
                    return true
                }
                return nil
            }).first
        {
            return shouldImplementEncoding
        }
        return false
    }
}

// MARK: - Encoding -

private extension ClassOrStructSafeDecodingMacro {
    static func encode(
        providingExtensionsOf type: some TypeSyntaxProtocol,
        notComputedNonInitializedTypeProperties: [(PatternBindingListSyntax.Element, codingKeyName: String?, ignore: Bool, retries: [Retry], fallback: (any SyntaxProtocol)?, condition: (any SyntaxProtocol)?)],
        accessModifier: String,
        context: some MacroExpansionContext
    ) throws -> ExtensionDeclSyntax {
        for (element, _, _, _, _, _) in notComputedNonInitializedTypeProperties {
            dump(element)
        }
        return try ExtensionDeclSyntax("extension \(type)") {
            try FunctionDeclSyntax("\(raw: accessModifier) func encode(to encoder: Encoder) throws") {
                CodeBlockItemListSyntax("var container = encoder.container(keyedBy: CodingKeys.self)")

                for (element, _, _, _, _, _) in notComputedNonInitializedTypeProperties {
                    if let identifier = element.pattern.as(IdentifierPatternSyntax.self)?.identifier {
                        CodeBlockItemListSyntax("try container.encode(\(identifier), forKey: .\(raw: identifier.text))")
                    }
                }
            }
        }
    }
}

// MARK: - Decoding -

private extension ClassOrStructSafeDecodingMacro {
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

private extension ClassOrStructSafeDecodingMacro {
    static func optionalDecoderSyntax(
        for pattern: IdentifierPatternSyntax,
        elementType: TypeSyntax,
        reporter: ExprSyntax?,
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol?,
        condition: SyntaxProtocol?
    ) -> CodeBlockItemSyntax {
        let decoding = if let reporter {
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

        if let condition {
            return
                    """
                    if (\(condition)) {
                        \(decoding)
                    } else {
                        self.\(pattern.identifier) = nil
                    }
                    """
        } else {
            return decoding
        }
    }

    static func optionalDecoderSyntaxNoReporting(
        for pattern: IdentifierPatternSyntax,
        elementType: TypeSyntax,
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
        elementType: TypeSyntax,
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
        of type: TypeSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry]
    ) -> CodeBlockItemSyntax {
        """
        self.\(pattern.identifier) = (try? container.decode(\(type).self, forKey: .\(pattern.identifier))) \(raw: retries.map { " ?? (try? container.decode(\($0.type), forKey: .\(pattern.identifier))).flatMap(\($0.mapper))" }.joined())
        """
    }

    static func optionalDecoderSyntaxNoReportingWithFallback(
        for pattern: IdentifierPatternSyntax,
        of type: TypeSyntax,
        container: TypeSyntaxProtocol,
        with retries: [Retry],
        fallback: SyntaxProtocol
    ) -> CodeBlockItemSyntax {
        """
        self.\(pattern.identifier) = (try? container.decode(\(type).self, forKey: .\(pattern.identifier))) \(raw: retries.map { " ?? (try? container.decode(\($0.type), forKey: .\(pattern.identifier))).flatMap(\($0.mapper))" }.joined()) ?? \(fallback)
        """
    }

    static func optionalDecoderSyntaxWithReportingNoFallback(
        for pattern: IdentifierPatternSyntax,
        of type: TypeSyntax,
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
        of type: TypeSyntax,
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

private extension ClassOrStructSafeDecodingMacro {
    static func arrayDecoderSyntax(
        for pattern: IdentifierPatternSyntax,
        elementType: TypeSyntax,
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

private extension ClassOrStructSafeDecodingMacro {
    static func setDecoderSyntax(
        for pattern: IdentifierPatternSyntax,
        elementType: TypeSyntax,
        reporter: ExprSyntax?,
        container: TypeSyntaxProtocol
    ) -> CodeBlockItemSyntax {
        return if let reporter {
            """
            do {
                let decodedItems = try container.decode([SafeDecodable<\(elementType)>].self, forKey: .\(pattern.identifier))
                var items: Set<\(elementType)> = []

                for (index, item) in decodedItems.enumerated() {
                    if let decoded = item.decoded {
                        items.insert(decoded)
                    } else if let error = item.error {
                        \(reporter).report(error: error, decoding: \(elementType).self, at: index, of: "\(raw: pattern.identifier.description)", in: (\(container)).self)
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

private extension ClassOrStructSafeDecodingMacro {
    static func dictionaryDecoderSyntax(
        for pattern: IdentifierPatternSyntax,
        keyType: TypeSyntax,
        valueType: TypeSyntax,
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

// MARK: - Errors

extension ClassOrStructSafeDecodingMacro {
    enum Errors: Error, CustomStringConvertible {
        case onlyApplicableToStructOrClassTypes

        var description: String {
            switch self {
            case .onlyApplicableToStructOrClassTypes: "ClassOrStructSafeDecodingMacro is only applicable to structs or classes"
            }
        }
    }
}
