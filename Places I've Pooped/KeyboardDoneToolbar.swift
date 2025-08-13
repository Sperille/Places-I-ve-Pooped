//
//  KeyboardDoneToolbar.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/9/25.
//


import SwiftUI

private func resignFirstResponder() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
}

struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { resignFirstResponder() }
                        .font(.headline)
                }
            }
    }
}

extension View {
    /// Attach once at the root to show a Done button above any keyboard.
    func keyboardDoneToolbar() -> some View {
        modifier(KeyboardDoneToolbar())
    }
}
