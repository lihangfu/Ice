//
//  SettingsWindowChrome.swift
//  Ice
//

import Combine
import SwiftUI

private struct SettingsTitlebarHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var settingsTitlebarHeight: CGFloat {
        get { self[SettingsTitlebarHeightKey.self] }
        set { self[SettingsTitlebarHeightKey.self] = newValue }
    }
}

struct SettingsWindowChrome: NSViewRepresentable {
    final class WindowProbe: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }

    final class Coordinator {
        var height: Binding<CGFloat>
        private weak var window: NSWindow?
        private var originalStyle: (transparent: Bool, separator: NSTitlebarSeparatorStyle)?
        private var observation: AnyCancellable?

        init(height: Binding<CGFloat>) {
            self.height = height
        }

        func attach(to newWindow: NSWindow?) {
            guard let newWindow else {
                detach()
                return
            }
            guard window !== newWindow else { return }
            detach()
            window = newWindow
            originalStyle = (newWindow.titlebarAppearsTransparent, newWindow.titlebarSeparatorStyle)
            // Only the detail overlay owns scroll material; the native window stays transparent.
            newWindow.titlebarAppearsTransparent = true
            newWindow.titlebarSeparatorStyle = .none
            // Window attachment can occur during a SwiftUI update, before state may be written.
            observation = newWindow.publisher(for: \.contentLayoutRect)
                .receive(on: RunLoop.main)
                .sink { [weak self, weak newWindow] rect in
                    guard let self, let newWindow, window === newWindow else { return }
                    height.wrappedValue = max(0, newWindow.frame.height - rect.maxY)
                }
        }

        func detach() {
            observation?.cancel()
            observation = nil
            if let window, let originalStyle {
                window.titlebarAppearsTransparent = originalStyle.transparent
                window.titlebarSeparatorStyle = originalStyle.separator
            }
            window = nil
            originalStyle = nil
        }
    }

    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    func makeNSView(context: Context) -> WindowProbe {
        let view = WindowProbe()
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateNSView(_ view: WindowProbe, context: Context) {
        context.coordinator.height = $height
        context.coordinator.attach(to: view.window)
    }

    static func dismantleNSView(_ view: WindowProbe, coordinator: Coordinator) {
        view.onWindowChange = nil
        coordinator.detach()
    }
}
