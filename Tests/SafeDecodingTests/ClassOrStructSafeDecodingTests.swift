import Foundation
import SafeDecoding
import XCTest

final class ClassOrStructSafeDecodingTests: XCTestCase {
    let interceptor = MockReporterInterceptor()
}

// MARK: - SetUp/TearDown

extension ClassOrStructSafeDecodingTests {
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

// MARK: - Plain model

extension ClassOrStructSafeDecodingTests {
    func testSafeDecodingRecoversFromMissingOptional() throws {
        let input = """
                    {
                        "integerArray": [1],
                        "integerSet": [1],
                        "stringToIntDictionary": { "a": 1 }
                    }
                    """
        let model = try XCTUnwrap(DecodingUtils.decode(TestModel.self, input: input))
        XCTAssertNil(model.optionalInteger)
        XCTAssertEqual(model.integerArray, [1])
        XCTAssertEqual(model.integerSet, [1])
        XCTAssertEqual(model.stringToIntDictionary, ["a": 1])
        XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, [])
        XCTAssertEqual(interceptor.didCallReportErrorForItemOfPropertyNameInContainer, [])
        XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
        XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)
    }

    func testSafeDecodingRecoversFromInvalidOptional() throws {
        let input = """
                    {
                        "optionalInteger": "",
                        "integerArray": [1],
                        "integerSet": [1],
                        "stringToIntDictionary": { "a": 1 }
                    }
                    """
        let model = try XCTUnwrap(DecodingUtils.decode(TestModel.self, input: input))
        XCTAssertNil(model.optionalInteger)
        XCTAssertEqual(model.integerArray, [1])
        XCTAssertEqual(model.integerSet, [1])
        XCTAssertEqual(model.stringToIntDictionary, ["a": 1])
        XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["optionalInteger"])
        XCTAssertEqual(interceptor.didCallReportErrorForItemOfPropertyNameInContainer, [])
        XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
        XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)
    }

    func testSafeDecodingRecoversFromMissingArray() throws {
        let input = """
                    {
                        "optionalInteger": 0,
                        "integerSet": [1],
                        "stringToIntDictionary": { "a": 1 }
                    }
                    """
        let model = try XCTUnwrap(DecodingUtils.decode(TestModel.self, input: input))
        XCTAssertEqual(model.optionalInteger, 0)
        XCTAssertEqual(model.integerArray, [])
        XCTAssertEqual(model.integerSet, [1])
        XCTAssertEqual(model.stringToIntDictionary, ["a": 1])
        XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["integerArray"])
        XCTAssertEqual(interceptor.didCallReportErrorForItemOfPropertyNameInContainer, [])
        XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
        XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)
    }

    func testSafeDecodingRecoversFromInvalidArray() throws {
        let input = """
                    {
                        "optionalInteger": 0,
                        "integerArray": "",
                        "integerSet": [1],
                        "stringToIntDictionary": { "a": 1 }
                    }
                    """
        let model = try XCTUnwrap(DecodingUtils.decode(TestModel.self, input: input))
        XCTAssertEqual(model.optionalInteger, 0)
        XCTAssertEqual(model.integerArray, [])
        XCTAssertEqual(model.integerSet, [1])
        XCTAssertEqual(model.stringToIntDictionary, ["a": 1])
        XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["integerArray"])
        XCTAssertEqual(interceptor.didCallReportErrorForItemOfPropertyNameInContainer, [])
        XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
        XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)
    }

    func testSafeDecodingRecoversFromInvalidArrayElements() throws {
        let input = """
                    {
                        "optionalInteger": 0,
                        "integerArray": [0, "a", 2],
                        "integerSet": [1],
                        "stringToIntDictionary": { "a": 1 }
                    }
                    """
        let model = try XCTUnwrap(DecodingUtils.decode(TestModel.self, input: input))
        XCTAssertEqual(model.optionalInteger, 0)
        XCTAssertEqual(model.integerArray, [0, 2])
        XCTAssertEqual(model.integerSet, [1])
        XCTAssertEqual(model.stringToIntDictionary, ["a": 1])
        XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, [])
        XCTAssertEqual(interceptor.didCallReportErrorForItemOfPropertyNameInContainer, [])
        XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.count, 1)
        XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.first?.index, 1)
        XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.first?.propertyName, "integerArray")
        XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)
    }

    func testSafeDecodingRecoversFromMissingSet() throws {
        let input = """
                    {
                        "optionalInteger": 0,
                        "integerArray": [1],
                        "stringToIntDictionary": { "a": 1 }
                    }
                    """
        let model = try XCTUnwrap(DecodingUtils.decode(TestModel.self, input: input))
        XCTAssertEqual(model.optionalInteger, 0)
        XCTAssertEqual(model.integerArray, [1])
        XCTAssertEqual(model.integerSet, [])
        XCTAssertEqual(model.stringToIntDictionary, ["a": 1])
        XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["integerSet"])
        XCTAssertEqual(interceptor.didCallReportErrorForItemOfPropertyNameInContainer, [])
        XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
        XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)
    }

    func testSafeDecodingRecoversFromInvalidSet() throws {
        let input = """
                    {
                        "optionalInteger": 0,
                        "integerArray": [1],
                        "integerSet": 0,
                        "stringToIntDictionary": { "a": 1 }
                    }
                    """
        let model = try XCTUnwrap(DecodingUtils.decode(TestModel.self, input: input))
        XCTAssertEqual(model.optionalInteger, 0)
        XCTAssertEqual(model.integerArray, [1])
        XCTAssertEqual(model.integerSet, [])
        XCTAssertEqual(model.stringToIntDictionary, ["a": 1])
        XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["integerSet"])
        XCTAssertEqual(interceptor.didCallReportErrorForItemOfPropertyNameInContainer, [])
        XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
        XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)
    }

    func testSafeDecodingRecoversFromInvalidSetElements() throws {
        let input = """
                    {
                        "optionalInteger": 0,
                        "integerArray": [1],
                        "integerSet": [0, "error-1", 2, "error-3"],
                        "stringToIntDictionary": { "a": 1 }
                    }
                    """
        let model = try XCTUnwrap(DecodingUtils.decode(TestModel.self, input: input))
        XCTAssertEqual(model.optionalInteger, 0)
        XCTAssertEqual(model.integerArray, [1])
        XCTAssertEqual(model.integerSet, [0, 2])
        XCTAssertEqual(model.stringToIntDictionary, ["a": 1])
        XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, [])
        XCTAssertEqual(interceptor.didCallReportErrorForItemOfPropertyNameInContainer, [])
        XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.count, 2)
        XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.first?.index, 1)
        XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.first?.propertyName, "integerSet")
        XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.last?.index, 3)
        XCTAssertEqual(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.last?.propertyName, "integerSet")
        XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)
    }

    func testSafeDecodingRecoversFromMissingDictionary() throws {
        let input = """
                    {
                        "optionalInteger": 0,
                        "integerArray": [1],
                        "integerSet": [1]
                    }
                    """
        let model = try XCTUnwrap(DecodingUtils.decode(TestModel.self, input: input))
        XCTAssertEqual(model.optionalInteger, 0)
        XCTAssertEqual(model.integerArray, [1])
        XCTAssertEqual(model.integerSet, [1])
        XCTAssertEqual(model.stringToIntDictionary, [:])
        XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["stringToIntDictionary"])
        XCTAssertEqual(interceptor.didCallReportErrorForItemOfPropertyNameInContainer, [])
        XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
        XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)
    }

    func testSafeDecodingRecoversFromInvalidDictionary() throws {
        let input = """
                    {
                        "optionalInteger": 0,
                        "integerArray": [1],
                        "integerSet": [1],
                        "stringToIntDictionary": 0
                    }
                    """
        let model = try XCTUnwrap(DecodingUtils.decode(TestModel.self, input: input))
        XCTAssertEqual(model.optionalInteger, 0)
        XCTAssertEqual(model.integerArray, [1])
        XCTAssertEqual(model.integerSet, [1])
        XCTAssertEqual(model.stringToIntDictionary, [:])
        XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, ["stringToIntDictionary"])
        XCTAssertEqual(interceptor.didCallReportErrorForItemOfPropertyNameInContainer, [])
        XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
        XCTAssertTrue(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.isEmpty)
    }

    func testSafeDecodingRecoversFromInvalidDictionaryValues() throws {
        let input = """
                    {
                        "optionalInteger": 0,
                        "integerArray": [1],
                        "integerSet": [1],
                        "stringToIntDictionary": {
                            "item-0": 0,
                            "item-1": true,
                            "item-2": 2,
                            "item-3": "error"
                        }
                    }
                    """
        let model = try XCTUnwrap(DecodingUtils.decode(TestModel.self, input: input))
        XCTAssertEqual(model.optionalInteger, 0)
        XCTAssertEqual(model.integerArray, [1])
        XCTAssertEqual(model.integerSet, [1])
        XCTAssertEqual(model.stringToIntDictionary, ["item-0": 0, "item-2": 2])
        XCTAssertEqual(interceptor.didCallReportErrorOfPropertyNameInContainer, [])
        XCTAssertEqual(interceptor.didCallReportErrorForItemOfPropertyNameInContainer, [])
        XCTAssertTrue(interceptor.didCallReportErrorForItemAtIndexOfPropertyNameInContainer.isEmpty)
        XCTAssertEqual(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.count, 2)
        XCTAssertEqual(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.first?.key, "item-1")
        XCTAssertEqual(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.first?.propertyName, "stringToIntDictionary")
        XCTAssertEqual(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.last?.key, "item-3")
        XCTAssertEqual(interceptor.didCallReportErrorForItemWithKeyOrPropertyNameInContainer.last?.propertyName, "stringToIntDictionary")
    }
}
