//
//  IceLabeledContent.swift
//  Ice
//

import SwiftUI

struct IceLabeledContent<Label: View, Content: View>: View {
    @Environment(\.iceSettingHelp) private var settingHelp

    private let label: Label
    private let content: Content

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.label = label()
        self.content = content()
    }

    init(
        _ titleKey: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) where Label == Text {
        self.init {
            content()
        } label: {
            Text(titleKey)
        }
    }

    var body: some View {
        if let settingHelp {
            // LabeledContent merges buttons inside its label into the value control's accessibility element.
            HStack {
                HStack(spacing: 4) {
                    label
                    IceSettingHelpButton(text: settingHelp)
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
                content
            }
            .environment(\.iceSettingHelp, nil)
        } else {
            LabeledContent {
                content
                    .layoutPriority(1)
            } label: {
                label
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(0)
            }
        }
    }
}

private struct IceSettingHelpKey: EnvironmentKey {
    static let defaultValue: Text? = nil
}

extension EnvironmentValues {
    fileprivate var iceSettingHelp: Text? {
        get { self[IceSettingHelpKey.self] }
        set { self[IceSettingHelpKey.self] = newValue }
    }
}

extension View {
    /// Adds contextual help beside the nearest IceLabeledContent label.
    func settingHelp(_ text: Text?) -> some View {
        environment(\.iceSettingHelp, text)
    }

    func settingHelp(_ key: LocalizedStringKey) -> some View {
        settingHelp(Text(key))
    }
}

private struct IceSettingHelpButton: View {
    @Environment(\.locale) private var locale
    @State private var isPresented = false

    let text: Text

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(text)
        .accessibilityLabel("Help")
        .accessibilityHint(text)
        .popover(isPresented: $isPresented) {
            text
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(width: 280, alignment: .leading)
                .environment(\.locale, locale)
        }
    }
}
