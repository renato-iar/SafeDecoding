import Foundation

extension Collection where Element == Bool {
    var any: Bool {
        self.reduce(false) { $0 || $1 }
    }

    var all: Bool {
        self.reduce(true) { $0 && $1 }
    }
}
