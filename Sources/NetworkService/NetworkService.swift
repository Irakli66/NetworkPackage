import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

public protocol NetworkServiceProtocol {
    func request<T: Decodable>(
        urlString: String,
        method: HTTPMethod,
        headers: [String: String]?,
        body: Data?,
        decoder: JSONDecoder
    ) async throws -> T
}

public enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case noData
    case requestError(Error)
}

@available(macOS 12.0, iOS 16.0, *)
public final class NetworkService: NetworkServiceProtocol {
    public init() {}
    
    public func request<T: Decodable>(
        urlString: String,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        body: Data? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        
        if let headers = headers {
            headers.forEach { key, value in
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let body = body,
           [.post, .put, .patch].contains(method) {
            urlRequest.httpBody = body
            
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
            
            do {
                let responseData = try decoder.decode(T.self, from: data)
                return responseData
            } catch {
                throw NetworkError.decodingError(error)
            }
        } catch {
            throw NetworkError.requestError(error)
        }
    }
}
