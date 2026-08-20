//
//  JarvisApp.swift
//  Jarvis
//
//  Created by Ehron on 03/07/26.
//

import SwiftUI

@main
struct JarvisApp: App {
    @StateObject private var updaterController = OrbitUpdaterController.shared
    @AppStorage(OrbitColorTheme.storageKey) private var selectedThemeRawValue = OrbitColorTheme.matrix.rawValue
    @AppStorage(OrbitColorTheme.darkBackgroundStorageKey) private var isDarkBackgroundEnabled = false

    private var selectedTheme: OrbitColorTheme {
        OrbitColorTheme(rawValue: selectedThemeRawValue) ?? .matrix
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(MatrixTheme.appBackground)
                .preferredColorScheme(selectedTheme.usesLightGlass ? .light : .dark)
                .animation(.easeInOut(duration: 0.24), value: isDarkBackgroundEnabled)
                .windowFullScreenBehavior(.disabled)
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.disabled)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Verificar Atualizações…") {
                    updaterController.checkForUpdates()
                }
            }
        }
    }
}
