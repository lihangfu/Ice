//
//  SettingsTitlebar.swift
//  Ice
//

import SwiftUI

struct SettingsTitlebar: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: LocalizedStringKey
    let height: CGFloat
    let leading: CGFloat
    let isScrolled: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .accessibilityAddTraits(.isHeader)
            .padding(.leading, leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .background {
                if isScrolled {
                    VisualEffectView(
                        material: .titlebar,
                        blendingMode: .withinWindow,
                        state: .followsWindowActiveState,
                        isEmphasized: false
                    )
                } else {
                    SettingsPalette.background(for: colorScheme)
                }
            }
            .overlay(alignment: .bottom) {
                if isScrolled {
                    Divider()
                }
            }
            .allowsHitTesting(false)
    }
}
