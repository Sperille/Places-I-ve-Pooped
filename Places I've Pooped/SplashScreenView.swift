//
//  SplashScreenView.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 7/3/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Places I've Pooped")
                    .font(.largeTitle).bold()
                Text("💩")
                    .font(.system(size: 120))
            }
            .opacity(isActive ? 1 : 0)
            .scaleEffect(isActive ? 1 : 0.8)
            .animation(.easeOut(duration: 1.0), value: isActive)
        }
        .onAppear {
            isActive = true
            // Navigate after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                withAnimation {
                    isActive = false
                }
            }
        }
        .fullScreenCover(isPresented: .constant(!isActive)) {
            LoginView()
        }
    }
}

