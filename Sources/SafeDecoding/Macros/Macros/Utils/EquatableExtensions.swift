import Foundation

extension Equatable {
    func `in`(_ collection: some Collection<Self>) -> Bool {
        collection.contains(self)
    }

    func `in`(_ collection: Self ...) -> Bool {
        self.in(collection)
    }
}
