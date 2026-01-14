//
//  ContentView.swift
//  Faith Journal Watch App
//
//  Created on 2025-01-09.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var connectivityManager = WatchConnectivityManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Faith Journal")
                .font(.title3)
                .fontWeight(.bold)

            if connectivityManager.isReachable {
                Text("Connected to iPhone")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("Not connected")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            VStack(spacing: 10) {
                Button(action: {
                    connectivityManager.sendMessage(["action": "open_journal"])
                }) {
                    Text("Open Journal")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    connectivityManager.sendMessage(["action": "add_entry"])
                }) {
                    Text("Add Entry")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    connectivityManager.sendMessage(["action": "view_prayers"])
                }) {
                    Text("Prayers")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Text("Quick Access")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}