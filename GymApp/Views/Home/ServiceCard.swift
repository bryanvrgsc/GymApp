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
            Rectangle()
                // Use a translucent system background color instead of the Material API
                // to avoid deployment-target / API-availability issues.
                .fill(Color(.systemBackground).opacity(0.65))
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
