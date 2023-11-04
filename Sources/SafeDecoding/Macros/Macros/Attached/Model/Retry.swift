import SwiftSyntax

struct Retry {
    let type: SyntaxProtocol
    let mapper: SyntaxProtocol

    init(
        type: SyntaxProtocol,
        mapper: SyntaxProtocol
    ) {
        self.type = type
        self.mapper = mapper
    }

    init?(from syntax: SyntaxProtocol) {
        guard
            let attribute = syntax.as(AttributeSyntax.self),
            attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "RetryDecoding",
            let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
            arguments.count == 2,
            let type = arguments.first?.as(LabeledExprSyntax.self)?.expression,
            let mapper = arguments.last?.as(LabeledExprSyntax.self)?.expression
        else {
            return nil
        }

        self.type = type
        self.mapper = mapper
    }
}
