//
//  HTTPClientTests.swift
//  RickAndMortyTests
//
//  Created by Manel Roca on 2/9/24.
//

import XCTest
import RickAndMorty

final class URLSessionHTTPClientTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLProtocolStub.startInterceptiongRequests()
    }

    override func tearDown() {
        super.tearDown()
        URLProtocolStub.stopInterceptingRequests()
    }

    func test_getFromURL_performsGETRequestsWithURL() async {
        let url = self.anyURL()

        URLProtocolStub.stub(data: nil, response: nil, error: nil)

        URLProtocolStub.observeRequests { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
        }

        let sut = self.makeSUT()
        do{
            _ = try await sut.get(from: url)
        } catch {
            XCTFail(error.localizedDescription)
        }

    }

    func test_getFromURL_failsOnRequestError() async {
        let error = anyNSError()
        let receivedError = await self.resultErrorFor(data: nil, response: nil, error: error)
        XCTAssertEqual(error.code, (receivedError! as NSError).code)
        XCTAssertEqual(error.domain, (receivedError! as NSError).domain)
    }

    func test_getFromURL_failsOnAllInvalidRepresentationCases() async {
        var error = await self.resultErrorFor(data: nil, response: nil, error: nil)
        XCTAssertNotNil(error)
        error = await self.resultErrorFor(data: nil, response: nonHTTPResponse(), error: nil)
        XCTAssertNotNil(error)
        error = await self.resultErrorFor(data: anyData(), response: nil, error: anyNSError())
        XCTAssertNotNil(error)
        error = await self.resultErrorFor(data: nil, response: nonHTTPResponse(), error: anyNSError())
        XCTAssertNotNil(error)
        error = await self.resultErrorFor(data: nil, response: anyHTTPResponse(), error: anyNSError())
        XCTAssertNotNil(error)
        error = await self.resultErrorFor(data: anyData(), response: nonHTTPResponse(), error: anyNSError())
        XCTAssertNotNil(error)
        error = await self.resultErrorFor(data: anyData(), response: anyHTTPResponse(), error: anyNSError())
        XCTAssertNotNil(error)
        error = await self.resultErrorFor(data: anyData(), response: nonHTTPResponse(), error: nil)
        XCTAssertNotNil(error)
    }

    func test_getFromURL_withoutData_returnsSuccess() async throws {
        let response = self.anyHTTPResponse()
        let result = try await self.resultFor(data: nil, response: response, error: nil)
        XCTAssertEqual(result.data, Data())
        XCTAssertEqual(result.response.url, response?.url)
        XCTAssertEqual(result.response.statusCode, response?.statusCode)
    }

    func test_getFromURL_succedsOnHTTPURLResponseWithData() async throws {
        let data = self.anyData()
        let response = self.anyHTTPResponse()
        let result = try await self.resultFor(data: data, response: response, error: nil)
        XCTAssertEqual(data, result.data)
        XCTAssertEqual(response?.url, result.response.url)
        XCTAssertEqual(response?.statusCode, result.response.statusCode)
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> HTTPClient {
        let sut = URLSessionHTTPClient()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private func resultErrorFor(data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) async -> Error? {
        do {
            let result = try await self.resultFor(data: data, response: response, error: error)
            XCTFail("Should send failure case, got \(String(describing: result))", file: file, line: line)
        } catch let receivedError {
            return receivedError
        }
        return nil
    }

    private func resultFor(data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) async throws -> (data: Data, response: HTTPURLResponse) {
        URLProtocolStub.stub(data: data, response: response, error: error)

        return try await makeSUT().get(from: self.anyURL())
    }

    private func anyURL() -> URL {
        return URL(string: "https://mroca.me")!
    }

    private func anyData() -> Data {
        return Data("any data".utf8)
    }

    private func anyNSError() -> NSError {
        return NSError(domain: "any error", code: 1)
    }

    private func anyHTTPResponse() -> HTTPURLResponse? {
        return HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)
    }

    private func nonHTTPResponse() -> URLResponse {
        return URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }

    private class URLProtocolStub: URLProtocol {
        private static var stub: Stub?
        private static var requestObserver: ((URLRequest) -> Void)?

        private struct Stub {
            let data: Data?
            let response: URLResponse?
            let error: Error?
        }

        static func stub(data: Data?, response: URLResponse?, error: Error?) {
            stub = Stub(data: data, response: response, error: error)
        }

        static func observeRequests(observer: @escaping (URLRequest) -> Void) {
            requestObserver = observer
        }

        static func startInterceptiongRequests() {
            URLProtocol.registerClass(URLProtocolStub.self)
        }

        static func stopInterceptingRequests() {
            URLProtocol.unregisterClass(URLProtocolStub.self)
            stub = nil
            requestObserver = nil
        }

        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }

        override func startLoading() {
            if let requestObserver = URLProtocolStub.requestObserver {
                client?.urlProtocol(self, didReceive: HTTPURLResponse(), cacheStoragePolicy: .allowed)
                client?.urlProtocolDidFinishLoading(self)
                return requestObserver(request)
            }
            var filled = false

            if let data = URLProtocolStub.stub?.data {
                filled = true
                client?.urlProtocol(self, didLoad: data)
            }

            if let response = URLProtocolStub.stub?.response {
                filled = true
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }

            if let error = URLProtocolStub.stub?.error {
                filled = true
                client?.urlProtocol(self, didFailWithError: error)
            }

            if !filled {
                // Async version crashes without response
                client?.urlProtocol(self, didFailWithError: NSError(domain: "", code: 1))
            }

            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }
}
