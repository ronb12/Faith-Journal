//
//  AgoraTokenService.swift
//  Faith Journal
//
//  Token server integration for Agora RTC
//  Fetches tokens from your backend server for secure channel access
//

import Foundation

/// Service for fetching Agora tokens from a token server
@MainActor
@available(iOS 17.0, *)
class AgoraTokenService {
    static let shared = AgoraTokenService()
    
    // MARK: - Configuration
    
    /// Token server base URL
    /// Configure this to point to your token server endpoint
    /// Example: "https://your-server.com/api/agora/token"
    /// For local testing: "http://localhost:8080/api/agora/token"
    private var tokenServerURL: String {
        // Try environment variable first (for different environments)
        if let envURL = ProcessInfo.processInfo.environment["AGORA_TOKEN_SERVER_URL"], !envURL.isEmpty {
            return envURL
        }
        
        // Use different URLs for Debug vs Release builds
        #if DEBUG
        // Development: Use Vercel server (works from anywhere, including simulator)
        // You can override with AGORA_TOKEN_SERVER_URL environment variable for local testing
        return "https://token-server-eight.vercel.app/api/agora/token"
        #else
        // Production: use Vercel serverless function
        // Free tier: 100GB bandwidth/month, 100 serverless function invocations/second
        // More than enough for token generation!
        // Using actual production URL: token-server-eight.vercel.app
        return "https://token-server-eight.vercel.app/api/agora/token"
        #endif
    }
    
    // MARK: - Token Request Model
    
    struct TokenRequest: Codable {
        let channelName: String
        let uid: UInt
        let role: String // "publisher" or "subscriber"
    }
    
    struct TokenResponse: Codable {
        let token: String
        let expiresIn: Int? // Token expiration time in seconds
    }
    
    // MARK: - Token Cache
    
    private struct CachedToken {
        let token: String
        let expiresAt: Date
        let channelName: String
        let uid: UInt
    }
    
    private var tokenCache: CachedToken?
    
    // MARK: - Public Methods
    
    /// Fetch a token from the token server
    /// - Parameters:
    ///   - channelName: The Agora channel name
    ///   - uid: User ID (0 for auto-assigned)
    ///   - role: User role ("publisher" for broadcaster, "subscriber" for audience)
    /// - Returns: The token string
    /// - Throws: Error if token fetch fails
    func fetchToken(channelName: String, uid: UInt = 0, role: String = "publisher") async throws -> String {
        // Check cache first
        if let cached = tokenCache,
           cached.channelName == channelName,
           cached.uid == uid,
           cached.expiresAt > Date().addingTimeInterval(60) { // Refresh if expires in < 1 minute
            print("✅ [TOKEN] Using cached token (expires in \(Int(cached.expiresAt.timeIntervalSinceNow))s)")
            return cached.token
        }
        
        // Build request URL
        guard let baseURL = URL(string: tokenServerURL) else {
            throw AgoraTokenError.invalidServerURL
        }
        
        // Create request body
        let requestBody = TokenRequest(
            channelName: channelName,
            uid: uid,
            role: role
        )
        
        // Create URL request
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add authentication header if needed (e.g., API key)
        if let apiKey = ProcessInfo.processInfo.environment["AGORA_TOKEN_SERVER_API_KEY"], !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Encode request body
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AgoraTokenError.encodingError(error)
        }
        
        print("📡 [TOKEN] Fetching token from server: \(tokenServerURL)")
        print("📡 [TOKEN] Channel: \(channelName), UID: \(uid), Role: \(role)")
        
        // Perform request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AgoraTokenError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [TOKEN] Server error: \(httpResponse.statusCode) - \(errorMessage)")
                throw AgoraTokenError.serverError(httpResponse.statusCode, errorMessage)
            }
            
            // Decode response
            let tokenResponse: TokenResponse
            do {
                tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            } catch {
                // Try parsing as plain string if JSON decode fails
                if let tokenString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !tokenString.isEmpty {
                    tokenResponse = TokenResponse(token: tokenString, expiresIn: 3600) // Default 1 hour
                } else {
                    throw AgoraTokenError.decodingError(error)
                }
            }
            
            // Cache the token
            let expiresIn = tokenResponse.expiresIn ?? 3600 // Default 1 hour
            tokenCache = CachedToken(
                token: tokenResponse.token,
                expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
                channelName: channelName,
                uid: uid
            )
            
            print("✅ [TOKEN] Token fetched successfully (expires in \(expiresIn)s)")
            return tokenResponse.token
            
        } catch let error as AgoraTokenError {
            throw error
        } catch {
            print("❌ [TOKEN] Network error: \(error.localizedDescription)")
            throw AgoraTokenError.networkError(error)
        }
    }
    
    /// Clear the token cache (useful for testing or when switching users)
    func clearCache() {
        tokenCache = nil
        print("🗑️ [TOKEN] Cache cleared")
    }
    
    /// Check if a cached token is still valid
    func hasValidCachedToken(for channelName: String, uid: UInt) -> Bool {
        guard let cached = tokenCache else { return false }
        return cached.channelName == channelName &&
               cached.uid == uid &&
               cached.expiresAt > Date().addingTimeInterval(60) // Valid if expires in > 1 minute
    }
}

// MARK: - Token Errors

enum AgoraTokenError: LocalizedError {
    case invalidServerURL
    case encodingError(Error)
    case decodingError(Error)
    case networkError(Error)
    case invalidResponse
    case serverError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Invalid token server URL. Please configure AGORA_TOKEN_SERVER_URL."
        case .encodingError(let error):
            return "Failed to encode token request: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode token response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from token server"
        case .serverError(let code, let message):
            return "Token server error (\(code)): \(message)"
        }
    }
}
