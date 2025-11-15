//
//  ContentView.swift
//  GymApp
//
//  Created by Bryan Vargas on 14/11/25.
//


import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = GymViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewModel.services) { service in
                        if service.isActive {
                            ServiceCard(service: service)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Servicios del Gimnasio")
        }
        .onAppear {
            viewModel.fetchServices()
        }
    }
}