//
//  AppError.swift
//  Resona
//
//  Created by Bruce Huang on 2025/12/14.
//

import Foundation

enum AppError: LocalizedError {
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "User is not authenticated"
        }
    }
}
