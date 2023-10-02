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
                    public init(from decoder: Decoder) throws {
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
                    public init(from decoder: Decoder) throws {
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
                    public init(from decoder: Decoder) throws {
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
                    public init(from decoder: Decoder) throws {
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

    func testSafeDecodingIgnoresComputedProperty() throws {
#if canImport(SafeDecodingMacros)
        assertMacroExpansion(
                """
                @SafeDecoding
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
