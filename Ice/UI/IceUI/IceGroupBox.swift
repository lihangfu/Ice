//
//  IceGroupBox.swift
//  Ice
//

import SwiftUI

struct IceGroupBox<Header: View, Content: View, Footer: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.iceFormStyle) private var style

    private let header: Header
    private let content: Content
    private let footer: Footer
    private let padding: CGFloat

    private var backgroundShape: some InsettableShape {
        RoundedRectangle(
            cornerRadius: style == .settings ? 8 : 6,
            style: style == .settings ? .continuous : .circular
        )
    }

    init(
        padding: CGFloat = 10,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.padding = padding
        self.header = header()
        self.content = content()
        self.footer = footer()
    }

    init(
        padding: CGFloat = 10,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) where Header == EmptyView {
        self.init(padding: padding) {
            EmptyView()
        } content: {
            content()
        } footer: {
            footer()
        }
    }

    init(
        padding: CGFloat = 10,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) where Footer == EmptyView {
        self.init(padding: padding) {
            header()
        } content: {
            content()
        } footer: {
            EmptyView()
        }
    }

    init(
        padding: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) where Header == EmptyView, Footer == EmptyView {
        self.init(padding: padding) {
            EmptyView()
        } content: {
            content()
        } footer: {
            EmptyView()
        }
    }

    init(
        _ title: LocalizedStringKey,
        padding: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) where Header == Text, Footer == EmptyView {
        self.init(padding: padding) {
            Text(title)
                .font(.headline)
        } content: {
            content()
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            header
            VStack {
                content
            }
            .padding(padding)
            .background {
                if style == .settings {
                    backgroundShape
                        .fill(SettingsPalette.groupBackground(for: colorScheme))
                        .overlay {
                            backgroundShape.fill(.primary.opacity(colorScheme == .light ? 0 : 0.045))
                        }
                        .overlay {
                            backgroundShape.strokeBorder(
                                Color(nsColor: .separatorColor).opacity(contrast == .increased ? 1 : 0.5),
                                lineWidth: contrast == .increased ? 1 : 0.5
                            )
                        }
                } else {
                    backgroundShape
                        .fill(.quinary.opacity(colorScheme == .light ? 0.5 : 1))
                        .overlay {
                            backgroundShape
                                .strokeBorder(.quaternary)
                        }
                }
            }
            footer
        }
    }
}
