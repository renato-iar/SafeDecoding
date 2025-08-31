import Foundation

extension String {
    func camelCased(capitalizeFirstSegment: Bool = false) -> String {
        guard !isEmpty else { return "" }

        let output = components(separatedBy: .alphanumerics.inverted)
            .enumerated()
            .map { offset, element in
                if capitalizeFirstSegment || offset > .zero {
                    return element.prefix(1).capitalized + element.dropFirst()
                } else {
                    return element
                }
            }
            .joined()

        return output
    }

    var camelCased: String {
        camelCased()
    }

    var snakeCased: String {
        guard !isEmpty else { return self }

        let step1 = camelCased.replacing(
            #/([A-Z]+)([A-Z][a-z])/#
        ) { match in
            return "\(match.output.1)_\(match.output.2)"
        }

        let step2 = step1.replacing(
            #/([a-z0-9])([A-Z]|[^A-Za-z0-9])/#
        ) { match in
            let left = String(match.output.1)
            let right = String(match.output.2)

            if right.unicodeScalars.allSatisfy({ !CharacterSet.alphanumerics.contains($0) }) {
                return "\(left)_"
            } else {
                return "\(left)_\(right)"
            }
        }

        let output = step2
            .lowercased()
            .replacing(#/_+/#, with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return output
    }

    var snakeUppercased: String {
        snakeCased.uppercased()
    }

    var kebabCased: String {
        snakeCased
            .replacingOccurrences(
                of: "_",
                with: "-"
            )
    }

    var kebabUppercased: String {
        kebabCased.uppercased()
    }

    var flat: String {
        replacingOccurrences(
            of: "_-",
            with: ""
        )
        .lowercased()
    }
}
