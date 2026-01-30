//
//  CheckForUpdatesViewModel.swift
//  SparkleTest
//
//  Created by Michael Martell on 1/30/26.
//

import Foundation
import Combine
import Sparkle

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates: Bool = false
    
    // Store the subscription to maintain it for the lifetime of the ViewModel
    private var cancellable: AnyCancellable?
    
    init(updater: SPUUpdater) {
        // Defer all updater access to avoid crashes during initialization
        // The updater may not be fully ready when this ViewModel is created
        DispatchQueue.main.async { [weak self, updater] in
            guard let self = self else { return }
            // Set initial value after a brief delay
            self.canCheckForUpdates = updater.canCheckForUpdates
            
            // Subscribe to changes
            self.cancellable = updater.publisher(for: \.canCheckForUpdates)
                .receive(on: DispatchQueue.main)
                .sink { value in
                    self.canCheckForUpdates = value
                }
        }
    }
}
