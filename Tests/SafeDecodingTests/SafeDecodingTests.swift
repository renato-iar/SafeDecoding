import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling.
// Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(SafeDecodingMacros)
import SafeDecodingMacros

let testMacros: [String: Macro.Type] = [
    "SafeDecoding": SafeDecodingMacro.self,
]
#endif

final class SafeDecodingTests: XCTestCase {
}

extension SafeDecodingTests {
    func testSafeDecodingOfOptional() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @SafeDecoding
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
                        self.optional = try? container.decode((Optional<Int>).self, forKey: .optional)
                        self.optionalGeneric = try? container.decode((Optional<Int>).self, forKey: .optionalGeneric)
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
                @SafeDecoding
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
                        self.set = ((try? container.decode((Array<SafeDecodable<Int>>).self, forKey: .set)) ?? []).reduce(into: Set<Int>()) { set, safe in
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
                @SafeDecoding
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
                        self.array = ((try? container.decode((Array<SafeDecodable<Int>>).self, forKey: .array)) ?? []).compactMap {
                            $0.decoded
                        }
                        self.arrayGeneric = ((try? container.decode((Array<SafeDecodable<Int>>).self, forKey: .arrayGeneric)) ?? []).compactMap {
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
                @SafeDecoding
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
                        self.dictionary = ((try? container.decode((Dictionary<Int, SafeDecodable<Int>>).self, forKey: .dictionary)) ?? [:]).reduce(into: [:]) {
                            $0 [$1.key] = $1.value.decoded
                        }
                        self.dictionaryGeneric = ((try? container.decode((Dictionary<Int, SafeDecodable<Int>>).self, forKey: .dictionaryGeneric)) ?? [:]).reduce(into: [:]) {
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

extension SafeDecodingTests {
    func testSafeDecodingOfOptionalWithReporter() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @SafeDecoding(reporter: reporter)
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
                            self.optional = try container.decode((Int).self, forKey: .optional)
                        } catch {
                            self.optional = nil
                            reporter.report(error: error, of: "optional", decoding: (Optional<Int>).self, in: (Model).self)
                        }
                        do {
                            self.optionalGeneric = try container.decode((Int).self, forKey: .optionalGeneric)
                        } catch {
                            self.optionalGeneric = nil
                            reporter.report(error: error, of: "optionalGeneric", decoding: (Optional<Int>).self, in: (Model).self)
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
                @SafeDecoding(reporter: reporter)
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
                            let decodedItems = try container.decode((Array<SafeDecodable<Int>>).self, forKey: .set)
                            var items: Set<Int> = []

                            for item in decodedItems {
                                if let decoded = item.decoded {
                                    items.insert(decoded)
                                } else if let error = item.error {
                                    reporter.report(error: error, decoding: (Int).self, of: "set", in: (Model).self)
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
                @SafeDecoding(reporter: reporter)
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
                            let decodedArray = try container.decode((Array<SafeDecodable<Int>>).self, forKey: .array)
                            var items: [Int] = []

                            for (index, item) in decodedArray.enumerated() {
                                if let decoded = item.decoded {
                                    items.append(decoded)
                                } else if let error = item.error {
                                    reporter.report(error: error, decoding: (Int).self, at: index, of: "array", in: (Model).self)
                                }
                            }

                            self.array = items
                        } catch {
                            self.array = []
                            reporter.report(error: error, of: "array", decoding: Array<Int> .self, in: (Model).self)
                        }
                        do {
                            let decodedArray = try container.decode((Array<SafeDecodable<Int>>).self, forKey: .arrayGeneric)
                            var items: [Int] = []

                            for (index, item) in decodedArray.enumerated() {
                                if let decoded = item.decoded {
                                    items.append(decoded)
                                } else if let error = item.error {
                                    reporter.report(error: error, decoding: (Int).self, at: index, of: "arrayGeneric", in: (Model).self)
                                }
                            }

                            self.arrayGeneric = items
                        } catch {
                            self.arrayGeneric = []
                            reporter.report(error: error, of: "arrayGeneric", decoding: Array<Int> .self, in: (Model).self)
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
                @SafeDecoding(reporter: reporter)
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
                            let decodedItems = try container.decode((Dictionary<Int, SafeDecodable<Int>>).self, forKey: .dictionary)
                            var items: Dictionary<Int, Int> = [:]

                            for (key, value) in decodedItems {
                                if let decoded = value.decoded {
                                    items[key] = decoded
                                } else if let error = value.error {
                                    reporter.report(error: error, decoding: (Int).self, forKey: key, of: "dictionary", in: (Model).self)
                                }
                            }

                            self.dictionary = items
                        } catch {
                            self.dictionary = [:]
                            reporter.report(error: error, of: "dictionary", decoding: (Dictionary<Int, SafeDecodable<Int>>).self, in: (Model).self)
                        }
                        do {
                            let decodedItems = try container.decode((Dictionary<Int, SafeDecodable<Int>>).self, forKey: .dictionaryGeneric)
                            var items: Dictionary<Int, Int> = [:]

                            for (key, value) in decodedItems {
                                if let decoded = value.decoded {
                                    items[key] = decoded
                                } else if let error = value.error {
                                    reporter.report(error: error, decoding: (Int).self, forKey: key, of: "dictionaryGeneric", in: (Model).self)
                                }
                            }

                            self.dictionaryGeneric = items
                        } catch {
                            self.dictionaryGeneric = [:]
                            reporter.report(error: error, of: "dictionaryGeneric", decoding: (Dictionary<Int, SafeDecodable<Int>>).self, in: (Model).self)
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

extension SafeDecodingTests {
    func testSafeDecodingIgnoresComputedProperty() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @SafeDecoding(reporter: SafeDecodingErrorReporter.shared)
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
                @SafeDecoding
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

extension SafeDecodingTests {
    func testSafeDecodingMacroRespectsDefaultAccessModifier() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @SafeDecoding
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
                @SafeDecoding
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
                @SafeDecoding
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
                @SafeDecoding
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
                @SafeDecoding
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

extension SafeDecodingTests {
    func testMacro() throws {
        #if canImport(SafeDecodingMacros)
        assertMacroExpansion(
            """
            @SafeDecoding
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
                    self.integer = try container.decode((Int ).self, forKey: .integer)
                    self.optional = try? container.decode((Optional<Int>).self, forKey: .optional)
                    self.array = try container.decode(([Int]).self, forKey: .array)
                    self.genericArray = ((try? container.decode((Array<SafeDecodable<Int>>).self, forKey: .genericArray)) ?? []).compactMap {
                        $0.decoded
                    }
                    self.dictionary = ((try? container.decode((Dictionary<Int, SafeDecodable<Int>>).self, forKey: .dictionary)) ?? [:]).reduce(into: [:]) {
                        $0 [$1.key] = $1.value.decoded
                    }
                    self.genericDictionary = ((try? container.decode((Dictionary<Int, SafeDecodable<Int>>).self, forKey: .genericDictionary)) ?? [:]).reduce(into: [:]) {
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
