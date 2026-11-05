//
//  PermissionsView.swift
//  Ice
//

import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var permissionsManager: PermissionsManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerView
                .padding(.bottom, 4)

            IceGroupBox(padding: 0) {
                VStack(spacing: 0) {
                    PermissionRow(
                        permission: permissionsManager.accessibilityPermission,
                        symbol: "accessibility",
                        summary: "Read menu bar information and arrange items.",
                        requestTitle: "Set Up…",
                        onGranted: returnToPermissions
                    )
                    Divider()
                        .padding(.horizontal, 20)
                    PermissionRow(
                        permission: permissionsManager.screenRecordingPermission,
                        symbol: "display",
                        summary: "Display menu bar item images and customize appearance.",
                        requestTitle: "Open Settings…",
                        onGranted: returnToPermissions
                    )
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("You can use basic features without Screen Recording.", systemImage: "info.circle")
                Label("You can change permissions in System Settings at any time.", systemImage: "lock")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            footerView
                .padding(.top, 4)
        }
        .padding(32)
        .frame(width: 620)
        .fixedSize(horizontal: false, vertical: true)
        .background(SettingsPalette.background(for: colorScheme))
        .environment(\.iceFormStyle, .settings)
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            if let nsImage = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Let Ice organize your menu bar")
                    .font(.system(size: 23, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("Enable the required permission to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerView: some View {
        HStack {
            Button("Quit Ice") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)

            Spacer()

            Button("Get Started") {
                guard let appState = permissionsManager.appState else {
                    return
                }
                appState.performSetup()
                appState.permissionsWindow?.close()
                appState.appDelegate?.openSettingsWindow()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(permissionsManager.permissionsState == .missingPermissions)
        }
    }

    private func returnToPermissions() {
        permissionsManager.appState?.activate(withPolicy: .regular)
        openWindow(id: Constants.permissionsWindowID)
    }
}

private struct PermissionRow: View {
    @ObservedObject var permission: Permission
    @State private var isRequesting = false

    let symbol: String
    let summary: LocalizedStringKey
    let requestTitle: LocalizedStringKey
    let onGranted: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(LocalizedStringKey(permission.title))
                        .font(.system(size: 15, weight: .medium))
                    Text(permission.isRequired ? LocalizedStringKey("Required") : LocalizedStringKey("Optional"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if permission.hasPermission {
                    Label {
                        Text("Enabled")
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Button(requestTitle) {
                        isRequesting = true
                        permission.performRequest()
                    }
                    .controlSize(.regular)
                    .accessibilityHint(Text(LocalizedStringKey(permission.title)))
                }
            }
            .frame(minWidth: 100, alignment: .trailing)
        }
        .padding(20)
        .onChange(of: permission.hasPermission) { _, granted in
            if granted && isRequesting {
                isRequesting = false
                onGranted()
            }
        }
        .onDisappear {
            isRequesting = false
        }
    }
}
