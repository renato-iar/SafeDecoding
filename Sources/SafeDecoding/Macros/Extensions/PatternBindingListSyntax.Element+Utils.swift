import SwiftSyntax

extension PatternBindingListSyntax.Element {
    var isComputed: Bool {
        self
            .accessorBlock?
            .accessors
            .is(CodeBlockItemListSyntax.self) == true
    }

    var isInitialized: Bool {
        self.initializer != nil
    }
}
