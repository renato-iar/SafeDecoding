enum PropertyNameCasingStrategy: String {
    case camel
    case snake
    case snakeUppercase
    case kebab
    case kebabUppercase
    case flat
}

extension PropertyNameCasingStrategy {
    func casing(_ string: String) -> String {
        switch self {
        case .camel:
            string.camelCased

        case .snake:
            string.snakeCased

        case .snakeUppercase:
            string.snakeUppercased

        case .kebab:
            string.kebabCased

        case .kebabUppercase:
            string.kebabUppercased

        case .flat:
            string.flat
        }
    }
}
