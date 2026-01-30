//
//  ContentViewModel.swift
//  SparkleTest
//
//  Created by Michael Martell on 1/30/26.
//

import Foundation
import Combine

final class ContentViewModel: ObservableObject {
    @Published var appVersion: String
    
    init() {
        self.appVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
