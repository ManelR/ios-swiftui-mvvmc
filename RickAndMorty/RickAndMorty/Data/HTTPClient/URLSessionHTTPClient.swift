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

    public func get(from url: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await self.session.data(from: url)
        if let response = response as? HTTPURLResponse {
            return (data, response)
        } else {
            throw URLSessionHTTPClientError.unknown
        }
    }
}
