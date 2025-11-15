//
//  GymViewModel.swift
//  GymApp
//
//  Created by Bryan Vargas on 14/11/25.
//


import Foundation
import Combine

class GymViewModel: ObservableObject {
    @Published var services: [Service] = []

    func fetchServices() {
        // Temporal: datos dummy
        self.services = [
            Service(name: "Yoga", description: "Clase de yoga", isActive: true),
            Service(name: "CrossFit", description: "Entrenamiento intenso", isActive: false)
        ]
    }
}