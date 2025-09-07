import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/**
 Implements safe decoding for `enum`s

 The `EnumSafeDecodingMacro` will add conformance to `Decodable` and custom-implement
 its initializer. For all properties suitable properties it will implement custom, safe decoding.
 Suitable properties will are typed `Array`, `Dictionary` and `Optional`, for any decodable type.

 Error reporting can be added to the macro declaration; the reporter must conform to the `SafeDecodingReporter` protocol.

 Individual properties can be decorated with macros to enhance decoding. Namely:
    - `CaseNameDecoding` allows the overriding of the case name of the associated coding key, or the decoding value for "natural" decoding

 The use of `CaseNameDecoding` can not only override coding-key raw value or underlying decodable string, but allow mixed-value decoding for natural decoding.
 Namely, if an enum has a raw value of a type other than string, but `CaseNameDecoding` is used on one of the cases, the decoder will use the overriden name as the raw value.
 E.g.

 ```
 @SafeDecoding(decodingStrategy: .natural)
 enum Example: Int {
 case one
 case another
 @CaseNameDecoding("yet-another")
 case yetAnother
 }
 ```

 The decoder will attempt to get a 0/1 for cases .one/.another, respectively, but will attempt to decode the string "yet-another" for .yetAnother.
 */
public enum EnumSafeDecodingMacro {}

// MARK: - ExtensionMacro

extension EnumSafeDecodingMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            context.addDiagnostics(
                from: EnumSafeDecodingMacro.Errors.onlyApplicableToEnumTypes,
                node: node
            )

            return []
        }

        let cases = enumDecl
            .memberBlock
            .members
            .compactMap({ member in
                member
                    .decl
                    .as(EnumCaseDeclSyntax.self)
            })

        let fallbacks = cases
            .compactMap { `case` -> String? in
                let hasFallback = `case`
                    .attributes
                    .contains { attribute in
                        attribute
                            .as(AttributeSyntax.self)?
                            .attributeName.as(IdentifierTypeSyntax.self)?
                            .name
                            .text  == "FallbackCaseDecoding"
                    }

                if hasFallback {
                    return `case`.elements.first?.name.text
                } else {
                    return nil
                }
            }

        if fallbacks.count > 1 {
            context.addDiagnostics(
                from: Errors.invalidMultipleFallbackEnumCases(cases: fallbacks),
                node: declaration
            )

            return []
        }

        let fallback = fallbacks.first
        let accessModifier = if let accessControl = SyntaxUtils.accessControl(decl: declaration) {
            accessControl.rawValue + " "
        } else {
            ""
        }
        let reporter = node.arguments?.as(LabeledExprListSyntax.self)?.first { $0.label?.text == "reporter" }?.expression

        let shouldImplementEncoding = shouldImplementEncoding(for: node)
        switch decodingStrategy(for: node) {
        case .none:
            let hasCaseWithParameter = cases.contains {
                $0.elements.contains {
                    $0.parameterClause?.parameters.isEmpty.not ?? false
                }
            }

            if hasCaseWithParameter {
                context.addDiagnostics(
                    from: Errors.enumNaturalStrategyWithAssociatedValues,
                    node: node
                )
            }

            if reporter != nil, fallback == nil {
                let dignostic = Diagnostic.init(
                    node: node,
                    message: EnumDiagnosticMessage(
                        message: "Reporter is not used for 'natural' safe-decoded enums, unless a fallback is defined",
                        diagnosticID: MessageID(
                            domain: "EnumSafeDecodingMacro",
                            id: "diagnostics_bad_parameter"
                        ),
                        severity: .warning
                    ),
                    fixIts: []
                )

                context.diagnose(dignostic)
            }

            var rawValueType: TypeSyntax? = enumDecl.inheritanceClause?.inheritedTypes.first?.type

            if rawValueType?.as(IdentifierTypeSyntax.self)?.name.text.in(Constants.supportedRawValueTypes) != true {
                rawValueType = nil
            }

            let decoders = try decodePlain(
                providingExtensionsOf: type,
                for: enumDecl,
                rawValueType: rawValueType,
                cases: cases,
                accessModifier: accessModifier,
                conformingTo: protocols,
                context: context,
                reporter: reporter,
                fallback: fallback
            )

            if shouldImplementEncoding {
                let encoder = try encodePlain(
                    providingExtensionsOf: type,
                    for: enumDecl,
                    rawValueType: rawValueType,
                    cases: cases,
                    accessModifier: accessModifier,
                    context: context
                )

                return decoders + [encoder]
            } else {
                return decoders
            }

        case .nested:
            let decoders = try decodeNestedObject(
                providingExtensionsOf: type,
                for: enumDecl,
                cases: cases,
                accessModifier: accessModifier,
                conformingTo: protocols,
                context: context,
                reporter: reporter,
                fallback: fallback
            )

            if shouldImplementEncoding {
                let encoder = try encodeNestedObject(
                    providingExtensionsOf: type,
                    for: enumDecl,
                    cases: cases,
                    accessModifier: accessModifier,
                    context: context
                )

                return decoders + [encoder]
            } else {
                return decoders
            }

        case let .property(name: name):
            let decoders = try decodeObjectByProperty(
                providingExtensionsOf: type,
                casingPropertyName: name,
                for: enumDecl,
                cases: cases,
                accessModifier: accessModifier,
                conformingTo: protocols,
                context: context,
                reporter: reporter,
                fallback: fallback
            )

            if shouldImplementEncoding {
                let encoder = try encodeObjectByProperty(
                    providingExtensionsOf: type,
                    casingPropertyName: name,
                    for: enumDecl,
                    cases: cases,
                    accessModifier: accessModifier,
                    context: context
                )

                return decoders + [encoder]
            } else {
                return decoders
            }
        }
    }
}


// MARK: - Decoding

private extension EnumSafeDecodingMacro {

    // MARK: Decoders

    static func decodeNestedObject(
        providingExtensionsOf type: some TypeSyntaxProtocol,
        for enum: EnumDeclSyntax,
        cases: [EnumCaseDeclSyntax],
        accessModifier: String,
        conformingTo protocols: [TypeSyntax],
        context: some MacroExpansionContext,
        reporter: ExprSyntax?,
        fallback: String?
    ) throws -> [ExtensionDeclSyntax] {
        let enumTypeName = `enum`.name.text
        let rootCodingKeysName = "CodingKeys"

        func rootCodingKeysCase(for `case`: EnumCaseDeclSyntax) -> String? {
            guard
                let caseName = `case`.elements.first?.name.text
            else {
                return nil
            }

            return if let override = Self.caseNameOverride(for: `case`) {
                "case \(caseName) = \"\(override)\""
            } else {
                "case \(caseName)"
            }
        }

        func caseDecoding(for `case`: EnumCaseDeclSyntax) -> [String] {
            `case`
                .elements
                .compactMap { element in
                    let name = element.name.text
                    if element.parameterClause?.parameters.isEmpty == false {
                        return "case .\(name): self = try Self.decode_\(name)(container: container.nestedContainer(keyedBy: \(rootCodingKeysName)_\(name).self, forKey: .\(name)))"
                    } else {
                        return "case .\(name): self = .\(name)"
                    }
                }
        }

        let extensionDecl = try ExtensionDeclSyntax(
            SyntaxUtils.isMissingConformanceToDecodable(conformances: protocols) ?
            "extension \(type): Decodable" :
                "extension \(type)"
        ) {
            // Root coding keys
            try EnumDeclSyntax("private enum \(raw: rootCodingKeysName): String, CodingKey") {
                for rootCodingKeysCase in cases.compactMap(rootCodingKeysCase(for:)) {
                    try EnumCaseDeclSyntax("\(raw: rootCodingKeysCase)")
                }
            }

            // Nested coding keys
            for `case` in cases {
                for element in `case`.elements {
                    let elementName = element.name.text

                    if
                        let parameters = element
                            .parameterClause?
                            .parameters
                    {
                        try EnumDeclSyntax("private enum \(raw: rootCodingKeysName)_\(raw: elementName): String, CodingKey") {
                            for (index, parameter) in parameters.enumerated() {
                                let parameterName = parameter.firstName?.text ?? "_\(index)"
                                try EnumCaseDeclSyntax("case \(raw: parameterName)")
                            }
                        }
                    } else {
                        try EnumDeclSyntax("private enum \(raw: rootCodingKeysName)_\(raw: elementName): CodingKey") {
                        }
                    }
                }
            }

            // Decoding functions
            for `case` in cases {
                for element in `case`.elements where element.parameterClause?.parameters.isEmpty == false {
                    try decode(
                        element: element,
                        rootCodingKeysName: rootCodingKeysName
                    )

                    for (index, parameter) in (element.parameterClause?.parameters ?? []).enumerated() {
                        try decode(
                            parameter: parameter,
                            at: index,
                            of: element,
                            in: enumTypeName,
                            rootCodingKeysName: rootCodingKeysName,
                            reporter: reporter
                        )
                    }
                }
            }

            // Initializer
            if let fallback {
                if let reporter {
                    MemberBlockItemListSyntax(
                        """
                        \(raw: accessModifier)init(from decoder: Decoder) throws {
                            do {
                                let container = try decoder.container(keyedBy: \(raw: rootCodingKeysName).self)
                                var allKeys = ArraySlice(container.allKeys)
                                guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                                    throw DecodingError.typeMismatch(\(type).self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                                }
                        
                                switch onlyKey {
                                \(raw: cases.map(caseDecoding(for:)).flatMap { $0 }.joined(separator: "\n"))
                                }
                            } catch {
                                (\(reporter)).report(error: error, decoding: "\(raw: enumTypeName).self")
                                self = .\(raw: fallback)
                            }
                        }
                        """
                    )
                } else {
                    MemberBlockItemListSyntax(
                        """
                        \(raw: accessModifier)init(from decoder: Decoder) throws {
                            do {
                                let container = try decoder.container(keyedBy: \(raw: rootCodingKeysName).self)
                                var allKeys = ArraySlice(container.allKeys)
                                guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                                    throw DecodingError.typeMismatch(\(type).self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                                }
                        
                                switch onlyKey {
                                \(raw: cases.map(caseDecoding(for:)).flatMap { $0 }.joined(separator: "\n"))
                                }
                            } catch {
                                self = .\(raw: fallback)
                            }
                        }
                        """
                    )
                }
            } else {
                MemberBlockItemListSyntax(
                    """
                    \(raw: accessModifier)init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: \(raw: rootCodingKeysName).self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(\(type).self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }

                        switch onlyKey {
                        \(raw: cases.map(caseDecoding(for:)).flatMap { $0 }.joined(separator: "\n"))
                        }
                    }
                    """
                )
            }
        }

        return [
            extensionDecl
        ]
    }

    static func decodeObjectByProperty(
        providingExtensionsOf type: some TypeSyntaxProtocol,
        casingPropertyName: String,
        for enum: EnumDeclSyntax,
        cases: [EnumCaseDeclSyntax],
        accessModifier: String,
        conformingTo protocols: [TypeSyntax],
        context: some MacroExpansionContext,
        reporter: ExprSyntax?,
        fallback: String?
    ) throws -> [ExtensionDeclSyntax] {
        let plainCasingPropertyName = casingPropertyName.plain
        let enumTypeName = `enum`.name.text
        let rootCodingKeysName = "CodingKeys"

        func rootCodingKeysCase(for `case`: EnumCaseDeclSyntax) -> String? {
            guard
                let caseName = `case`.elements.first?.name.text
            else {
                return nil
            }

            return if let override = Self.caseNameOverride(for: `case`) {
                "case \(caseName) = \"\(override)\""
            } else {
                "case \(caseName)"
            }
        }

        func caseDecoding(for `case`: EnumCaseDeclSyntax) -> [String] {
            `case`
                .elements
                .compactMap { element in
                    let name = element.name.text
                    if element.parameterClause?.parameters.isEmpty == false {
                        return "case .\(name): self = try Self.decode_\(name)(container: decoder.container(keyedBy: \(rootCodingKeysName)_\(name).self))"
                    } else {
                        return "case .\(name): self = .\(name)"
                    }
                }
        }

        let extensionDecl = try ExtensionDeclSyntax(
            SyntaxUtils.isMissingConformanceToDecodable(conformances: protocols) ?
                "extension \(type): Decodable" :
                "extension \(type)"
        ) {
            // Decision enum
            try EnumDeclSyntax("private enum CasingKeys: String, Decodable") {
                for rootCodingKeysCase in cases.compactMap(rootCodingKeysCase(for:)) {
                    try EnumCaseDeclSyntax("\(raw: rootCodingKeysCase)")
                }
            }

            try EnumDeclSyntax("private enum \(raw: rootCodingKeysName): String, CodingKey") {
                try EnumCaseDeclSyntax("case \(raw: plainCasingPropertyName) = \"\(raw: casingPropertyName)\"")
            }

            // Nested coding keys
            for `case` in cases {
                for element in `case`.elements where element.parameterClause?.parameters.isEmpty == false {
                    if
                        let parameters = element
                            .parameterClause?
                            .parameters
                    {
                        try EnumDeclSyntax("private enum \(raw: rootCodingKeysName)_\(raw: element.name.text): String, CodingKey") {
                            for (index, parameter) in parameters.enumerated() {
                                try EnumCaseDeclSyntax("case \(raw: parameter.firstName?.text ?? "_\(index)")")
                            }
                        }
                    }
                }
            }

            // Decoding functions
            for `case` in cases {
                for element in `case`.elements where element.parameterClause?.parameters.isEmpty == false {
                    try decode(
                        element: element,
                        rootCodingKeysName: rootCodingKeysName
                    )

                    for (index, parameter) in (element.parameterClause?.parameters ?? []).enumerated() {
                        try decode(
                            parameter: parameter,
                            at: index,
                            of: element,
                            in: enumTypeName,
                            rootCodingKeysName: rootCodingKeysName,
                            reporter: reporter
                        )
                    }
                }
            }

            if let fallback {
                if let reporter {
                    MemberBlockItemListSyntax(
                        """
                        \(raw: accessModifier)init(from decoder: Decoder) throws {
                            do {
                                switch try decoder.container(keyedBy: \(raw: rootCodingKeysName).self).decode(CasingKeys.self, forKey: .\(raw: plainCasingPropertyName)) {
                                \(raw: cases.map(caseDecoding(for:)).flatMap { $0 }.joined(separator: "\n"))
                                }
                            } catch {
                                (\(reporter)).report(error: error, in: \(raw: enumTypeName).self)
                                self = .\(raw: fallback)
                            }
                        }
                        """
                    )
                } else {
                    MemberBlockItemListSyntax(
                        """
                        \(raw: accessModifier)init(from decoder: Decoder) throws {
                            do {
                                switch try decoder.container(keyedBy: \(raw: rootCodingKeysName).self).decode(CasingKeys.self, forKey: .\(raw: plainCasingPropertyName)) {
                                \(raw: cases.map(caseDecoding(for:)).flatMap { $0 }.joined(separator: "\n"))
                                }
                            } catch {
                                self = .\(raw: fallback)
                            }
                        }
                        """
                    )
                }
            } else {
                MemberBlockItemListSyntax(
                    """
                    \(raw: accessModifier)init(from decoder: Decoder) throws {
                        switch try decoder.container(keyedBy: \(raw: rootCodingKeysName).self).decode(CasingKeys.self, forKey: .\(raw: plainCasingPropertyName)) {
                        \(raw: cases.map(caseDecoding(for:)).flatMap { $0 }.joined(separator: "\n"))
                        }
                    }
                    """
                )
            }
        }

        return [
            extensionDecl
        ]
    }

    static func decodePlain(
        providingExtensionsOf type: some TypeSyntaxProtocol,
        for enum: EnumDeclSyntax,
        rawValueType: TypeSyntax?,
        cases: [EnumCaseDeclSyntax],
        accessModifier: String,
        conformingTo protocols: [TypeSyntax],
        context: some MacroExpansionContext,
        reporter: ExprSyntax?,
        fallback: String?
    ) throws -> [ExtensionDeclSyntax] {
        let enumTypeName = `enum`.name.text
        var overridenCaseNames: [(String, String)] = []
        var nonOverridenCaseNames: [String] = []

        let _ = cases.forEach { `case` in

            let caseNameOverride = Self.caseNameOverride(for: `case`)
            var elements = `case`.elements.map(\.name.text)

            guard !elements.isEmpty else { return }

            if let caseNameOverride {
                overridenCaseNames.append((elements[0], caseNameOverride))
                elements.remove(at: .zero)
            }

            nonOverridenCaseNames.append(contentsOf: elements)
        }

        func decoderBlock() throws -> CodeBlockItemListSyntax {
            var items: [CodeBlockItemSyntax] = []

            items.append("let container = try decoder.singleValueContainer()")

            if !overridenCaseNames.isEmpty {
                items.append(
                    CodeBlockItemSyntax(
                        item: .expr(
                            ExprSyntax(
                                try SwitchExprSyntax("switch try? container.decode(String.self)") {
                                    for (caseName, overrideCaseName) in overridenCaseNames {
                                        SwitchCaseSyntax("case \"\(raw: overrideCaseName)\":") {
                                            CodeBlockItemListSyntax {
                                                CodeBlockItemSyntax("self = .\(raw: caseName)")
                                                CodeBlockItemSyntax("return")
                                            }
                                        }
                                    }

                                    SwitchCaseSyntax("default:") {
                                        CodeBlockItemSyntax("break")
                                    }
                                }
                            )
                            )
                    )
                )
            }

            if !nonOverridenCaseNames.isEmpty {
                if let rawValueType {
                    items.append(
                        """
                        if let `case` = Self.init(rawValue: try container.decode(\(rawValueType).self)) {
                            self = `case`
                            return
                        } else {
                            throw DecodingError.typeMismatch(\(type).self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }
                        """
                    )
                } else {
                    items.append(
                        """
                        let rawCase = try container.decode(String.self)
                        """
                    )

                    for caseName in nonOverridenCaseNames {
                        items.append(
                            """
                            if rawCase == \"\(raw: caseName)\" {
                                self = .\(raw: caseName)
                                return
                            }
                            """
                        )
                    }

                    items.append(
                        "throw DecodingError.typeMismatch(\(type).self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: \"No matching decoding cases \(type)\", underlyingError: nil))"
                    )
                }
            } else {
                items.append(
                    "throw DecodingError.typeMismatch(\(type).self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: \"No matching decoding cases \(type)\", underlyingError: nil))"
                )
            }

            return CodeBlockItemListSyntax(items)
        }

        let initDecl = try InitializerDeclSyntax("\(raw: accessModifier)init(from decoder: Decoder) throws") {
            let decoder = try decoderBlock()

            if let fallback {
                CodeBlockItemListSyntax {
                    DoStmtSyntax(
                        body: CodeBlockSyntax(statements: decoder),
                        catchClauses: [
                            CatchClauseSyntax("catch") {
                                CodeBlockItemListSyntax(
                                    "self = .\(raw: fallback)"
                                )

                                if let reporter {
                                    CodeBlockItemListSyntax(
                                        "(\(reporter)).report(error: error, in: \(raw: enumTypeName).self)"
                                    )
                                }
                            }
                        ]
                    )
                }
            } else {
                try decoderBlock()
            }
            /*
            CodeBlockItemListSyntax(
                [
                    CodeBlockItemSyntax(
                        "let container = try decoder.singleValueContainer()"
                    )
                ]
            )

            if !overridenCaseNames.isEmpty {
                try SwitchExprSyntax("switch try? container.decode(String.self)") {
                    for (caseName, overrideCaseName) in overridenCaseNames {
                        SwitchCaseSyntax("case \"\(raw: overrideCaseName)\":") {
                            CodeBlockItemListSyntax {
                                CodeBlockItemSyntax("self = .\(raw: caseName)")
                                CodeBlockItemSyntax("return")
                            }
                        }
                    }

                    SwitchCaseSyntax("default:") {
                        CodeBlockItemSyntax("break")
                    }
                }
            }

            if !nonOverridenCaseNames.isEmpty {
                if let rawValueType {
                    CodeBlockItemSyntax(
                        """
                        if let `case` = Self.init(rawValue: try container.decode(\(rawValueType).self)) {
                            self = `case`
                            return
                        } else {
                            throw DecodingError.typeMismatch(\(type).self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }
                        """
                    )
                } else {
                    CodeBlockItemSyntax(
                        """
                        let rawCase = try container.decode(String.self)
                        """
                    )

                    for caseName in nonOverridenCaseNames {
                        CodeBlockItemSyntax(
                            """
                            if rawCase == \"\(raw: caseName)\" {
                                self = .\(raw: caseName)
                                return
                            }
                            """
                        )
                    }

                    CodeBlockItemSyntax(
                        "throw DecodingError.typeMismatch(\(type).self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: \"No matching decoding cases \(type)\", underlyingError: nil))"
                    )
                }
            } else {
                CodeBlockItemSyntax(
                    "throw DecodingError.typeMismatch(\(type).self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: \"No matching decoding cases \(type)\", underlyingError: nil))"
                )
            }
            */
        }

        let `extension` = try ExtensionDeclSyntax(
            SyntaxUtils.isMissingConformanceToDecodable(conformances: protocols) ?
                "extension \(type): Decodable" :
                "extension \(type)"
        ) {
            MemberBlockItemListSyntax(
                [
                    MemberBlockItemSyntax(decl: initDecl)
                ]
            )
        }

        return [`extension`]
    }

    static func decode(
        element: EnumCaseElementListSyntax.Element,
        rootCodingKeysName: String
    ) throws -> MemberBlockItemListSyntax {
        let caseName = element.name.text
        let parameters = element.parameterClause?.parameters.map { $0 } ?? []

        return if parameters.isEmpty {
            MemberBlockItemListSyntax(
                """
                private static func decode_\(raw: caseName)() throws -> Self {
                    return .\(raw: caseName)
                }
                """
            )
        } else {
            MemberBlockItemListSyntax(
                """
                private static func decode_\(raw: caseName)(container: KeyedDecodingContainer<\(raw: rootCodingKeysName)_\(raw: caseName)>) throws -> Self {
                    return try .\(raw: caseName)(\(raw: parameters.enumerated().map { index, parameter in
                                                        return if let name = parameter.firstName?.text {
                                                            "\(name): Self.decode_\(caseName)_\(parameter.firstName?.text ?? "_\(index)")(container: container)"
                                                        } else {
                                                            "Self.decode_\(caseName)_\(parameter.firstName?.text ?? "_\(index)")(container: container)"
                                                        }
                                                    }.joined(separator: ", ")
                                                  ))
                }
                """
            )
        }
    }

    // MARK: Encoders

    static func encodeNestedObject(
        providingExtensionsOf type: some TypeSyntaxProtocol,
        for enum: EnumDeclSyntax,
        cases: [EnumCaseDeclSyntax],
        accessModifier: String,
        context: some MacroExpansionContext
    ) throws -> ExtensionDeclSyntax {
        let rootCodingKeysName = "CodingKeys"

        return try ExtensionDeclSyntax("extension \(type)") {
            try FunctionDeclSyntax("\(raw: accessModifier)func encode(to encoder: Encoder) throws") {
                CodeBlockItemListSyntax(
                    """
                    var container = encoder.container(keyedBy: \(raw: rootCodingKeysName).self)
                    """
                )

                try SwitchExprSyntax("switch self") {
                    for `case`in cases {
                        for element in `case`.elements {
                            let elementName = element.name.text
                            let elementCodingKeysName = "\(rootCodingKeysName)_\(elementName)"

                            if
                                let parameters = element.parameterClause?.parameters,
                                !parameters.isEmpty
                            {
                                let parameterNames = parameters.enumerated().map { index, parameter in parameter.firstName?.text ?? "_\(index)"  }

                                SwitchCaseSyntax("case let .\(raw: elementName)(\(raw: parameterNames.joined(separator: ", "))):") {
                                    CodeBlockItemSyntax(
                                        """
                                        var nestedContainer = container.nestedContainer(keyedBy: \(raw: elementCodingKeysName).self, forKey: .\(raw: elementName))
                                        """
                                    )

                                    for parameterName in parameterNames {
                                        CodeBlockItemSyntax(
                                            """
                                            try nestedContainer.encode(\(raw: parameterName), forKey: \(raw: elementCodingKeysName).\(raw: parameterName))
                                            """
                                        )
                                    }
                                }
                            } else {
                                SwitchCaseSyntax("case .\(raw: elementName):") {
                                    CodeBlockItemSyntax(
                                        """
                                        _ = container.nestedContainer(keyedBy: \(raw: elementCodingKeysName).self, forKey: .\(raw: elementName))
                                        """
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    static func encodeObjectByProperty(
        providingExtensionsOf type: some TypeSyntaxProtocol,
        casingPropertyName: String,
        for enum: EnumDeclSyntax,
        cases: [EnumCaseDeclSyntax],
        accessModifier: String,
        context: some MacroExpansionContext
    ) throws -> ExtensionDeclSyntax {
        let rootCodingKeysName = "CodingKeys"
        let casingKeysName = "CasingKeys"

        return try ExtensionDeclSyntax("extension \(type)") {
            try FunctionDeclSyntax("\(raw: accessModifier)func encode(to encoder: Encoder) throws") {
                try SwitchExprSyntax("switch self") {
                    for `case` in cases {
                        for element in `case`.elements {
                            let elementName = element.name.text
                            let elementCodingKeysName = "\(rootCodingKeysName)_\(elementName)"

                            if
                                let parameters = element.parameterClause?.parameters,
                                !parameters.isEmpty
                            {
                                let parameterNames = parameters.enumerated().map { index, parameter in parameter.firstName?.text ?? "_\(index)"  }

                                SwitchCaseSyntax("case let .\(raw: elementName)(\(raw: parameterNames.joined(separator: ", "))):") {
                                    CodeBlockItemListSyntax("var baseContainer = encoder.container(keyedBy: \(raw: rootCodingKeysName).self)")
                                    CodeBlockItemListSyntax("try baseContainer.encode(\(raw: casingKeysName).\(raw: elementName).rawValue, forKey: .\(raw: casingPropertyName))")
                                    CodeBlockItemListSyntax("var container = encoder.container(keyedBy: \(raw: elementCodingKeysName).self)")

                                    for parameterName in parameterNames {
                                        CodeBlockItemListSyntax("try container.encode(\(raw: parameterName), forKey: .\(raw: parameterName))")
                                    }
                                }
                            } else {
                                SwitchCaseSyntax("case .\(raw: elementName):") {
                                    CodeBlockItemListSyntax("var container = encoder.container(keyedBy: \(raw: rootCodingKeysName).self)")
                                    CodeBlockItemListSyntax("try container.encode(\(raw: casingKeysName).\(raw: elementName).rawValue, forKey: .\(raw: casingPropertyName))")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    static func encodePlain(
        providingExtensionsOf type: some TypeSyntaxProtocol,
        for enum: EnumDeclSyntax,
        rawValueType: TypeSyntax?,
        cases: [EnumCaseDeclSyntax],
        accessModifier: String,
        context: some MacroExpansionContext
    ) throws -> ExtensionDeclSyntax {
        return try ExtensionDeclSyntax("extension \(type)") {
            try FunctionDeclSyntax("\(raw: accessModifier)func encode(to encoder: Encoder) throws") {
                CodeBlockItemSyntax("var container = encoder.singleValueContainer()")

                try SwitchExprSyntax("switch self") {
                    for `case` in cases {
                        let caseNameOverride = Self.caseNameOverride(for: `case`)

                        for (index, caseElement) in `case`.elements.enumerated() {
                            if index == .zero, let caseNameOverride {
                                SwitchCaseSyntax("case .\(raw: caseElement.name.text):") {
                                    CodeBlockItemSyntax("try container.encode(\"\(raw: caseNameOverride)\")")
                                }
                            } else if rawValueType != nil {
                                SwitchCaseSyntax("case .\(raw: caseElement.name.text):") {
                                    CodeBlockItemSyntax("try container.encode(Self.\(raw: caseElement.name.text).rawValue)")
                                }
                            } else {
                                SwitchCaseSyntax("case .\(raw: caseElement.name.text):") {
                                    CodeBlockItemSyntax("try container.encode(\"\(raw: caseElement.name.text)\")")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Decoders -

private extension EnumSafeDecodingMacro {

    static func decode(
        parameter: EnumCaseParameterSyntax,
        at index: Int,
        of element: EnumCaseElementListSyntax.Element,
        in enumTypeName: String,
        rootCodingKeysName: String,
        reporter: ExprSyntax?
    ) throws -> MemberBlockItemListSyntax {
        let type = parameter.type

        return if let wrappedType = SyntaxUtils.extractOptionalType(from: type) {
            try decodeOptional(
                wrappedType: wrappedType,
                parameter: parameter,
                at: index,
                of: element,
                rootCodingKeysName: rootCodingKeysName,
                container: enumTypeName,
                reporter: reporter
            )
        } else if let elementType = SyntaxUtils.extractArrayType(from: type) {
            try decodeArray(
                elementType: elementType,
                parameter: parameter,
                at: index,
                of: element,
                rootCodingKeysName: rootCodingKeysName,
                container: enumTypeName,
                reporter: reporter
            )
        } else if let elementType = SyntaxUtils.extractSetType(from: type) {
            try decodeSet(
                elementType: elementType,
                parameter: parameter,
                at: index,
                of: element,
                rootCodingKeysName: rootCodingKeysName,
                container: enumTypeName,
                reporter: reporter
            )
        } else if let (keyType, valueType) = SyntaxUtils.extractDictionayTypes(from: type) {
            try decodeDictionary(
                keyType: keyType,
                valueType: valueType,
                parameter: parameter,
                at: index,
                of: element,
                rootCodingKeysName: rootCodingKeysName,
                container: enumTypeName,
                reporter: reporter
            )
        } else {
            try decodeStandard(
                type: type,
                parameter: parameter,
                at: index,
                of: element,
                rootCodingKeysName: rootCodingKeysName,
                container: enumTypeName,
                reporter: reporter
            )
        }
    }

    static func decodeOptional(
        wrappedType type: TypeSyntax,
        parameter: EnumCaseParameterSyntax,
        at index: Int,
        of element: EnumCaseElementListSyntax.Element,
        rootCodingKeysName: String,
        container: String,
        reporter: ExprSyntax?
    ) throws -> MemberBlockItemListSyntax {
        let elementName = element.name.text
        let parameterName = parameter.firstName?.text ?? "_\(index)"

        return if let reporter {
            MemberBlockItemListSyntax(
                """
                private static func decode_\(raw: elementName)_\(raw: parameterName)(container: KeyedDecodingContainer<\(raw: rootCodingKeysName)_\(raw: elementName)>) throws -> \(type)? {
                    do {
                        return try container.decode(\(type).self, forKey: .\(raw: parameterName))
                    } catch {
                        \(reporter).report(error: error, of: "\(raw: elementName).\(raw: parameterName)", decoding: \(type)?.self, in: \(raw: container).self)
                        return nil
                    }
                }
                """
            )
        } else {
            MemberBlockItemListSyntax(
                """
                private static func decode_\(raw: elementName)_\(raw: parameterName)(container: KeyedDecodingContainer<\(raw: rootCodingKeysName)_\(raw: elementName)>) throws -> \(type)? {
                    try? container.decode(\(type).self, forKey: .\(raw: parameterName))
                }
                """
            )
        }
    }

    static func decodeArray(
        elementType type: TypeSyntax,
        parameter: EnumCaseParameterSyntax,
        at index: Int,
        of element: EnumCaseElementListSyntax.Element,
        rootCodingKeysName: String,
        container: String,
        reporter: ExprSyntax?
    ) throws -> MemberBlockItemListSyntax {
        let elementName = element.name.text
        let parameterName = parameter.firstName?.text ?? "_\(index)"

        return if let reporter {
            MemberBlockItemListSyntax(
                """
                private static func decode_\(raw: elementName)_\(raw: parameterName)(container: KeyedDecodingContainer<\(raw: rootCodingKeysName)_\(raw: elementName)>) throws -> [\(type)] {
                    do {
                        let decodedArray = try container.decode([SafeDecodable<\(type)>].self, forKey: .\(raw: parameterName))
                        var items: [\(type)] = []

                        for (index, item) in decodedArray.enumerated() {
                            if let decoded = item.decoded {
                                items.append(decoded)
                            } else if let error = item.error {
                                \(reporter).report(error: error, decoding: \(type).self, at: index, of: "\(raw: elementName).\(raw: parameterName)", in: \(raw: container).self)
                            }
                        }

                        return items
                    } catch {
                        \(reporter).report(error: error, of: "\(raw: elementName).\(raw: parameterName)", decoding: [\(type)].self, in: \(raw: container).self)
                        return []
                    }
                }
                """
            )
        } else {
            MemberBlockItemListSyntax(
                """
                private static func decode_\(raw: elementName)_\(raw: parameterName)(container: KeyedDecodingContainer<\(raw: rootCodingKeysName)_\(raw: elementName)>) throws -> [\(type)] {
                    (try? container.decode([SafeDecodable<\(type)>].self, forKey: .\(raw: parameterName)))?.compactMap(\\.decoded) ?? []
                }
                """
            )
        }
    }

    static func decodeSet(
        elementType type: TypeSyntax,
        parameter: EnumCaseParameterSyntax,
        at index: Int,
        of element: EnumCaseElementListSyntax.Element,
        rootCodingKeysName: String,
        container: String,
        reporter: ExprSyntax?
    ) throws -> MemberBlockItemListSyntax {
        let elementName = element.name.text
        let parameterName = parameter.firstName?.text ?? "_\(index)"

        return if let reporter {
            MemberBlockItemListSyntax(
                """
                private static func decode_\(raw: elementName)_\(raw: parameterName)(container: KeyedDecodingContainer<\(raw: rootCodingKeysName)_\(raw: elementName)>) throws -> Set<\(type)> {
                    do {
                        let decodedArray = try container.decode([SafeDecodable<\(type)>].self, forKey: .\(raw: parameterName))
                        var items: Set<\(type)> = []

                        for (index, item) in decodedArray.enumerated() {
                            if let decoded = item.decoded {
                                items.insert(decoded)
                            } else if let error = item.error {
                                \(reporter).report(error: error, decoding: \(type).self, at: index, of: "\(raw: elementName).\(raw: parameterName)", in: \(raw: container).self)
                            }
                        }

                        return items
                    } catch {
                        \(reporter).report(error: error, of: "\(raw: elementName).\(raw: parameterName)", decoding: [\(type)].self, in: \(raw: container).self)
                        return Set()
                    }
                }
                """
            )
        } else {
            MemberBlockItemListSyntax(
                """
                private static func decode_\(raw: elementName)_\(raw: parameterName)(container: KeyedDecodingContainer<\(raw: rootCodingKeysName)_\(raw: elementName)>) throws -> Set<\(type)> {
                    (try? container.decode([SafeDecodable<\(type)>].self, forKey: .\(raw: parameterName)))?.reduce(into: []) { if let decoded = $1.decoded { $0.insert(decoded) } } ?? Set()
                }
                """
            )
        }

    }

    static func decodeDictionary(
        keyType: TypeSyntax,
        valueType: TypeSyntax,
        parameter: EnumCaseParameterSyntax,
        at index: Int,
        of element: EnumCaseElementListSyntax.Element,
        rootCodingKeysName: String,
        container: String,
        reporter: ExprSyntax?
    ) throws -> MemberBlockItemListSyntax {
        let elementName = element.name.text
        let parameterName = parameter.firstName?.text ?? "_\(index)"

        return if let reporter {
            """
            private static func decode_\(raw: elementName)_\(raw: parameterName)(container: KeyedDecodingContainer<\(raw: rootCodingKeysName)_\(raw: elementName)>) throws -> [\(keyType): \(valueType)] {
                do {
                    let decodedItems = try container.decode([\(keyType): SafeDecodable<\(valueType)>].self, forKey: .\(raw: parameterName))
                    var items: [\(keyType): \(valueType)] = [:]

                    for (key, value) in decodedItems {
                        if let decoded = value.decoded {
                            items[key] = decoded
                        } else if let error = value.error {
                            \(reporter).report(error: error, decoding: \(valueType).self, forKey: key, of: "\(raw: elementName).\(raw: parameterName)", in: \(raw: container).self)
                        }
                    }

                    return items
                } catch {
                    \(reporter).report(error: error, of: "\(raw: elementName).\(raw: parameterName)", decoding: [\(keyType): SafeDecodable<\(valueType)>].self, in: \(raw: container).self)
                    return [:]
                }
            }
            """
        } else {
            """
            private static func decode_\(raw: elementName)_\(raw: parameterName)(container: KeyedDecodingContainer<\(raw: rootCodingKeysName)_\(raw: elementName)>) throws -> [\(keyType): \(valueType)] {
                return ((try? container.decode([\(keyType): SafeDecodable<\(valueType)>].self, forKey: .\(raw: parameterName))) ?? [:]).reduce(into: [:]) { $0[$1.key] = $1.value.decoded }
            }
            """
        }
    }

    static func decodeStandard(
        type: TypeSyntax,
        parameter: EnumCaseParameterSyntax,
        at index: Int,
        of element: EnumCaseElementListSyntax.Element,
        rootCodingKeysName: String,
        container: String,
        reporter: ExprSyntax?
    ) throws -> MemberBlockItemListSyntax {
        let elementName = element.name.text
        let parameterName = parameter.firstName?.text ?? "_\(index)"

        return if let reporter {
            MemberBlockItemListSyntax(
                """
                private static func decode_\(raw: elementName)_\(raw: parameterName)(container: KeyedDecodingContainer<\(raw: rootCodingKeysName)_\(raw: elementName)>) throws -> \(parameter.type) {
                    do {
                        return try container.decode(\(type).self, forKey: .\(raw: parameterName))
                    } catch {
                        \(reporter).report(error: error, of: "\(raw: elementName).\(raw: parameterName)", decoding: \(type).self, in: \(raw: container).self)
                        throw error
                    }
                }
                """
            )
        } else {
            MemberBlockItemListSyntax(
                """
                private static func decode_\(raw: elementName)_\(raw: parameterName)(container: KeyedDecodingContainer<\(raw: rootCodingKeysName)_\(raw: elementName)>) throws -> \(parameter.type) {
                    try container.decode(\(type).self, forKey: .\(raw: parameterName))
                }
                """
            )
        }
    }
}

// MARK: - Utils

private extension EnumSafeDecodingMacro {
    static func caseNameOverride(for case: EnumCaseDeclSyntax) -> String? {
        `case`
            .attributes
            .first { attribute in
                attribute
                    .as(AttributeSyntax.self)?
                    .attributeName
                    .as(IdentifierTypeSyntax.self)?
                    .name
                    .text == "CaseNameDecoding"
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

    static func decodingStrategy(for attribute: AttributeSyntax) -> DecodingStrategy {
        if case let .argumentList(arguments) = attribute.arguments {
            for argument in arguments where argument.label?.text == "decodingStrategy" {
                if
                    let functionCall = argument
                        .expression
                        .as(FunctionCallExprSyntax.self),
                    functionCall
                        .calledExpression
                        .as(MemberAccessExprSyntax.self)?
                        .declName
                        .baseName
                        .text == "caseByObjectProperty",
                    let caseName = functionCall
                        .arguments
                        .first?
                        .expression
                        .as(StringLiteralExprSyntax.self)?
                        .segments
                        .first?
                        .as(StringSegmentSyntax.self)?
                        .content
                        .text
                {
                    return .property(name: caseName)
                } else if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                    let name = memberAccess.declName.baseName.text

                    if name == "caseByNestedObject" { return .nested }

                    if name == "natural" { return .none }
                }
            }

            return .nested
        } else {
            return .nested
        }

        /*
        if let caseSwitchingPropertyName = attribute
            .arguments?
            .as(LabeledExprListSyntax.self)?
            .compactMap({ argument -> String? in
                guard
                    argument.label?.text == "decodingStrategy",
                    let expression = argument
                        .expression
                        .as(FunctionCallExprSyntax.self),
                    expression
                        .calledExpression
                        .as(MemberAccessExprSyntax.self)?
                        .declName
                        .baseName
                        .text == "caseByObjectProperty",
                    let caseName = expression
                        .arguments
                        .first?
                        .expression
                        .as(StringLiteralExprSyntax.self)?
                        .segments
                        .first?
                        .as(StringSegmentSyntax.self)?
                        .content
                        .text
                else {
                    return nil
                }

                return caseName
            }).first
        {
            return .property(name: caseSwitchingPropertyName)
        }

        return .nested
        */
    }

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

    enum DecodingStrategy {
        case nested
        case property(name: String)
        case none
    }
}

// MARK: - Errors

private extension EnumSafeDecodingMacro {
    enum Errors: Error, CustomStringConvertible {
        case onlyApplicableToEnumTypes
        case invalidCaseName
        case enumNaturalStrategyWithAssociatedValues
        case invalidMultipleFallbackEnumCases(cases: [String])
        case unexpectedError

        var description: String {
            switch self {
            case .onlyApplicableToEnumTypes: "EnumSafeDecodingMacro is only applicable to enums"
            case .invalidCaseName: "Case name is missing or invalid"
            case .enumNaturalStrategyWithAssociatedValues: "Found case(s) with associated values while using natural decoding strategy"
            case .invalidMultipleFallbackEnumCases(let cases): "Multiple instances of @FallbackCaseDecoding are illegal: \(cases.map { "case \($0)" }.joined(separator: ", "))"
            case .unexpectedError: "Unexpected error"
            }
        }
    }

    struct EnumDiagnosticMessage: DiagnosticMessage {
        let message: String
        let diagnosticID: MessageID
        let severity: DiagnosticSeverity
    }
}

// MARK: - Constants

private extension EnumSafeDecodingMacro {
    enum Constants {
        static let supportedRawValueTypes = [
            "String",
            "Character",
            "Int",
            "UInt",
            "Double",
            "Float"
        ]
    }
}
