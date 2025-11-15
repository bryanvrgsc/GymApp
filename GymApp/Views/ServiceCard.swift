//
//  ServiceCard.swift
//  GymApp
//
//  Created by Bryan Vargas on 14/11/25.
//


import SwiftUI

struct ServiceCard: View {
    let service: Service

    var body: some View {
        ZStack {
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                .cornerRadius(20)
                .shadow(radius: 5)
            VStack(alignment: .leading) {
                Text(service.name)
                    .font(.headline)
                Text(service.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(height: 120)
    }
}