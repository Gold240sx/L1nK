//
//  UpdaterDelegate.swift
//  SparkleTest
//
//  Created by Michael Martell on 1/30/26.
//

import Foundation
import Sparkle

/// Delegate to handle automatic update checking on app launch
/// Note: SPUUpdaterDelegate protocol methods are optional in Sparkle 2.
/// This delegate can be extended with optional methods as needed.
class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    // Sparkle 2 delegate methods are optional.
    // If you need to handle update events, implement the appropriate optional methods
    // from the SPUUpdaterDelegate protocol. The deprecated Sparkle 1 methods
    // (updaterDidNotFindUpdate, didFinishUpdateCycleFor) are no longer available.
}
