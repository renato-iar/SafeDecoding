import Foundation

extension String {
    var plain: String {
        self.reduce("") {
            $0 + ($1.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains(_:)) ? "\($1)" : "_")
        }
    }
}
