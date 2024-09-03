//
//  XCTestCase+Helpers.swift
//  RickAndMortyTests
//
//  Created by Manel Roca on 2/9/24.
//

import XCTest

extension XCTestCase{
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated", file: file, line: line)
        }
    }
}
