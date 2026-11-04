//
//  IceForm.swift
//  Ice
//

import SwiftUI

enum IceFormStyle {
    case standard
    case settings
}

private struct IceFormStyleKey: EnvironmentKey {
    static let defaultValue = IceFormStyle.standard
}

extension EnvironmentValues {
    var iceFormStyle: IceFormStyle {
        get { self[IceFormStyleKey.self] }
        set { self[IceFormStyleKey.self] = newValue }
    }
}

struct IceForm<Content: View>: View {
    @Environment(\.isScrollEnabled) private var isScrollEnabled
    @Environment(\.iceFormStyle) private var style
    @State private var contentFrame = CGRect.zero

    private let alignment: HorizontalAlignment
    private let padding: EdgeInsets
    private let spacing: CGFloat
    private let content: Content

    init(
        alignment: HorizontalAlignment = .center,
        padding: EdgeInsets,
        spacing: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.padding = padding
        self.spacing = spacing
        self.content = content()
    }

    init(
        alignment: HorizontalAlignment = .center,
        padding: CGFloat = 20,
        spacing: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            alignment: alignment,
            padding: EdgeInsets(top: padding, leading: padding, bottom: padding, trailing: padding),
            spacing: spacing
        ) {
            content()
        }
    }

    var body: some View {
        if isScrollEnabled, style == .settings {
            ScrollView {
                contentStack
            }
            .scrollContentBackground(.hidden)
        } else if isScrollEnabled {
            GeometryReader { geometry in
                if contentFrame.height > geometry.size.height {
                    ScrollView {
                        contentStack
                    }
                    .scrollContentBackground(.hidden)
                } else {
                    contentStack
                }
            }
        } else {
            contentStack
        }
    }

    @ViewBuilder
    private var contentStack: some View {
        VStack(alignment: alignment, spacing: style == .settings ? max(spacing, 16) : spacing) {
            content
                .toggleStyle(IceFormToggleStyle())
        }
        .frame(maxWidth: style == .settings ? 720 : nil)
        .padding(padding)
        .frame(maxWidth: style == .settings ? .infinity : nil, alignment: .top)
        .onFrameChange(update: $contentFrame)
    }
}

private struct IceFormToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        IceLabeledContent {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        } label: {
            configuration.label
        }
    }
}
