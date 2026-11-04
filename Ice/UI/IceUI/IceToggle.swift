//
//  IceToggle.swift
//  Ice
//

import SwiftUI

/// Keeps the row label and its help button outside Toggle's combined accessibility element.
struct IceToggle: View {
    @Binding private var isOn: Bool
    private let titleKey: LocalizedStringKey

    init(_ titleKey: LocalizedStringKey, isOn: Binding<Bool>) {
        self.titleKey = titleKey
        self._isOn = isOn
    }

    var body: some View {
        IceLabeledContent(titleKey) {
            Toggle(titleKey, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }
}
