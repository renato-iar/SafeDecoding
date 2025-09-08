import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling.
// Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(SafeDecodingMacros)
import SafeDecodingMacros

private let testMacros: [String: Macro.Type] = [
    "EnumSafeDecoding": EnumSafeDecodingMacro.self,
    "CaseNameDecoding": CaseNameDecodingMacro.self,
    "FallbackCaseDecoding": FallbackCaseDecodingMacro.self
]
#endif

final class EnumSafeDecodingMacrosTests: XCTestCase { }

// MARK: - enum -

extension EnumSafeDecodingMacrosTests {
    func testSafeDecodingOfEnumWithEmptyCaseCasedByNesting() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByNestedObject)
                enum Model {
                    case empty1
                    case empty2
                }
                """,
                expandedSource:
                """

                enum Model {
                    case empty1
                    case empty2
                }

                extension Model {
                    private enum CodingKeys: String, CodingKey {
                        case empty1
                        case empty2
                    }
                    private enum CodingKeys_empty1: CodingKey {
                    }
                    private enum CodingKeys_empty2: CodingKey {
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }

                        switch onlyKey {
                        case .empty1:
                            self = .empty1
                        case .empty2:
                            self = .empty2
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumWithEmptyCaseCasedByObjectProperty() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByObjectProperty("type"))
                enum Model {
                    case empty1
                    case empty2
                }
                """,
                expandedSource:
                """

                enum Model {
                    case empty1
                    case empty2
                }

                extension Model {
                    private enum CasingKeys: String, Decodable {
                        case empty1
                        case empty2
                    }
                    private enum CodingKeys: String, CodingKey {
                        case type = "type"
                    }
                    init(from decoder: Decoder) throws {
                        switch try decoder.container(keyedBy: CodingKeys.self).decode(CasingKeys.self, forKey: .type) {
                        case .empty1:
                            self = .empty1
                        case .empty2:
                            self = .empty2
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }
}

extension EnumSafeDecodingMacrosTests {
    func testSafeDecodingOfEnumWithCaseWithUnnamedStringPropertyWithoutReporting() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByNestedObject)
                enum Model {
                    case vod(String)
                }
                """,
                expandedSource:
                """

                enum Model {
                    case vod(String)
                }

                extension Model {
                    private enum CodingKeys: String, CodingKey {
                        case vod
                    }
                    private enum CodingKeys_vod: String, CodingKey {
                        case _0
                    }
                    private static func decode_vod(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Self {
                        return try .vod(Self.decode_vod__0(container: container))
                    }
                    private static func decode_vod__0(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> String {
                        try container.decode(String.self, forKey: ._0)
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }

                        switch onlyKey {
                        case .vod:
                            self = try Self.decode_vod(container: container.nestedContainer(keyedBy: CodingKeys_vod.self, forKey: .vod))
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumWithCaseWithUnnamedOptionalPropertyWithoutReporting() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByNestedObject)
                enum Model {
                    case vod(String?)
                }
                """,
                expandedSource:
                """

                enum Model {
                    case vod(String?)
                }

                extension Model {
                    private enum CodingKeys: String, CodingKey {
                        case vod
                    }
                    private enum CodingKeys_vod: String, CodingKey {
                        case _0
                    }
                    private static func decode_vod(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Self {
                        return try .vod(Self.decode_vod__0(container: container))
                    }
                    private static func decode_vod__0(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> String? {
                        try? container.decode(String.self, forKey: ._0)
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }

                        switch onlyKey {
                        case .vod:
                            self = try Self.decode_vod(container: container.nestedContainer(keyedBy: CodingKeys_vod.self, forKey: .vod))
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumWithCaseWithUnnamedArrayPropertyWithoutReporting() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByNestedObject)
                enum Model {
                    case vod([Bool])
                }
                """,
                expandedSource:
                """

                enum Model {
                    case vod([Bool])
                }

                extension Model {
                    private enum CodingKeys: String, CodingKey {
                        case vod
                    }
                    private enum CodingKeys_vod: String, CodingKey {
                        case _0
                    }
                    private static func decode_vod(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Self {
                        return try .vod(Self.decode_vod__0(container: container))
                    }
                    private static func decode_vod__0(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> [Bool] {
                        (try? container.decode([SafeDecodable<Bool>].self, forKey: ._0))?.compactMap(\\.decoded) ?? []
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }

                        switch onlyKey {
                        case .vod:
                            self = try Self.decode_vod(container: container.nestedContainer(keyedBy: CodingKeys_vod.self, forKey: .vod))
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumWithCaseWithUnnamedSetPropertyWithoutReporting() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByNestedObject)
                enum Model {
                    case vod(Set<Bool>)
                }
                """,
                expandedSource:
                """

                enum Model {
                    case vod(Set<Bool>)
                }

                extension Model {
                    private enum CodingKeys: String, CodingKey {
                        case vod
                    }
                    private enum CodingKeys_vod: String, CodingKey {
                        case _0
                    }
                    private static func decode_vod(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Self {
                        return try .vod(Self.decode_vod__0(container: container))
                    }
                    private static func decode_vod__0(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Set<Bool> {
                        (try? container.decode([SafeDecodable<Bool>].self, forKey: ._0))?.reduce(into: []) {
                            if let decoded = $1.decoded {
                                $0.insert(decoded)
                            }
                        } ?? Set()
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }

                        switch onlyKey {
                        case .vod:
                            self = try Self.decode_vod(container: container.nestedContainer(keyedBy: CodingKeys_vod.self, forKey: .vod))
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumWithCaseWithUnnamedDictionaryPropertyWithoutReporting() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByNestedObject)
                enum Model {
                    case vod([String: Bool])
                }
                """,
                expandedSource:
                """

                enum Model {
                    case vod([String: Bool])
                }

                extension Model {
                    private enum CodingKeys: String, CodingKey {
                        case vod
                    }
                    private enum CodingKeys_vod: String, CodingKey {
                        case _0
                    }
                    private static func decode_vod(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Self {
                        return try .vod(Self.decode_vod__0(container: container))
                    }
                    private static func decode_vod__0(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> [String: Bool] {
                        return ((try? container.decode([String: SafeDecodable<Bool>].self, forKey: ._0)) ?? [:]).reduce(into: [:]) {
                            $0 [$1.key] = $1.value.decoded
                        }
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }

                        switch onlyKey {
                        case .vod:
                            self = try Self.decode_vod(container: container.nestedContainer(keyedBy: CodingKeys_vod.self, forKey: .vod))
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }
}

extension EnumSafeDecodingMacrosTests {
    func testSafeDecodingOfEnumForCaseWithUnnamedStringPropertyWithReporting() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByNestedObject, reporter: sampleReporter)
                enum Model {
                    case vod(String)
                }
                """,
                expandedSource:
                """
                
                enum Model {
                    case vod(String)
                }
                
                extension Model {
                    private enum CodingKeys: String, CodingKey {
                        case vod
                    }
                    private enum CodingKeys_vod: String, CodingKey {
                        case _0
                    }
                    private static func decode_vod(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Self {
                        return try .vod(Self.decode_vod__0(container: container))
                    }
                    private static func decode_vod__0(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> String {
                        do {
                            return try container.decode(String.self, forKey: ._0)
                        } catch {
                            sampleReporter.report(error: error, of: "vod._0", decoding: String.self, in: Model.self)
                            throw error
                        }
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }
                
                        switch onlyKey {
                        case .vod:
                            self = try Self.decode_vod(container: container.nestedContainer(keyedBy: CodingKeys_vod.self, forKey: .vod))
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumForCaseWithUnnamedOptionalPropertyWithReporting() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByNestedObject, reporter: sampleReporter)
                enum Model {
                    case vod(String?)
                }
                """,
                expandedSource:
                """
                
                enum Model {
                    case vod(String?)
                }
                
                extension Model {
                    private enum CodingKeys: String, CodingKey {
                        case vod
                    }
                    private enum CodingKeys_vod: String, CodingKey {
                        case _0
                    }
                    private static func decode_vod(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Self {
                        return try .vod(Self.decode_vod__0(container: container))
                    }
                    private static func decode_vod__0(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> String? {
                        do {
                            return try container.decode(String.self, forKey: ._0)
                        } catch {
                            sampleReporter.report(error: error, of: "vod._0", decoding: String?.self, in: Model.self)
                            return nil
                        }
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }
                
                        switch onlyKey {
                        case .vod:
                            self = try Self.decode_vod(container: container.nestedContainer(keyedBy: CodingKeys_vod.self, forKey: .vod))
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumForCaseWithUnnamedArrayPropertyWithReporting() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByNestedObject, reporter: sampleReporter)
                enum Model {
                    case vod([Bool])
                }
                """,
                expandedSource:
                """
                
                enum Model {
                    case vod([Bool])
                }
                
                extension Model {
                    private enum CodingKeys: String, CodingKey {
                        case vod
                    }
                    private enum CodingKeys_vod: String, CodingKey {
                        case _0
                    }
                    private static func decode_vod(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Self {
                        return try .vod(Self.decode_vod__0(container: container))
                    }
                    private static func decode_vod__0(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> [Bool] {
                        do {
                            let decodedArray = try container.decode([SafeDecodable<Bool>].self, forKey: ._0)
                            var items: [Bool] = []
                
                            for (index, item) in decodedArray.enumerated() {
                                if let decoded = item.decoded {
                                    items.append(decoded)
                                } else if let error = item.error {
                                    sampleReporter.report(error: error, decoding: Bool.self, at: index, of: "vod._0", in: Model.self)
                                }
                            }
                
                            return items
                        } catch {
                            sampleReporter.report(error: error, of: "vod._0", decoding: [Bool].self, in: Model.self)
                            return []
                        }
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }
                
                        switch onlyKey {
                        case .vod:
                            self = try Self.decode_vod(container: container.nestedContainer(keyedBy: CodingKeys_vod.self, forKey: .vod))
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumForCaseWithUnnamedSetPropertyWithReporting() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByNestedObject, reporter: sampleReporter)
                enum Model {
                    case vod(Set<Bool>)
                }
                """,
                expandedSource:
                """
                
                enum Model {
                    case vod(Set<Bool>)
                }
                
                extension Model {
                    private enum CodingKeys: String, CodingKey {
                        case vod
                    }
                    private enum CodingKeys_vod: String, CodingKey {
                        case _0
                    }
                    private static func decode_vod(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Self {
                        return try .vod(Self.decode_vod__0(container: container))
                    }
                    private static func decode_vod__0(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Set<Bool> {
                        do {
                            let decodedArray = try container.decode([SafeDecodable<Bool>].self, forKey: ._0)
                            var items: Set<Bool> = []
                
                            for (index, item) in decodedArray.enumerated() {
                                if let decoded = item.decoded {
                                    items.insert(decoded)
                                } else if let error = item.error {
                                    sampleReporter.report(error: error, decoding: Bool.self, at: index, of: "vod._0", in: Model.self)
                                }
                            }
                
                            return items
                        } catch {
                            sampleReporter.report(error: error, of: "vod._0", decoding: [Bool].self, in: Model.self)
                            return Set()
                        }
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }
                
                        switch onlyKey {
                        case .vod:
                            self = try Self.decode_vod(container: container.nestedContainer(keyedBy: CodingKeys_vod.self, forKey: .vod))
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumForCaseWithUnnamedDictionaryPropertyWithReporting() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @EnumSafeDecoding(decodingStrategy: .caseByNestedObject, reporter: sampleReporter)
                enum Model {
                    case vod([String: Bool])
                }
                """,
                expandedSource:
                """
                
                enum Model {
                    case vod([String: Bool])
                }
                
                extension Model {
                    private enum CodingKeys: String, CodingKey {
                        case vod
                    }
                    private enum CodingKeys_vod: String, CodingKey {
                        case _0
                    }
                    private static func decode_vod(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> Self {
                        return try .vod(Self.decode_vod__0(container: container))
                    }
                    private static func decode_vod__0(container: KeyedDecodingContainer<CodingKeys_vod>) throws -> [String: Bool] {
                        do {
                            let decodedItems = try container.decode([String: SafeDecodable<Bool>].self, forKey: ._0)
                            var items: [String: Bool] = [:]
                
                            for (key, value) in decodedItems {
                                if let decoded = value.decoded {
                                    items[key] = decoded
                                } else if let error = value.error {
                                    sampleReporter.report(error: error, decoding: Bool.self, forKey: key, of: "vod._0", in: Model.self)
                                }
                            }
                
                            return items
                        } catch {
                            sampleReporter.report(error: error, of: "vod._0", decoding: [String: SafeDecodable<Bool>].self, in: Model.self)
                            return [:]
                        }
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        var allKeys = ArraySlice(container.allKeys)
                        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                            throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
                        }
                
                        switch onlyKey {
                        case .vod:
                            self = try Self.decode_vod(container: container.nestedContainer(keyedBy: CodingKeys_vod.self, forKey: .vod))
                        }
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumForNaturalStrategyWithRawValueType() throws {

#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                    """
                    @EnumSafeDecoding(decodingStrategy: .natural, shouldImplementEncoding: true)
                    enum Model: Int {
                        @CaseNameDecoding("vd")
                        case vod
                        case bla
                    }
                    """,
                    expandedSource:
                    """
                    
                    enum Model: Int {
                        case vod
                        case bla
                    }

                    extension Model {
                        init(from decoder: Decoder) throws {
                            let container = try decoder.singleValueContainer()
                            switch try? container.decode(String.self) {
                            case "vd":
                                self = .vod
                                return
                            default:
                                break
                            }
                            if let `case` = Self.init(rawValue: try container.decode(Int .self)) {
                                self = `case`
                                return
                            } else {
                                throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "No matching decoding cases.", underlyingError: nil))
                            }
                        }
                    }

                    extension Model {
                        func encode(to encoder: Encoder) throws {
                            var container = encoder.singleValueContainer()
                            switch self {
                            case .vod:
                                try container.encode("vd")
                            case .bla:
                                try container.encode(Self.bla.rawValue)
                            }
                        }
                    }
                    """,
                    macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumForNaturalStrategyWithoutRawValueType() throws {

#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                    """
                    @EnumSafeDecoding(decodingStrategy: .natural, shouldImplementEncoding: true)
                    enum Model {
                        @CaseNameDecoding("vd")
                        case vod
                        @FallbackCaseDecoding
                        case bla
                    }
                    """,
                    expandedSource:
                    """
                    
                    enum Model {
                        case vod
                        case bla
                    }

                    extension Model {
                        init(from decoder: Decoder) throws {
                            do {
                                let container = try decoder.singleValueContainer()
                                switch try? container.decode(String.self) {
                                case "vd":
                                    self = .vod
                                    return
                                default:
                                    break
                                }
                                let rawCase = try container.decode(String.self)
                                if rawCase == "bla" {
                                    self = .bla
                                    return
                                }
                                throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "No matching decoding cases Model", underlyingError: nil))
                            } catch {
                                self = .bla
                            }
                        }
                    }

                    extension Model {
                        func encode(to encoder: Encoder) throws {
                            var container = encoder.singleValueContainer()
                            switch self {
                            case .vod:
                                try container.encode("vd")
                            case .bla:
                                try container.encode("bla")
                            }
                        }
                    }
                    """,
                    macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfEnumForNaturalStrategyWithRawValueTypeWithReporting() throws {

    #if canImport(SafeDecodingMacros)
            assertMacroExpansion(
                    """
                    @EnumSafeDecoding(decodingStrategy: .natural, shouldImplementEncoding: true, reporter: reporter)
                    enum Model: Int {
                        @CaseNameDecoding("vd")
                        @FallbackCaseDecoding
                        case vod
                        case bla
                    }
                    """,
                    expandedSource:
                    """

                    enum Model: Int {
                        case vod
                        case bla
                    }

                    extension Model {
                        init(from decoder: Decoder) throws {
                            do {
                                let container = try decoder.singleValueContainer()
                                switch try? container.decode(String.self) {
                                case "vd":
                                    self = .vod
                                    return
                                default:
                                    break
                                }
                                if let `case` = Self.init(rawValue: try container.decode(Int .self)) {
                                    self = `case`
                                    return
                                } else {
                                    throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "No matching decoding cases.", underlyingError: nil))
                                }
                            } catch {
                                self = .vod
                                (reporter).report(error: error, in: Model.self)
                            }
                        }
                    }

                    extension Model {
                        func encode(to encoder: Encoder) throws {
                            var container = encoder.singleValueContainer()
                            switch self {
                            case .vod:
                                try container.encode("vd")
                            case .bla:
                                try container.encode(Self.bla.rawValue)
                            }
                        }
                    }
                    """,
                    macros: testMacros
            )
    #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
    }

    func testSafeDecodingOfEnumForNaturalStrategyWithoutRawValueTypeWithReporting() throws {

    #if canImport(SafeDecodingMacros)
            assertMacroExpansion(
                    """
                    @EnumSafeDecoding(decodingStrategy: .natural, shouldImplementEncoding: true, reporter: reporter)
                    enum Model {
                        @CaseNameDecoding("vd")
                        case vod
                        @FallbackCaseDecoding
                        case bla
                    }
                    """,
                    expandedSource:
                    """

                    enum Model {
                        case vod
                        case bla
                    }

                    extension Model {
                        init(from decoder: Decoder) throws {
                            do {
                                let container = try decoder.singleValueContainer()
                                switch try? container.decode(String.self) {
                                case "vd":
                                    self = .vod
                                    return
                                default:
                                    break
                                }
                                let rawCase = try container.decode(String.self)
                                if rawCase == "bla" {
                                    self = .bla
                                    return
                                }
                                throw DecodingError.typeMismatch(Model.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "No matching decoding cases Model", underlyingError: nil))
                            } catch {
                                self = .bla
                                (reporter).report(error: error, in: Model.self)
                            }
                        }
                    }

                    extension Model {
                        func encode(to encoder: Encoder) throws {
                            var container = encoder.singleValueContainer()
                            switch self {
                            case .vod:
                                try container.encode("vd")
                            case .bla:
                                try container.encode("bla")
                            }
                        }
                    }
                    """,
                    macros: testMacros
            )
    #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
    }
}
