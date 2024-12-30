//
//  ContentView.swift
//  WhatIsMDL
//
//  Created by gzonelee on 12/30/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .onAppear {
            UsdzLoader().loadUSDZAsset(named: "chair_swan")
        }
    }
}

#Preview {
    ContentView()
}
