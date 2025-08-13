//
//  AppRootView.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/4/25.
//

import SwiftUI

struct AppRootView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        Group {
            if auth.isAuthenticated {
                RootContentView()
                    .sheet(isPresented: $auth.requiresDisplayNameCapture) {
                        DisplayNameCaptureView()
                            .environmentObject(auth)
                    }


            } else {
                LoginView()
            }
        }
    }
}
