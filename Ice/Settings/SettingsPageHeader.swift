//
//  SettingsPageHeader.swift
//  Ice
//

import SwiftUI

/// A shared identity for each settings pane, used in its sidebar row and introduction.
struct SettingsPaneIcon: View {
    let identifier: SettingsNavigationIdentifier
    var size: CGFloat = 48

    private var symbol: String {
        switch identifier {
        case .general: "gearshape"
        case .menuBarLayout: "rectangle.topthird.inset.filled"
        case .menuBarAppearance: "paintpalette.fill"
        case .hotkeys: "keyboard.fill"
        case .advanced: "gearshape.2"
        case .about: "cube.fill"
        }
    }

    private var color: Color {
        switch identifier {
        case .general, .advanced: Color(nsColor: .systemGray)
        case .menuBarLayout, .about: .blue
        case .menuBarAppearance: .purple
        case .hotkeys: .indigo
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.62, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct SettingsPageHeader: View {
    let identifier: SettingsNavigationIdentifier

    private var summary: LocalizedStringKey {
        switch identifier {
        case .general: "Manage how Ice starts and how your hidden menu bar items appear."
        case .menuBarLayout: "Keep your menu bar organized by choosing where each item belongs."
        case .menuBarAppearance: "Personalize the look of your menu bar to match your Mac."
        case .hotkeys: "Quickly access your menu bar items with keyboard shortcuts."
        case .advanced: "Fine-tune menu bar behavior and manage Ice’s permissions."
        case .about: "A little more space for what matters."
        }
    }

    var body: some View {
        IceGroupBox(padding: 20) {
            VStack(spacing: 8) {
                SettingsPaneIcon(identifier: identifier)
                    .padding(.bottom, 2)
                Text(identifier.localized)
                    .font(.system(size: 22, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
