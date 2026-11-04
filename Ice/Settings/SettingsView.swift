//
//  SettingsView.swift
//  Ice
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var navigationState: AppNavigationState
    @Environment(\.sidebarRowSize) var sidebarRowSize

    private var sidebarWidth: CGFloat {
        switch sidebarRowSize {
        case .small: 190
        case .medium: 210
        case .large: 230
        @unknown default: 210
        }
    }

    private var sidebarIconSize: CGFloat {
        switch sidebarRowSize {
        case .small: 16
        case .medium: 20
        case .large: 26
        @unknown default: 20
        }
    }

    private var sidebarItemFontSize: CGFloat {
        switch sidebarRowSize {
        case .small: 13
        case .medium: 13
        case .large: 15
        @unknown default: 13
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
                .environment(\.iceFormStyle, .settings)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle(navigationState.settingsNavigationIdentifier.localized)
    }

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $navigationState.settingsNavigationIdentifier) {
            ForEach(SettingsNavigationIdentifier.allCases, id: \.self) { identifier in
                sidebarItem(for: identifier)
                    .tag(identifier)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 8) {
            HStack(spacing: 10) {
                SettingsPaneIcon(identifier: .about, size: 28)
                Text("Ice")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)
        }
        .removeSidebarToggle()
        .navigationSplitViewColumnWidth(sidebarWidth)
    }

    @ViewBuilder
    private var detailView: some View {
        switch navigationState.settingsNavigationIdentifier {
        case .general:
            GeneralSettingsPane()
        case .menuBarLayout:
            MenuBarLayoutSettingsPane()
        case .menuBarAppearance:
            MenuBarAppearanceSettingsPane()
        case .hotkeys:
            HotkeysSettingsPane()
        case .advanced:
            AdvancedSettingsPane()
        case .about:
            AboutSettingsPane()
        }
    }

    @ViewBuilder
    private func sidebarItem(for identifier: SettingsNavigationIdentifier) -> some View {
        HStack(spacing: 6) {
            SettingsPaneIcon(identifier: identifier, size: sidebarIconSize)
            Text(identifier.localized)
                .font(.system(size: sidebarItemFontSize))
            Spacer(minLength: 0)
        }
        // The native sidebar adds its own vertical row insets around this content.
        .frame(minHeight: sidebarIconSize)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
