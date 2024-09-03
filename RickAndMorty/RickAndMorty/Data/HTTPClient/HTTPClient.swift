//
//  HTTPClient.swift
//  RickAndMorty
//
//  Created by Manel Roca on 2/9/24.
//

import Foundation

public enum HTTPClientResult {
    case success(Data, HTTPURLResponse)
    case failure(Error)
}

public protocol HTTPClient {
    func get(from url: URL) async throws -> (Data, HTTPURLResponse)
}
