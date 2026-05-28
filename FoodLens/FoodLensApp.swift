//
//  FoodLensApp.swift
//  FoodLens
//

import SwiftUI

@main
struct FoodLensApp: App {
    @StateObject private var store = FoodStore()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environmentObject(store)
                .dismissKeyboardOnTap()
        }
    }
}
