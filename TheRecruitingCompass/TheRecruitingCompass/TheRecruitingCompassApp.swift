//
//  TheRecruitingCompassApp.swift
//  TheRecruitingCompass
//
//  Created by Chris Andrikanich on 2/5/26.
//

import SwiftUI
import Supabase

@main
struct TheRecruitingCompassApp: App {
    @StateObject var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environmentObject(authManager)
    }
}
