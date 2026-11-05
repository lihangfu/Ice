//
//  AboutSettingsPane.swift
//  Ice
//

import SwiftUI

struct AboutSettingsPane: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale

    private var updatesManager: UpdatesManager {
        appState.updatesManager
    }

    private var acknowledgementsURL: URL {
        // swiftlint:disable:next force_unwrapping
        Bundle.main.url(forResource: "Acknowledgements", withExtension: "pdf")!
    }

    private var contributeURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://github.com/lihangfu/Ice")!
    }

    private var issuesURL: URL {
        contributeURL.appendingPathComponent("issues")
    }

    private var lastUpdateCheckString: String {
        if let date = updatesManager.lastUpdateCheckDate {
            date.formatted(Date.FormatStyle(date: .abbreviated, time: .standard).locale(locale))
        } else {
            AppLanguage.current.localizedString("Never")
        }
    }

    var body: some View {
        IceForm {
            appIconAndCopyrightSection
            updatesSection
            bottomBar
        }
    }

    @ViewBuilder
    private var appIconAndCopyrightSection: some View {
        IceGroupBox(padding: 24) {
            VStack(spacing: 8) {
                if let nsImage = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .accessibilityHidden(true)
                }
                Text("Ice")
                    .font(.largeTitle.bold())
                Text("Version \(Constants.versionString)")
                    .foregroundStyle(.secondary)
                Text(Constants.copyrightString)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var updatesSection: some View {
        IceSection {
            automaticallyCheckForUpdates
            automaticallyDownloadUpdates
            if updatesManager.canCheckForUpdates {
                checkForUpdates
            }
        }
        .disabled(Constants.isLocalBuild)
        .annotation {
            if Constants.isLocalBuild {
                Text("Updates are disabled in local builds.")
            }
        }
    }

    @ViewBuilder
    private var automaticallyCheckForUpdates: some View {
        Toggle(
            "Automatically check for updates",
            isOn: updatesManager.bindings.automaticallyChecksForUpdates
        )
    }

    @ViewBuilder
    private var automaticallyDownloadUpdates: some View {
        Toggle(
            "Automatically download updates",
            isOn: updatesManager.bindings.automaticallyDownloadsUpdates
        )
    }

    @ViewBuilder
    private var checkForUpdates: some View {
        HStack {
            Button("Check for Updates") {
                updatesManager.checkForUpdates()
            }
            Spacer()
            Text("Last checked: \(lastUpdateCheckString)")
                .font(.caption)
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        IceSection {
            HStack {
                Button("Acknowledgements") {
                    NSWorkspace.shared.open(acknowledgementsURL)
                }
                Spacer()
                Button("Contribute") {
                    openURL(contributeURL)
                }
                Button("Report a Bug") {
                    openURL(issuesURL)
                }
            }
            .buttonStyle(.link)
            HStack {
                Spacer()
                Button("Quit Ice") {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
