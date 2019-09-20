import XCTest

import genieTests

var tests = [XCTestCaseEntry]()
tests += genieTests.allTests()
XCTMain(tests)
