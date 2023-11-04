import Foundation
import SafeDecoding
import XCTest

final class PropertyCaseEnumSafeDecodingTests: XCTestCase {
    private let interceptor = MockReporterInterceptor()
}

// MARK: - SetUp/TearDown

extension PropertyCaseEnumSafeDecodingTests {
    override func setUp() {
        super.setUp()

        MockReporter.shared.interceptor = interceptor
    }

    override func tearDown() {
        super.tearDown()

        interceptor.clear()
        MockReporter.shared.interceptor = nil
    }
}

// MARK: - Test optionals

extension PropertyCaseEnumSafeDecodingTests {
    func testSafeDecodingDecodesOptionalCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithOptionalStringParameter",
                        "optionalString": "optionalString value"
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithOptionalStringParameter(optionalString: value):
            XCTAssertEqual(value, "optionalString value")
            XCTAssertTrue(interceptor.didCallReportErrorOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithOptionalStringParameter")
        }
    }

    func testSafeDecodingRecoversFromMissingOptionalCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithOptionalStringParameter"
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithOptionalStringParameter(optionalString: value):
            XCTAssertNil(value)
            XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["elementWithOptionalStringParameter.optionalString"])

        default:
            XCTFail("Expected elementWithOptionalStringParameter")
        }
    }

    func testSafeDecodingRecoversFromIncorrectOptionalCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithOptionalStringParameter",
                        "optionalString": 1
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithOptionalStringParameter(optionalString: value):
            XCTAssertNil(value)
            XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["elementWithOptionalStringParameter.optionalString"])

        default:
            XCTFail("Expected elementWithOptionalStringParameter")
        }
    }
}

// MARK: - Test arrays

extension PropertyCaseEnumSafeDecodingTests {
    func testSafeDecodingDecodesArrayCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringArrayParameter",
                        "stringArray": ["s1", "s2", "s3"]
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringArrayParameter(stringArray: array):
            XCTAssertEqual(array, ["s1", "s2", "s3"])
            XCTAssertTrue(interceptor.didCallReportErrorOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }

    func testSafeDecodingRecoversFromMissingArrayCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringArrayParameter"
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringArrayParameter(stringArray: array):
            XCTAssertEqual(array, [])
            XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["elementWithStringArrayParameter.stringArray"])
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }

    func testSafeDecodingRecoversFromIncorrectArrayCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringArrayParameter",
                        "stringArray": 0
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringArrayParameter(stringArray: array):
            XCTAssertEqual(array, [])
            XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["elementWithStringArrayParameter.stringArray"])
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }

    func testSafeDecodingRecoversFromIncorrectItemsInArrayCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringArrayParameter",
                        "stringArray": ["a", "b", 0, "c"]
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringArrayParameter(stringArray: array):
            XCTAssertEqual(array, ["a", "b", "c"])
            XCTAssertTrue(interceptor.didCallReportErrorOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.count, 1)
            XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.first?.index, 2)
            XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.first?.propertyName, "elementWithStringArrayParameter.stringArray")
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }
}

// MARK: - Test sets

extension PropertyCaseEnumSafeDecodingTests {
    func testSafeDecodingDecodesSetCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringSetParameter",
                        "stringSet": ["s1", "s2", "s3"]
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringSetParameter(stringSet: set):
            XCTAssertEqual(set, ["s1", "s2", "s3"])
            XCTAssertTrue(interceptor.didCallReportErrorOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }

    func testSafeDecodingRecoversFromMissingSetCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringSetParameter"
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringSetParameter(stringSet: set):
            XCTAssertEqual(set, [])
            XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["elementWithStringSetParameter.stringSet"])
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }

    func testSafeDecodingRecoversFromIncorrectSetCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringSetParameter",
                        "stringSet": 0
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringSetParameter(stringSet: set):
            XCTAssertEqual(set, [])
            XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["elementWithStringSetParameter.stringSet"])
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }

    func testSafeDecodingRecoversFromIncorrectItemsInSetCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringSetParameter",
                        "stringSet": ["a", "b", 0, "c"]
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringSetParameter(stringSet: set):
            XCTAssertEqual(set, ["a", "b", "c"])
            XCTAssertTrue(interceptor.didCallReportErrorOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.count, 1)
            XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.first?.index, 2)
            XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.first?.propertyName, "elementWithStringSetParameter.stringSet")
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }
}

// MARK: - Test dictionaries

extension PropertyCaseEnumSafeDecodingTests {
    func testSafeDecodingDecodesDictionaryCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringToIntDictionaryParameter",
                        "stringToIntDictionary": {
                            "item-0": 0,
                            "item-1": 1
                        }
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringToIntDictionaryParameter(stringToIntDictionary: dictionary):
            XCTAssertEqual(dictionary, ["item-0": 0, "item-1": 1])
            XCTAssertTrue(interceptor.didCallReportErrorOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }

    func testSafeDecodingRecoversFromMissingDictionaryCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringToIntDictionaryParameter"
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringToIntDictionaryParameter(stringToIntDictionary: dictionary):
            XCTAssertEqual(dictionary, [:])
            XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["elementWithStringToIntDictionaryParameter.stringToIntDictionary"])
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }

    func testSafeDecodingRecoversFromIncorrectDictionaryCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringToIntDictionaryParameter",
                        "stringToIntDictionary": 0
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringToIntDictionaryParameter(stringToIntDictionary: dictionary):
            XCTAssertEqual(dictionary, [:])
            XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["elementWithStringToIntDictionaryParameter.stringToIntDictionary"])
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }

    func testSafeDecodingRecoversFromIncorrectItemsInDictionaryCaseParameter() throws {
        let input = """
                    {
                        "type": "elementWithStringToIntDictionaryParameter",
                        "stringToIntDictionary": {
                            "item-0": 0,
                            "item-1": "incorrect",
                            "item-2": 2
                        }
                    }
                    """
        let testModel = try XCTUnwrap(DecodingUtils.decode(PropertyCasedEnumTestModel.self, input: input))

        switch testModel {
        case let .elementWithStringToIntDictionaryParameter(stringToIntDictionary: dictionary):
            XCTAssertEqual(dictionary, ["item-0": 0, "item-2": 2])
            XCTAssertTrue(interceptor.didCallReportErrorOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemOfPropertyNameInContainer.isEmpty)
            XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
            XCTAssertEqual(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.count, 1)
            XCTAssertEqual(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.first?.key, "item-1")
            XCTAssertEqual(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.first?.propertyName, "elementWithStringToIntDictionaryParameter.stringToIntDictionary")

        default:
            XCTFail("Expected elementWithStringArrayParameter")
        }
    }
}
