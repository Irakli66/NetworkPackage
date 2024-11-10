import Foundation

public enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case noData
}

public final class NetworkService {
    
    public init() {}
    
    public func fetchData<T: Decodable>(
        urlString: String,
        httpMethod: String = "GET",
        headers: [String: String]? = nil,
        decoder: JSONDecoder = JSONDecoder(),
        completion: @escaping @Sendable (Result<T, NetworkError>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = httpMethod
        if let headers = headers {
            headers.forEach { key, value in
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print(error)
                completion(.failure(.decodingError(error)))
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            guard (200...299).contains(response.statusCode) else {
                completion(.failure(.httpError(statusCode: response.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let responseData = try decoder.decode(T.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(responseData))
                }
            } catch {
                print(error.localizedDescription)
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }
}
