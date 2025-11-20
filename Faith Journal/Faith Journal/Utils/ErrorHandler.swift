//
//  ErrorHandler.swift
//  Faith Journal
//
//  User-friendly error handling
//

import Foundation
import SwiftUI
import CloudKit

class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: AppError?
    @Published var showingError = false
    
    private init() {}
    
    func handle(_ error: Error) {
        let appError = AppError.from(error)
        currentError = appError
        showingError = true
    }
    
    func handle(_ appError: AppError) {
        currentError = appError
        showingError = true
    }
    
    func clear() {
        currentError = nil
        showingError = false
    }
}

enum AppError: LocalizedError, Identifiable {
    case saveFailed
    case deleteFailed
    case networkError(String)
    case cloudKitError(String)
    case invalidData
    case permissionDenied
    case notFound
    case unknown(String)
    
    var id: String {
        switch self {
        case .saveFailed: return "save_failed"
        case .deleteFailed: return "delete_failed"
        case .networkError: return "network_error"
        case .cloudKitError: return "cloudkit_error"
        case .invalidData: return "invalid_data"
        case .permissionDenied: return "permission_denied"
        case .notFound: return "not_found"
        case .unknown: return "unknown"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Unable to save your data. Please check your connection and try again."
        case .deleteFailed:
            return "Unable to delete. Please try again."
        case .networkError(let message):
            return "Network error: \(message). Please check your internet connection."
        case .cloudKitError(let message):
            return "Sync error: \(message). Your data is saved locally and will sync when possible."
        case .invalidData:
            return "Invalid data format. Please check your input and try again."
        case .permissionDenied:
            return "Permission denied. Please enable access in Settings."
        case .notFound:
            return "Item not found. It may have been deleted."
        case .unknown(let message):
            return "An unexpected error occurred: \(message). Please try again."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .deleteFailed:
            return "Please ensure you have a stable internet connection and try again."
        case .networkError:
            return "Check your internet connection and try again."
        case .cloudKitError:
            return "Your data is saved locally. It will sync automatically when your connection is restored."
        case .permissionDenied:
            return "Go to Settings > Faith Journal to enable necessary permissions."
        default:
            return "If the problem persists, please contact support."
        }
    }
    
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        let nsError = error as NSError
        let domain = nsError.domain
        let code = nsError.code
        
        switch domain {
        case NSCocoaErrorDomain:
            switch code {
            case 256, 257, 134030: // Save/update errors
                return .saveFailed
            case 4, 5: // Delete errors
                return .deleteFailed
            default:
                return .unknown(error.localizedDescription)
            }
        case NSURLErrorDomain:
            return .networkError(error.localizedDescription)
        case CKErrorDomain:
            return .cloudKitError(error.localizedDescription)
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorHandler: ErrorHandler
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorHandler.showingError, presenting: errorHandler.currentError) { error in
                Button("OK") {
                    errorHandler.clear()
                }
                if error.recoverySuggestion != nil {
                    Button("Learn More") {
                        // Could show a help screen
                    }
                }
            } message: { error in
                Text(error.recoverySuggestion ?? error.errorDescription ?? "An error occurred.")
            }
    }
}

extension View {
    func errorHandling() -> some View {
        modifier(ErrorAlertModifier(errorHandler: ErrorHandler.shared))
    }
}
