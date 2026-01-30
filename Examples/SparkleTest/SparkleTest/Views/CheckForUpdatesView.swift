//
//  CheckForUpdatesView.swift
//  SparkleTest
//
//  Created by Michael Martell on 1/30/26.
//

import SwiftUI
import Sparkle

struct CheckForUpdatesView: View {
    @StateObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    
    init(updater: SPUUpdater) {
        self.updater = updater
        // Use @StateObject with lazy initialization to avoid accessing updater during init
        _viewModel = StateObject(wrappedValue: CheckForUpdatesViewModel(updater: updater))
    }
    
    var body: some View {
        Button("Check For Updates...", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}
