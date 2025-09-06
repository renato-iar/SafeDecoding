import Foundation
import SafeDecoding

class MockReporterInterceptor: SafeDecodingReporter {
    var didCallReportErrorOfPropertyNameInContainer: [String] = []
    var didCallReportErrorForItemAtIndexOfPropertyNameInContainer: [(index: Int, propertyName: String)] = []
    var didCallReportErrorForItemOfPropertyNameInContainer: [String] = []
    var didCallReportErrorForItemWithKeyOrPropertyNameInContainer: [(key: String, propertyName: String)] = []
    var didCallReportErrorInContainerType: Int = .zero

    func clear() {
        didCallReportErrorOfPropertyNameInContainer = []
        didCallReportErrorForItemAtIndexOfPropertyNameInContainer = []
        didCallReportErrorForItemOfPropertyNameInContainer = []
        didCallReportErrorForItemWithKeyOrPropertyNameInContainer = []
    }

    func report<Container, Property>(error: Error, of propertyName: String, decoding propertyType: Property.Type, in containerType: Container.Type) {
        didCallReportErrorOfPropertyNameInContainer.append(propertyName)
    }

    func report<Container, Item>(error: Error, decoding itemType: Item.Type, at index: Int, of propertyName: String, in containerType: Container.Type) {
        didCallReportErrorForItemAtIndexOfPropertyNameInContainer.append((index, propertyName))
    }

    func report<Container, Item>(error: Error, decoding itemType: Item.Type, of propertyName: String, in containerType: Container.Type) {
        didCallReportErrorForItemOfPropertyNameInContainer.append(propertyName)
    }

    func report<Container, Key, Item>(error: Error, decoding itemType: Item.Type, forKey key: Key, of propertyName: String, in containerType: Container.Type) where Key : Hashable {
        didCallReportErrorForItemWithKeyOrPropertyNameInContainer.append(("\(key)", propertyName))
    }

    func report<Container>(error: any Error, in containerType: Container.Type) {
        didCallReportErrorInContainerType += 1
    }
}
