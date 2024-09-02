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

    func test_getFromURL_performsGETRequestsWithURL() {
        let url = self.anyURL()
        let exp = expectation(description: "observe request")

        URLProtocolStub.stub(data: nil, response: nil, error: nil)

        URLProtocolStub.observeRequests { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            exp.fulfill()
        }

        let sut = self.makeSUT()

        sut.get(from: url) { result in }

        wait(for: [exp], timeout: 1.0)
    }

    func test_getFromURL_failsOnRequestError() {
        let error = anyNSError()
        let receivedError = self.resultErrorFor(data: nil, response: nil, error: error)
        XCTAssertEqual(error.code, (receivedError! as NSError).code)
        XCTAssertEqual(error.domain, (receivedError! as NSError).domain)
    }

    func test_getFromURL_failsOnAllInvalidRepresentationCases() {
        XCTAssertNotNil(self.resultErrorFor(data: nil, response: nil, error: nil))
        XCTAssertNotNil(self.resultErrorFor(data: nil, response: nonHTTPResponse(), error: nil))
        XCTAssertNotNil(self.resultErrorFor(data: anyData(), response: nil, error: nil))
        XCTAssertNotNil(self.resultErrorFor(data: anyData(), response: nil, error: anyNSError()))
        XCTAssertNotNil(self.resultErrorFor(data: nil, response: nonHTTPResponse(), error: anyNSError()))
        XCTAssertNotNil(self.resultErrorFor(data: nil, response: anyHTTPResponse(), error: anyNSError()))
        XCTAssertNotNil(self.resultErrorFor(data: anyData(), response: nonHTTPResponse(), error: anyNSError()))
        XCTAssertNotNil(self.resultErrorFor(data: anyData(), response: anyHTTPResponse(), error: anyNSError()))
        XCTAssertNotNil(self.resultErrorFor(data: anyData(), response: nonHTTPResponse(), error: nil))
    }

    func test_getFromURL_withoutData_returnsSuccess() {
        let response = self.anyHTTPResponse()
        let result = self.resultValuesFor(data: nil, response: response)
        XCTAssertEqual(result?.data, Data())
        XCTAssertEqual(result?.response.url, response?.url)
        XCTAssertEqual(result?.response.statusCode, response?.statusCode)
    }

    func test_getFromURL_succedsOnHTTPURLResponseWithData() {
        let data = self.anyData()
        let response = self.anyHTTPResponse()
        let result = self.resultValuesFor(data: data, response: response)
        XCTAssertEqual(data, result?.data)
        XCTAssertEqual(response?.url, result?.response.url)
        XCTAssertEqual(response?.statusCode, result?.response.statusCode)
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> HTTPClient {
        let sut = URLSessionHTTPClient()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private func resultValuesFor(data: Data?, response: URLResponse?, file: StaticString = #filePath, line: UInt = #line) -> (data: Data, response: HTTPURLResponse)? {
        let result = self.resultFor(data: data, response: response, error: nil, file: file, line: line)
        switch result {
        case let .success(receivedData, receivedResponse):
            return (receivedData, receivedResponse)
        default:
            XCTFail("Expected success, got \(String(describing: result))", file: file, line: line)
            return nil
        }
    }

    private func resultErrorFor(data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) -> Error? {
        let result = self.resultFor(data: data, response: response, error: error, file: file, line: line)
        switch result {
        case let .failure(error):
            return error
        default:
            XCTFail("Should send failure case, got \(String(describing: result))", file: file, line: line)
            return nil
        }
    }

    private func resultFor(data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) -> HTTPClientResult? {
        URLProtocolStub.stub(data: data, response: response, error: error)

        var receivedResult: HTTPClientResult?

        let exp = expectation(description: "get method correct")
        makeSUT().get(from: self.anyURL()) { result in
            receivedResult = result
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
        return receivedResult
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
                client?.urlProtocolDidFinishLoading(self)
                return requestObserver(request)
            }

            if let data = URLProtocolStub.stub?.data {
                client?.urlProtocol(self, didLoad: data)
            }

            if let response = URLProtocolStub.stub?.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }

            if let error = URLProtocolStub.stub?.error {
                client?.urlProtocol(self, didFailWithError: error)
            }

            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }
}
