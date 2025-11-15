//
//  User.swift
//  GymApp
//
//  Created by Bryan Vargas on 14/11/25.
//


import Foundation

struct User {
    let id: String
    let name: String
    let membershipExp: Date?
    
    var isActive: Bool {
        if let exp = membershipExp {
            return exp > Date()
        }
        return false
    }
}
