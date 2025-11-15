//
//  Service.swift
//  GymApp
//
//  Created by Bryan Vargas on 14/11/25.
//


import Foundation

struct Service: Identifiable {
    let id: UUID = UUID()
    let name: String
    let description: String
    let isActive: Bool
}