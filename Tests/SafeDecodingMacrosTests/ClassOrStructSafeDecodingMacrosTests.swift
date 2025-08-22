import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling.
// Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(SafeDecodingMacros)
import SafeDecodingMacros

private let testMacros: [String: Macro.Type] = [
    "ClassOrStructSafeDecoding": ClassOrStructSafeDecodingMacro.self,
    "RetryDecoding": RetryDecodingMacro.self,
    "FallbackDecoding": FallbackDecodingMacro.self,
    "OptionalDecoding": OptionalDecodingMacro.self
]
#endif

final class ClassOrStructSafeDecodingMacrosTests: XCTestCase { }

// MARK: - class/struct -

extension ClassOrStructSafeDecodingMacrosTests {
    func testSafeDecodingOfOptional() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding
                struct Model {
                    let optional: Int?
                    let optionalGeneric: Optional<Int>
                }
                """,
                expandedSource:
                """

                struct Model {
                    let optional: Int?
                    let optionalGeneric: Optional<Int>
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                        case optional
                        case optionalGeneric
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.optional = try? container.decode(Int.self, forKey: .optional)
                        self.optionalGeneric = try? container.decode(Int.self, forKey: .optionalGeneric)
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingOfSet() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding
                struct Model {
                    let set: Set<Int>
                }
                """,
                expandedSource:
                """

                struct Model {
                    let set: Set<Int>
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                        case set
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.set = ((try? container.decode([SafeDecodable<Int>].self, forKey: .set)) ?? []).reduce(into: Set<Int>()) { set, safe in
                            _ = safe.decoded.flatMap { value in
                                set.insert(value)
                            }
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

    func testSafeDecodingOfArray() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding
                struct Model {
                    let array: [Int]
                    let arrayGeneric: Array<Int>
                }
                """,
                expandedSource:
                """

                struct Model {
                    let array: [Int]
                    let arrayGeneric: Array<Int>
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                        case array
                        case arrayGeneric
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.array = ((try? container.decode([SafeDecodable<Int>].self, forKey: .array)) ?? []).compactMap {
                            $0.decoded
                        }
                        self.arrayGeneric = ((try? container.decode([SafeDecodable<Int>].self, forKey: .arrayGeneric)) ?? []).compactMap {
                            $0.decoded
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

    func testSafeDecodingOfDictionary() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding
                struct Model {
                    let dictionary: [Int: Int]
                    let dictionaryGeneric: Dictionary<Int, Int>
                }
                """,
                expandedSource:
                """

                struct Model {
                    let dictionary: [Int: Int]
                    let dictionaryGeneric: Dictionary<Int, Int>
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                        case dictionary
                        case dictionaryGeneric
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        self.dictionary = ((try? container.decode([Int: SafeDecodable<Int>].self, forKey: .dictionary)) ?? [:]).reduce(into: [:]) {
                            $0 [$1.key] = $1.value.decoded
                        }
                        self.dictionaryGeneric = ((try? container.decode([Int: SafeDecodable<Int>].self, forKey: .dictionaryGeneric)) ?? [:]).reduce(into: [:]) {
                            $0 [$1.key] = $1.value.decoded
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

extension ClassOrStructSafeDecodingMacrosTests {
    func testSafeDecodingOfOptionalWithReporter() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding(reporter: reporter)
                struct Model {
                    let optional: Int?
                    let optionalGeneric: Optional<Int>
                }
                """,
                expandedSource:
                """

                struct Model {
                    let optional: Int?
                    let optionalGeneric: Optional<Int>
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                        case optional
                        case optionalGeneric
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        do {
                            self.optional = try container.decodeIfPresent(Int.self, forKey: .optional)
                        } catch {
                            self.optional = nil
                            reporter.report(error: error, of: "optional", decoding: Int?.self, in: (Model).self)
                        }
                        do {
                            self.optionalGeneric = try container.decodeIfPresent(Int.self, forKey: .optionalGeneric)
                        } catch {
                            self.optionalGeneric = nil
                            reporter.report(error: error, of: "optionalGeneric", decoding: Int?.self, in: (Model).self)
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

    func testSafeDecodingOfSetWithReporter() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding(reporter: reporter)
                struct Model {
                    let set: Set<Int>
                }
                """,
                expandedSource:
                """

                struct Model {
                    let set: Set<Int>
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                        case set
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        do {
                            let decodedItems = try container.decode([SafeDecodable<Int>].self, forKey: .set)
                            var items: Set<Int> = []

                            for (index, item) in decodedItems.enumerated() {
                                if let decoded = item.decoded {
                                    items.insert(decoded)
                                } else if let error = item.error {
                                    reporter.report(error: error, decoding: Int.self, at: index, of: "set", in: (Model).self)
                                }
                            }

                            self.set = items
                        } catch {
                            self.set = []
                            reporter.report(error: error, of: "set", decoding: Set<Int> .self, in: (Model).self)
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

    func testSafeDecodingOfArrayWithReporter() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding(reporter: reporter)
                struct Model {
                    let array: [Int]
                    let arrayGeneric: Array<Int>
                }
                """,
                expandedSource:
                """

                struct Model {
                    let array: [Int]
                    let arrayGeneric: Array<Int>
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                        case array
                        case arrayGeneric
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        do {
                            let decodedArray = try container.decode([SafeDecodable<Int>].self, forKey: .array)
                            var items: [Int] = []

                            for (index, item) in decodedArray.enumerated() {
                                if let decoded = item.decoded {
                                    items.append(decoded)
                                } else if let error = item.error {
                                    reporter.report(error: error, decoding: Int.self, at: index, of: "array", in: (Model).self)
                                }
                            }

                            self.array = items
                        } catch {
                            self.array = []
                            reporter.report(error: error, of: "array", decoding: [Int].self, in: (Model).self)
                        }
                        do {
                            let decodedArray = try container.decode([SafeDecodable<Int>].self, forKey: .arrayGeneric)
                            var items: [Int] = []

                            for (index, item) in decodedArray.enumerated() {
                                if let decoded = item.decoded {
                                    items.append(decoded)
                                } else if let error = item.error {
                                    reporter.report(error: error, decoding: Int.self, at: index, of: "arrayGeneric", in: (Model).self)
                                }
                            }

                            self.arrayGeneric = items
                        } catch {
                            self.arrayGeneric = []
                            reporter.report(error: error, of: "arrayGeneric", decoding: [Int].self, in: (Model).self)
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

    func testSafeDecodingOfDictionaryWithReporter() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding(reporter: reporter)
                struct Model {
                    let dictionary: [Int: Int]
                    let dictionaryGeneric: Dictionary<Int, Int>
                }
                """,
                expandedSource:
                """

                struct Model {
                    let dictionary: [Int: Int]
                    let dictionaryGeneric: Dictionary<Int, Int>
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                        case dictionary
                        case dictionaryGeneric
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        do {
                            let decodedItems = try container.decode([Int: SafeDecodable<Int>].self, forKey: .dictionary)
                            var items: [Int: Int] = [:]

                            for (key, value) in decodedItems {
                                if let decoded = value.decoded {
                                    items[key] = decoded
                                } else if let error = value.error {
                                    reporter.report(error: error, decoding: Int.self, forKey: key, of: "dictionary", in: (Model).self)
                                }
                            }

                            self.dictionary = items
                        } catch {
                            self.dictionary = [:]
                            reporter.report(error: error, of: "dictionary", decoding: [Int: SafeDecodable<Int>].self, in: (Model).self)
                        }
                        do {
                            let decodedItems = try container.decode([Int: SafeDecodable<Int>].self, forKey: .dictionaryGeneric)
                            var items: [Int: Int] = [:]

                            for (key, value) in decodedItems {
                                if let decoded = value.decoded {
                                    items[key] = decoded
                                } else if let error = value.error {
                                    reporter.report(error: error, decoding: Int.self, forKey: key, of: "dictionaryGeneric", in: (Model).self)
                                }
                            }

                            self.dictionaryGeneric = items
                        } catch {
                            self.dictionaryGeneric = [:]
                            reporter.report(error: error, of: "dictionaryGeneric", decoding: [Int: SafeDecodable<Int>].self, in: (Model).self)
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

extension ClassOrStructSafeDecodingMacrosTests {
    func testSafeDecodingIgnoresComputedProperty() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding(reporter: SafeDecodingErrorReporter.shared)
                struct Model {
                    let computed: Int { 0 }
                }
                """,
                expandedSource:
                """

                struct Model {
                    let computed: Int { 0 }
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                    }
                    init(from decoder: Decoder) throws {
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif


    }

    func testSafeDecodingIgnoresInitializedProperty() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding
                struct Model {
                    let computed: Int = 0
                }
                """,
                expandedSource:
                """

                struct Model {
                    let computed: Int = 0
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                    }
                    init(from decoder: Decoder) throws {
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

extension ClassOrStructSafeDecodingMacrosTests {
    func testSafeDecodingMacroRespectsDefaultAccessModifier() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding
                struct Model {
                    let computed: Int = 0
                }
                """,
                expandedSource:
                """

                struct Model {
                    let computed: Int = 0
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                    }
                    init(from decoder: Decoder) throws {
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingMacroRespectsInternalAccessModifier() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding
                internal struct Model {
                    let computed: Int = 0
                }
                """,
                expandedSource:
                """

                internal struct Model {
                    let computed: Int = 0
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                    }
                    internal init(from decoder: Decoder) throws {
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingMacroRespectsPackageAccessModifier() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding
                package struct Model {
                    let computed: Int = 0
                }
                """,
                expandedSource:
                """

                package struct Model {
                    let computed: Int = 0
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                    }
                    package init(from decoder: Decoder) throws {
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingMacroRespectsPublicAccessModifier() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding
                public struct Model {
                    let computed: Int = 0
                }
                """,
                expandedSource:
                """

                public struct Model {
                    let computed: Int = 0
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                    }
                    public init(from decoder: Decoder) throws {
                    }
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testSafeDecodingMacroRespectsOpenAccessModifier() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding
                open struct Model {
                    let computed: Int = 0
                }
                """,
                expandedSource:
                """

                open struct Model {
                    let computed: Int = 0
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                    }
                    open init(from decoder: Decoder) throws {
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

extension ClassOrStructSafeDecodingMacrosTests {
    func testSafeDecodingRetryDecoding() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding(reporter: SafeDecodingErrorReporter.shared)
                struct Model {
                    @RetryDecoding(String.self, map: { Int.init($0, radix: 10) })
                    let int: Int
                }
                """,
                expandedSource:
                """

                struct Model {
                    let int: Int
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                        case int
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        do {
                            self.int = try container.decode(Int.self, forKey: .int)
                        } catch {
                            if let retry = (try? container.decode(String.self, forKey: .int)).flatMap({
                                    Int.init($0, radix: 10)
                                }) {
                                self.int = retry
                                SafeDecodingErrorReporter.shared.report(error: error, of: "int", decoding: Int.self, in: (Model).self)
                            } else {
                                throw error
                            }
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

    func testSafeDecodingFallbackDecoding() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding(reporter: SafeDecodingErrorReporter.shared)
                struct Model {
                    @FallbackDecoding(Int.random(in: 0 ..< 1000))
                    let int: Int
                }
                """,
                expandedSource:
                """

                struct Model {
                    let int: Int
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                        case int
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        do {
                            self.int = try container.decode(Int.self, forKey: .int)
                        } catch {
                            self.int = Int.random(in: 0 ..< 1000)
                            SafeDecodingErrorReporter.shared.report(error: error, of: "int", decoding: Int.self, in: (Model).self)
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

extension ClassOrStructSafeDecodingMacrosTests {
    func testSafeDecodingOptionalDecoding() throws {
#if canImport(SafeDecodingMacros)
        // @FallbackDecoding will be ignored for "int" property as it is non-optional
        assertMacroExpansion(
                """
                @ClassOrStructSafeDecoding
                struct Model {
                    @FallbackDecoding(.zero)
                    @OptionalDecoding(-1)
                    let int: Int
                    @OptionalDecoding(false)
                    let optionalInt: Int?
                }
                """,
                expandedSource:
                """

                struct Model {
                    let int: Int
                    let optionalInt: Int?
                }

                extension Model {
                    private enum CodingKeys: CodingKey {
                        case int
                        case optionalInt
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        do {
                            self.int = try container.decode(Int.self, forKey: .int)
                        } catch {
                            self.int = .zero
                        }
                        if (false) {
                            self.optionalInt = (try? container.decode(Int.self, forKey: .optionalInt))
                        } else {
                            self.optionalInt = nil
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

extension ClassOrStructSafeDecodingMacrosTests {
    func testMacro() throws {
        #if canImport(SafeDecodingMacros)
        assertMacroExpansion(
            """
            @ClassOrStructSafeDecoding
            public struct Custom {
                let integer: Int { willSet { print("==> willSet") } didSet { print("==> didSet") } }
                let optional: Int?
                @IgnoreSafeDecoding
                let array: [Int]
                let genericArray: Array<Int>
                let dictionary: [Int: Int]
                let genericDictionary: Dictionary<Int, Int>
                var computed: Int { 0 }
            }
            """,
            expandedSource: """

            public struct Custom {
                let integer: Int { willSet { print("==> willSet") } didSet { print("==> didSet") } }
                let optional: Int?
                @IgnoreSafeDecoding
                let array: [Int]
                let genericArray: Array<Int>
                let dictionary: [Int: Int]
                let genericDictionary: Dictionary<Int, Int>
                var computed: Int { 0 }
            }

            extension Custom {
                private enum CodingKeys: CodingKey {
                    case integer
                    case optional
                    case array
                    case genericArray
                    case dictionary
                    case genericDictionary
                }
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.integer = try container.decode(Int .self, forKey: .integer)
                    self.optional = try? container.decode(Int.self, forKey: .optional)
                    self.array = try container.decode([Int].self, forKey: .array)
                    self.genericArray = ((try? container.decode([SafeDecodable<Int>].self, forKey: .genericArray)) ?? []).compactMap {
                        $0.decoded
                    }
                    self.dictionary = ((try? container.decode([Int: SafeDecodable<Int>].self, forKey: .dictionary)) ?? [:]).reduce(into: [:]) {
                        $0 [$1.key] = $1.value.decoded
                    }
                    self.genericDictionary = ((try? container.decode([Int: SafeDecodable<Int>].self, forKey: .genericDictionary)) ?? [:]).reduce(into: [:]) {
                        $0 [$1.key] = $1.value.decoded
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
