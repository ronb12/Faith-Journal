//
//  WeatherService.swift
//  Faith Journal
//
//  Service to fetch real weather data based on location
//

import Foundation
import CoreLocation

class WeatherService {
    static let shared = WeatherService()
    
    private init() {}
    
    /// Fetches current weather for a given location
    /// Uses wttr.in - a free weather API that doesn't require an API key
    func fetchWeather(for location: CLLocation, completion: @escaping (Result<String, Error>) -> Void) {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Use wttr.in API - free, no API key required
        // Format: https://wttr.in/latitude,longitude?format=%C+%t
        // %C = condition, %t = temperature
        let urlString = "https://wttr.in/\(latitude),\(longitude)?format=%C+%t"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(WeatherError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent") // Some APIs require a user agent
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data,
                  let weatherString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !weatherString.isEmpty else {
                DispatchQueue.main.async {
                    completion(.failure(WeatherError.noData))
                }
                return
            }
            
            // Clean up the response - wttr.in returns something like "Clear +72°F"
            let cleanedWeather = weatherString
                .replacingOccurrences(of: "+", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            DispatchQueue.main.async {
                completion(.success(cleanedWeather))
            }
        }.resume()
    }
    
    /// Simplified version that returns a formatted weather string
    func getWeatherString(for location: CLLocation, completion: @escaping (String?) -> Void) {
        fetchWeather(for: location) { result in
            switch result {
            case .success(let weather):
                completion(weather)
            case .failure:
                // Fallback to a generic message if fetch fails
                completion(nil)
            }
        }
    }
}

enum WeatherError: Error {
    case invalidURL
    case noData
    case networkError
}

