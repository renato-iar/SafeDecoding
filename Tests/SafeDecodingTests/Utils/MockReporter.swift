import Foundation
import SafeDecoding

class MockReporter: SafeDecodingReporter {

    var interceptor: SafeDecodingReporter?

    func report<Container, Property>(error: Error, of propertyName: String, decoding propertyType: Property.Type, in containerType: Container.Type) {
        interceptor?.report(error: error, of: propertyName, decoding: propertyType, in: containerType)
    }
    
    func report<Container, Item>(error: Error, decoding itemType: Item.Type, at index: Int, of propertyName: String, in containerType: Container.Type) {
        interceptor?.report(error: error, decoding: itemType, at: index, of: propertyName, in: containerType)
    }
    
    func report<Container, Item>(error: Error, decoding itemType: Item.Type, of propertyName: String, in containerType: Container.Type) {
        interceptor?.report(error: error, decoding: itemType, of: propertyName, in: containerType)
    }
    
    func report<Container, Key, Item>(error: Error, decoding itemType: Item.Type, forKey key: Key, of propertyName: String, in containerType: Container.Type) where Key : Hashable {
        interceptor?.report(error: error, decoding: itemType, forKey: key, of: propertyName, in: containerType)
    }

    func report<Container>(error: any Error, in containerType: Container.Type) {
        interceptor?.report(error: error, in: containerType)
    }

    private init() { }

    static let shared = MockReporter()
}
