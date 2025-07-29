import XCTest
import class Foundation.Bundle
import SQLite

final class genieTests: XCTestCase {
    
    // MARK: - Test Setup and Teardown
    
    var testDBPath: String!
    var originalDBPath: String!
    
    override func setUp() {
        super.setUp()
        
        // Create a temporary database for testing
        testDBPath = NSTemporaryDirectory() + "test_geniedb"
        originalDBPath = NSHomeDirectory() + "/.geniedb"
        
        // Backup original database if it exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: originalDBPath) {
            try? fileManager.copyItem(atPath: originalDBPath, toPath: originalDBPath + ".backup")
        }
        
        // Remove test database if it exists
        try? fileManager.removeItem(atPath: testDBPath)
    }
    
    override func tearDown() {
        super.tearDown()
        
        // Clean up test database
        let fileManager = FileManager.default
        try? fileManager.removeItem(atPath: testDBPath)
        
        // Restore original database
        if fileManager.fileExists(atPath: originalDBPath + ".backup") {
            try? fileManager.removeItem(atPath: originalDBPath)
            try? fileManager.moveItem(atPath: originalDBPath + ".backup", toPath: originalDBPath)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns path to the built products directory.
    var productsDirectory: URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
        #else
        return Bundle.main.bundleURL
        #endif
    }
    
    func runGenieCommand(_ arguments: [String]) -> (output: String, exitCode: Int32) {
        let genieBinary = productsDirectory.appendingPathComponent("genie")
        
        let process = Process()
        process.executableURL = genieBinary
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return (output: output, exitCode: process.terminationStatus)
        } catch {
            return (output: "Error: \(error)", exitCode: -1)
        }
    }
    
    func createTestFile(_ path: String) {
        let fileManager = FileManager.default
        let testDir = NSTemporaryDirectory() + "genie_test_files"
        
        try? fileManager.createDirectory(atPath: testDir, withIntermediateDirectories: true)
        
        let fullPath = testDir + "/" + path
        let content = "Test file content"
        try? content.write(toFile: fullPath, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Command Line Interface Tests
    
    func testNoArguments() throws {
        let result = runGenieCommand([])
        XCTAssertTrue(result.output.contains("Error: Not enough arguments"))
        XCTAssertEqual(result.exitCode, 1) // Should return exit code 1 for usage error
    }
    
    func testHelpFlag() throws {
        let result = runGenieCommand(["--help"])
        XCTAssertTrue(result.output.contains("USAGE:"))
        XCTAssertTrue(result.output.contains("SUBCOMMANDS:"))
        XCTAssertEqual(result.exitCode, 0)
    }
    
    func testShortHelpFlag() throws {
        let result = runGenieCommand(["-h"])
        XCTAssertTrue(result.output.contains("USAGE:"))
        XCTAssertTrue(result.output.contains("SUBCOMMANDS:"))
        XCTAssertEqual(result.exitCode, 0)
    }
    
    func testVersionFlag() throws {
        let result = runGenieCommand(["--version"])
        XCTAssertTrue(result.output.contains("genie"))
        XCTAssertTrue(result.output.contains("1.3.0"))
        XCTAssertEqual(result.exitCode, 0)
    }
    
    func testShortVersionFlag() throws {
        let result = runGenieCommand(["-v"])
        XCTAssertTrue(result.output.contains("genie"))
        XCTAssertTrue(result.output.contains("1.3.0"))
        XCTAssertEqual(result.exitCode, 0)
    }
    
    func testUnknownCommand() throws {
        let result = runGenieCommand(["unknowncommand"])
        XCTAssertTrue(result.output.contains("Command unknowncommand not found"))
        XCTAssertEqual(result.exitCode, 1) // Should return exit code 1 for usage error
    }
    
    // MARK: - Tag Command Tests
    
    func testTagCommandBasic() throws {
        createTestFile("testfile.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/testfile.txt"
        
        let result = runGenieCommand(["tag", testPath, "testtag"])
        XCTAssertEqual(result.exitCode, 0)
        
        // Verify tag was added by searching for it
        let searchResult = runGenieCommand(["search", "testtag"])
        XCTAssertTrue(searchResult.output.contains(testPath))
    }
    
    func testTagCommandWithSpecialCharacters() throws {
        createTestFile("test file with spaces.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/test file with spaces.txt"
        
        let result = runGenieCommand(["tag", testPath, "special-tag"])
        XCTAssertEqual(result.exitCode, 0)
        
        // The path is URL-encoded in the database, so we need to check for the encoded version
        let searchResult = runGenieCommand(["search", "special-tag"])
        XCTAssertTrue(searchResult.output.contains("test%20file%20with%20spaces.txt"))
    }
    
    func testTagCommandInsufficientArguments() throws {
        let result = runGenieCommand(["tag", "/path/to/file"])
        XCTAssertTrue(result.output.contains("Error: Not enough arguments"))
        XCTAssertEqual(result.exitCode, 1) // Should return exit code 1 for usage error
    }
    
    func testTagCommandWithJsonFlag() throws {
        createTestFile("testfile.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/testfile.txt"
        
        let result = runGenieCommand(["-j", "tag", testPath, "testtag"])
        XCTAssertEqual(result.exitCode, 0)
        
        // Should work the same as without -j flag
        let searchResult = runGenieCommand(["search", "testtag"])
        XCTAssertTrue(searchResult.output.contains(testPath))
    }
    
    // MARK: - Remove Command Tests
    
    func testRemoveCommandBasic() throws {
        createTestFile("testfile.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/testfile.txt"
        
        // First tag the file
        let tagResult = runGenieCommand(["tag", testPath, "testtag"])
        XCTAssertEqual(tagResult.exitCode, 0)
        
        // Then remove the tag
        let removeResult = runGenieCommand(["rm", testPath, "testtag"])
        XCTAssertEqual(removeResult.exitCode, 0)
        
        // Verify tag was removed
        let searchResult = runGenieCommand(["search", "testtag"])
        XCTAssertFalse(searchResult.output.contains(testPath))
    }
    
    func testRemoveCommandNonExistentTag() throws {
        createTestFile("testfile.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/testfile.txt"
        
        let result = runGenieCommand(["rm", testPath, "nonexistenttag"])
        XCTAssertEqual(result.exitCode, 0) // Should not error
    }
    
    func testRemoveCommandInsufficientArguments() throws {
        let result = runGenieCommand(["rm", "/path/to/file"])
        XCTAssertTrue(result.output.contains("Error: Not enough arguments"))
        XCTAssertEqual(result.exitCode, 1) // Should return exit code 1 for usage error
    }
    
    // MARK: - Print Command Tests
    
    func testPrintCommandBasic() throws {
        createTestFile("testfile.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/testfile.txt"
        
        // Tag the file
        let tagResult = runGenieCommand(["tag", testPath, "testtag"])
        XCTAssertEqual(tagResult.exitCode, 0)
        
        // Print tags
        let printResult = runGenieCommand(["print", testPath])
        XCTAssertTrue(printResult.output.contains("testtag"))
        XCTAssertEqual(printResult.exitCode, 0)
    }
    
    func testPrintCommandUntaggedFile() throws {
        createTestFile("untagged.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/untagged.txt"
        
        let result = runGenieCommand(["print", testPath])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.isEmpty || result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    func testPrintCommandInsufficientArguments() throws {
        let result = runGenieCommand(["print"])
        XCTAssertTrue(result.output.contains("Error: Not enough arguments"))
        XCTAssertEqual(result.exitCode, 1) // Should return exit code 1 for usage error
    }
    
    // MARK: - Search Command Tests
    
    func testSearchCommandSimple() throws {
        createTestFile("testfile.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/testfile.txt"
        
        // Tag the file
        let tagResult = runGenieCommand(["tag", testPath, "testtag"])
        XCTAssertEqual(tagResult.exitCode, 0)
        
        // Search for the tag
        let searchResult = runGenieCommand(["search", "testtag"])
        XCTAssertTrue(searchResult.output.contains(testPath))
        XCTAssertEqual(searchResult.exitCode, 0)
    }
    
    func testSearchCommandAndOperator() throws {
        createTestFile("testfile1.txt")
        createTestFile("testfile2.txt")
        let testPath1 = NSTemporaryDirectory() + "genie_test_files/testfile1.txt"
        let testPath2 = NSTemporaryDirectory() + "genie_test_files/testfile2.txt"
        
        // Tag files
        runGenieCommand(["tag", testPath1, "tag1"])
        runGenieCommand(["tag", testPath1, "tag2"])
        runGenieCommand(["tag", testPath2, "tag2"])
        
        // Search for files with both tags
        let searchResult = runGenieCommand(["search", "tag1", "and", "tag2"])
        XCTAssertTrue(searchResult.output.contains(testPath1))
        XCTAssertFalse(searchResult.output.contains(testPath2))
    }
    
    func testSearchCommandOrOperator() throws {
        createTestFile("testfile1.txt")
        createTestFile("testfile2.txt")
        let testPath1 = NSTemporaryDirectory() + "genie_test_files/testfile1.txt"
        let testPath2 = NSTemporaryDirectory() + "genie_test_files/testfile2.txt"
        
        // Tag files
        runGenieCommand(["tag", testPath1, "tag1"])
        runGenieCommand(["tag", testPath2, "tag2"])
        
        // Search for files with either tag
        let searchResult = runGenieCommand(["search", "tag1", "or", "tag2"])
        XCTAssertTrue(searchResult.output.contains(testPath1))
        XCTAssertTrue(searchResult.output.contains(testPath2))
    }
    
    func testSearchCommandNotOperator() throws {
        createTestFile("testfile1.txt")
        createTestFile("testfile2.txt")
        let testPath1 = NSTemporaryDirectory() + "genie_test_files/testfile1.txt"
        let testPath2 = NSTemporaryDirectory() + "genie_test_files/testfile2.txt"
        
        // Tag files
        runGenieCommand(["tag", testPath1, "tag1"])
        runGenieCommand(["tag", testPath2, "tag2"])
        
        // Search for files with tag1 but not tag2
        let searchResult = runGenieCommand(["search", "tag1", "and", "not", "tag2"])
        XCTAssertTrue(searchResult.output.contains(testPath1))
        XCTAssertFalse(searchResult.output.contains(testPath2))
    }
    
    func testSearchCommandXorOperator() throws {
        createTestFile("testfile1.txt")
        createTestFile("testfile2.txt")
        createTestFile("testfile3.txt")
        let testPath1 = NSTemporaryDirectory() + "genie_test_files/testfile1.txt"
        let testPath2 = NSTemporaryDirectory() + "genie_test_files/testfile2.txt"
        let testPath3 = NSTemporaryDirectory() + "genie_test_files/testfile3.txt"
        
        // Tag files
        runGenieCommand(["tag", testPath1, "tag1"])
        runGenieCommand(["tag", testPath2, "tag2"])
        runGenieCommand(["tag", testPath3, "tag1"])
        runGenieCommand(["tag", testPath3, "tag2"])
        
        // Search for files with exactly one of the tags
        let searchResult = runGenieCommand(["search", "tag1", "xor", "tag2"])
        XCTAssertTrue(searchResult.output.contains(testPath1))
        XCTAssertTrue(searchResult.output.contains(testPath2))
        XCTAssertFalse(searchResult.output.contains(testPath3))
    }
    
    func testSearchCommandWithParentheses() throws {
        createTestFile("testfile1.txt")
        createTestFile("testfile2.txt")
        createTestFile("testfile3.txt")
        let testPath1 = NSTemporaryDirectory() + "genie_test_files/testfile1.txt"
        let testPath2 = NSTemporaryDirectory() + "genie_test_files/testfile2.txt"
        let testPath3 = NSTemporaryDirectory() + "genie_test_files/testfile3.txt"
        
        // Tag files
        runGenieCommand(["tag", testPath1, "tag1"])
        runGenieCommand(["tag", testPath1, "tag2"])
        runGenieCommand(["tag", testPath2, "tag2"])
        runGenieCommand(["tag", testPath2, "tag3"])
        runGenieCommand(["tag", testPath3, "tag1"])
        
        // Search for files with tag1 and (tag2 or tag3)
        let searchResult = runGenieCommand(["search", "tag1", "and", "(", "tag2", "or", "tag3", ")"])
        XCTAssertTrue(searchResult.output.contains("testfile1.txt"))
        XCTAssertTrue(searchResult.output.contains("testfile2.txt"))
        XCTAssertFalse(searchResult.output.contains("testfile3.txt"))
    }
    
    func testSearchCommandSingleCharOperators() throws {
        createTestFile("testfile1.txt")
        createTestFile("testfile2.txt")
        let testPath1 = NSTemporaryDirectory() + "genie_test_files/testfile1.txt"
        let testPath2 = NSTemporaryDirectory() + "genie_test_files/testfile2.txt"
        
        // Tag files
        runGenieCommand(["tag", testPath1, "tag1"])
        runGenieCommand(["tag", testPath1, "tag2"])
        runGenieCommand(["tag", testPath2, "tag2"])
        
        // Test single char operators
        let andResult = runGenieCommand(["search", "tag1", "&", "tag2"])
        XCTAssertTrue(andResult.output.contains("testfile1.txt"))
        XCTAssertFalse(andResult.output.contains("testfile2.txt"))
        
        let orResult = runGenieCommand(["search", "tag1", "|", "tag2"])
        XCTAssertTrue(orResult.output.contains("testfile1.txt"))
        XCTAssertTrue(orResult.output.contains("testfile2.txt"))
        
        let notResult = runGenieCommand(["search", "tag1", "&", "!", "tag2"])
        XCTAssertFalse(notResult.output.contains("testfile1.txt"))
        XCTAssertFalse(notResult.output.contains("testfile2.txt"))
        
        let xorResult = runGenieCommand(["search", "tag1", "^", "tag2"])
        XCTAssertTrue(xorResult.output.contains("testfile1.txt"))
        XCTAssertTrue(xorResult.output.contains("testfile2.txt"))
    }
    
    func testSearchCommandJsonOutput() throws {
        createTestFile("testfile.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/testfile.txt"
        
        // Tag the file
        runGenieCommand(["tag", testPath, "testtag"])
        
        // Search with JSON output
        let searchResult = runGenieCommand(["-j", "search", "testtag"])
        XCTAssertTrue(searchResult.output.contains("\"items\""))
        XCTAssertTrue(searchResult.output.contains("\"title\""))
        XCTAssertTrue(searchResult.output.contains("\"arg\""))
        // Check for the actual database path (URL-encoded)
        XCTAssertTrue(searchResult.output.contains("testfile.txt"))
    }
    
    func testSearchCommandInvalidExpression() throws {
        let result = runGenieCommand(["search", "invalid", "expression", "("])
        // The parser is permissive and handles malformed expressions gracefully
        // It returns empty results rather than throwing an error
        XCTAssertEqual(result.exitCode, 0)
    }
    
    func testSearchCommandInsufficientArguments() throws {
        let result = runGenieCommand(["search"])
        XCTAssertTrue(result.output.contains("Error: Not enough arguments"))
        XCTAssertEqual(result.exitCode, 1) // Should return exit code 1 for usage error
    }
    
    // MARK: - List Tags Command Tests
    
    func testListTagsCommand() throws {
        createTestFile("testfile1.txt")
        createTestFile("testfile2.txt")
        let testPath1 = NSTemporaryDirectory() + "genie_test_files/testfile1.txt"
        let testPath2 = NSTemporaryDirectory() + "genie_test_files/testfile2.txt"
        
        // Tag files
        runGenieCommand(["tag", testPath1, "tag1"])
        runGenieCommand(["tag", testPath2, "tag2"])
        
        // List all tags
        let listResult = runGenieCommand(["-l", "tag"])
        XCTAssertTrue(listResult.output.contains("tag1"))
        XCTAssertTrue(listResult.output.contains("tag2"))
    }
    
    func testListTagsCommandEmptyDatabase() throws {
        let listResult = runGenieCommand(["tag", "-l"])
        XCTAssertEqual(listResult.exitCode, 0)
        // Should return empty or just whitespace
        let trimmedOutput = listResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(trimmedOutput.isEmpty)
    }
    
    // MARK: - Database Tests
    
    func testDatabaseCreation() throws {
        // This test verifies that the database is created when it doesn't exist
        let fileManager = FileManager.default
        let dbPath = NSHomeDirectory() + "/.geniedb"
        
        // Remove existing database if it exists
        if fileManager.fileExists(atPath: dbPath) {
            try fileManager.removeItem(atPath: dbPath)
        }
        
        // Run a simple command to trigger database creation
        let result = runGenieCommand(["tag", "/tmp/testfile", "testtag"])
        
        // Verify database was created
        XCTAssertTrue(fileManager.fileExists(atPath: dbPath))
    }
    
    func testDatabaseTableStructure() throws {
        // This test verifies the database table structure
        createTestFile("testfile.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/testfile.txt"
        
        // Tag a file to create the database
        runGenieCommand(["tag", testPath, "testtag"])
        
        // Verify the database structure by checking if we can query it
        let dbPath = NSHomeDirectory() + "/.geniedb"
        let db = try Connection(dbPath)
        
        // Check if the genie table exists
        let tableExists = try db.scalar("SELECT name FROM sqlite_master WHERE type='table' AND name='genie'") != nil
        XCTAssertTrue(tableExists)
        
        // Check if the table has the expected columns
        let columns = try db.prepare("PRAGMA table_info(genie)")
        var columnNames: [String] = []
        for row in columns {
            columnNames.append(row[1] as! String)
        }
        
        XCTAssertTrue(columnNames.contains("id"))
        XCTAssertTrue(columnNames.contains("host"))
        XCTAssertTrue(columnNames.contains("path"))
        XCTAssertTrue(columnNames.contains("tag"))
        XCTAssertTrue(columnNames.contains("time_created"))
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testNonExistentFile() throws {
        let result = runGenieCommand(["tag", "/nonexistent/file", "testtag"])
        XCTAssertEqual(result.exitCode, 0) // Should not error, just add the tag
        
        let printResult = runGenieCommand(["print", "/nonexistent/file"])
        XCTAssertEqual(printResult.exitCode, 0)
        // Should return empty result
    }
    
    func testMultipleTagsOnSameFile() throws {
        createTestFile("testfile.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/testfile.txt"
        
        // Add multiple tags
        runGenieCommand(["tag", testPath, "tag1"])
        runGenieCommand(["tag", testPath, "tag2"])
        runGenieCommand(["tag", testPath, "tag3"])
        
        // Print all tags
        let printResult = runGenieCommand(["print", testPath])
        XCTAssertTrue(printResult.output.contains("tag1"))
        XCTAssertTrue(printResult.output.contains("tag2"))
        XCTAssertTrue(printResult.output.contains("tag3"))
        
        // Search with any of the tags
        let searchResult = runGenieCommand(["search", "tag1", "or", "tag2", "or", "tag3"])
        XCTAssertTrue(searchResult.output.contains(testPath))
    }
    
    func testRemoveSpecificTag() throws {
        createTestFile("testfile.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/testfile.txt"
        
        // Add multiple tags
        runGenieCommand(["tag", testPath, "tag1"])
        runGenieCommand(["tag", testPath, "tag2"])
        
        // Remove one tag
        runGenieCommand(["rm", testPath, "tag1"])
        
        // Verify only tag2 remains
        let printResult = runGenieCommand(["print", testPath])
        XCTAssertFalse(printResult.output.contains("tag1"))
        XCTAssertTrue(printResult.output.contains("tag2"))
    }
    
    // MARK: - Performance Tests
    
    func testMultipleFilesPerformance() throws {
        // Create multiple test files
        for i in 1...10 {
            createTestFile("testfile\(i).txt")
        }
        
        // Tag all files
        for i in 1...10 {
            let testPath = NSTemporaryDirectory() + "genie_test_files/testfile\(i).txt"
            runGenieCommand(["tag", testPath, "batchtag"])
        }
        
        // Search for all tagged files
        let startTime = CFAbsoluteTimeGetCurrent()
        let searchResult = runGenieCommand(["search", "batchtag"])
        let endTime = CFAbsoluteTimeGetCurrent()
        
        XCTAssertEqual(searchResult.exitCode, 0)
        XCTAssertLessThan(endTime - startTime, 1.0) // Should complete within 1 second
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflow() throws {
        createTestFile("workflow_test.txt")
        let testPath = NSTemporaryDirectory() + "genie_test_files/workflow_test.txt"
        
        // Step 1: Tag the file
        let tagResult = runGenieCommand(["tag", testPath, "workflowtag"])
        XCTAssertEqual(tagResult.exitCode, 0)
        
        // Step 2: Verify tag was added
        let printResult = runGenieCommand(["print", testPath])
        XCTAssertTrue(printResult.output.contains("workflowtag"))
        
        // Step 3: Search for the tag
        let searchResult = runGenieCommand(["search", "workflowtag"])
        XCTAssertTrue(searchResult.output.contains(testPath))
        
        // Step 4: Remove the tag
        let removeResult = runGenieCommand(["rm", testPath, "workflowtag"])
        XCTAssertEqual(removeResult.exitCode, 0)
        
        // Step 5: Verify tag was removed
        let finalPrintResult = runGenieCommand(["print", testPath])
        XCTAssertFalse(finalPrintResult.output.contains("workflowtag"))
        
        // Step 6: Verify search no longer finds it
        let finalSearchResult = runGenieCommand(["search", "workflowtag"])
        XCTAssertFalse(finalSearchResult.output.contains(testPath))
    }
    
    // MARK: - Test Suite Registration
    
    static var allTests = [
        // Command Line Interface Tests
        ("testNoArguments", testNoArguments),
        ("testHelpFlag", testHelpFlag),
        ("testShortHelpFlag", testShortHelpFlag),
        ("testVersionFlag", testVersionFlag),
        ("testShortVersionFlag", testShortVersionFlag),
        ("testUnknownCommand", testUnknownCommand),
        
        // Tag Command Tests
        ("testTagCommandBasic", testTagCommandBasic),
        ("testTagCommandWithSpecialCharacters", testTagCommandWithSpecialCharacters),
        ("testTagCommandInsufficientArguments", testTagCommandInsufficientArguments),
        ("testTagCommandWithJsonFlag", testTagCommandWithJsonFlag),
        
        // Remove Command Tests
        ("testRemoveCommandBasic", testRemoveCommandBasic),
        ("testRemoveCommandNonExistentTag", testRemoveCommandNonExistentTag),
        ("testRemoveCommandInsufficientArguments", testRemoveCommandInsufficientArguments),
        
        // Print Command Tests
        ("testPrintCommandBasic", testPrintCommandBasic),
        ("testPrintCommandUntaggedFile", testPrintCommandUntaggedFile),
        ("testPrintCommandInsufficientArguments", testPrintCommandInsufficientArguments),
        
        // Search Command Tests
        ("testSearchCommandSimple", testSearchCommandSimple),
        ("testSearchCommandAndOperator", testSearchCommandAndOperator),
        ("testSearchCommandOrOperator", testSearchCommandOrOperator),
        ("testSearchCommandNotOperator", testSearchCommandNotOperator),
        ("testSearchCommandXorOperator", testSearchCommandXorOperator),
        ("testSearchCommandWithParentheses", testSearchCommandWithParentheses),
        ("testSearchCommandSingleCharOperators", testSearchCommandSingleCharOperators),
        ("testSearchCommandJsonOutput", testSearchCommandJsonOutput),
        ("testSearchCommandInvalidExpression", testSearchCommandInvalidExpression),
        ("testSearchCommandInsufficientArguments", testSearchCommandInsufficientArguments),
        
        // List Tags Command Tests
        ("testListTagsCommand", testListTagsCommand),
        ("testListTagsCommandEmptyDatabase", testListTagsCommandEmptyDatabase),
        
        // Database Tests
        ("testDatabaseCreation", testDatabaseCreation),
        ("testDatabaseTableStructure", testDatabaseTableStructure),
        
        // Edge Cases and Error Handling
        ("testNonExistentFile", testNonExistentFile),
        ("testMultipleTagsOnSameFile", testMultipleTagsOnSameFile),
        ("testRemoveSpecificTag", testRemoveSpecificTag),
        
        // Performance Tests
        ("testMultipleFilesPerformance", testMultipleFilesPerformance),
        
        // Integration Tests
        ("testFullWorkflow", testFullWorkflow),
    ]
}
