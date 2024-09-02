//
//  URLSessionHTTPClient.swift
//  RickAndMorty
//
//  Created by Manel Roca on 2/9/24.
//

import Foundation

public enum URLSessionHTTPClientError: Error {
    case unknown
}

public class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
        self.session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
            } else if let data = data, let response = response as? HTTPURLResponse {
                completion(.success(data, response))
            } else {
                completion(.failure(URLSessionHTTPClientError.unknown))
            }
        }.resume()
    }
}
