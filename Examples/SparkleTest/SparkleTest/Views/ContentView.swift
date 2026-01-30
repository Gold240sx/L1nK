//
//  ContentView.swift
//  SparkleTest
//
//  Created by Michael Martell on 1/30/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        VStack{
            Spacer()
            Text("I said Hey!")
            Text("App Version: \(viewModel.appVersion)")
              
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 300)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
