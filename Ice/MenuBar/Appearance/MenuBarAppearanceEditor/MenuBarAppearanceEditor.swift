//
//  MenuBarAppearanceEditor.swift
//  Ice
//

import SwiftUI

struct MenuBarAppearanceEditor: View {
    enum Location {
        case settings
        case popover(closePopover: () -> Void)
    }

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appearanceManager: MenuBarAppearanceManager

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let location: Location

    private var mainFormPadding: EdgeInsets {
        with(EdgeInsets(all: 20)) { insets in
            switch location {
            case .settings: break
            case .popover: insets.top = 0
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stackHeader
            stackBody
        }
    }

    @ViewBuilder
    private var stackHeader: some View {
        if case .popover(let closePopover) = location {
            ZStack {
                Text("Menu Bar Appearance")
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .center)
                Button("Done", action: closePopover)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var stackBody: some View {
        if appState.menuBarManager.isMenuBarHiddenBySystemUserDefaults {
            cannotEdit
        } else {
            mainForm
        }
    }

    @ViewBuilder
    private var mainForm: some View {
        IceForm(padding: mainFormPadding) {
            if case .settings = location {
                SettingsPageHeader(identifier: .menuBarAppearance)
            }
            IceSection {
                IceLabeledContent("Background blur") {
                    HStack {
                        Slider(value: appearanceManager.bindings.configuration.wallpaperBlurRadius, in: 0...30)
                            .accessibilityLabel(Text("Background blur"))
                        Text("\(Int((appearanceManager.configuration.wallpaperBlurRadius / 30 * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                    .frame(width: 220)
                    .disabled(reduceTransparency || !MenuBarWallpaperBlurView.isSupported)
                }
                .settingHelp("Blur the wallpaper behind menu bar text and icons. Zero restores the system background. Requires screen recording permission and Reduce Transparency to be off.")
                if reduceTransparency || !MenuBarWallpaperBlurView.isSupported {
                    Text("Background blur is unavailable with Reduce Transparency or on this system.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            UnlabeledPartialEditor(configuration: appearanceManager.bindings.configuration.staticConfiguration)
            IceSection("Menu Bar Shape") {
                shapePicker
                isInset
            }
            if case .settings = location {
                IceGroupBox {
                    AnnotationView(
                        alignment: .center,
                        font: .callout.bold()
                    ) {
                        Label {
                            Text("Tip: you can also edit these settings by right-clicking in an empty area of the menu bar")
                        } icon: {
                            Image(systemName: "lightbulb")
                        }
                    }
                }
            }
            if
                !appState.menuBarManager.isMenuBarHiddenBySystemUserDefaults,
                appearanceManager.configuration != .defaultConfiguration
            {
                Button("Reset") {
                    appearanceManager.configuration = .defaultConfiguration
                }
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }

    @ViewBuilder
    private var cannotEdit: some View {
        Text("Ice cannot edit the appearance of automatically hidden menu bars")
            .font(.title3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var shapePicker: some View {
        MenuBarShapePicker()
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var isInset: some View {
        if appearanceManager.configuration.shapeKind != .none {
            Toggle(
                "Use inset shape on screens with notch",
                isOn: appearanceManager.bindings.configuration.isInset
            )
        }
    }
}

private struct UnlabeledPartialEditor: View {
    @Binding var configuration: MenuBarAppearancePartialConfiguration

    var body: some View {
        IceSection {
            tintPicker
            shadowToggle
        }
        IceSection {
            borderToggle
            borderColor
            borderWidth
        }
    }

    @ViewBuilder
    private var tintPicker: some View {
        IceLabeledContent("Tint") {
            HStack {
                IcePicker("Tint", selection: $configuration.tintKind) {
                    ForEach(MenuBarTintKind.allCases) { tintKind in
                        Text(tintKind.localized).tag(tintKind)
                    }
                }
                .labelsHidden()

                switch configuration.tintKind {
                case .none:
                    EmptyView()
                case .solid:
                    CustomColorPicker(
                        selection: $configuration.tintColor,
                        supportsOpacity: false,
                        mode: .crayon
                    )
                case .gradient:
                    CustomGradientPicker(
                        gradient: $configuration.tintGradient,
                        supportsOpacity: false,
                        allowsEmptySelections: false,
                        mode: .crayon
                    )
                }
            }
            .frame(height: 24)
        }
    }

    @ViewBuilder
    private var shadowToggle: some View {
        Toggle("Shadow", isOn: $configuration.hasShadow)
    }

    @ViewBuilder
    private var borderToggle: some View {
        Toggle("Border", isOn: $configuration.hasBorder)
    }

    @ViewBuilder
    private var borderColor: some View {
        if configuration.hasBorder {
            IceLabeledContent("Border Color") {
                CustomColorPicker(
                    selection: $configuration.borderColor,
                    supportsOpacity: true,
                    mode: .crayon
                )
            }
        }
    }

    @ViewBuilder
    private var borderWidth: some View {
        if configuration.hasBorder {
            IcePicker(
                "Border Width",
                selection: $configuration.borderWidth
            ) {
                Text("1").tag(1.0)
                Text("2").tag(2.0)
                Text("3").tag(3.0)
            }
        }
    }
}
