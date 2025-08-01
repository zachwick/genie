/**
* genie - filesystem tagger
*
* Copyright 2017, 2018, 2019, 2020, 2025 zachwick <zach@zachwick.com>
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
**/

import SQLite
import Foundation
import argtree

let dbPath = ".geniedb"
let databaseFilePath = "\(NSHomeDirectory())/\(dbPath)"
let genieVersion = "1.3.0"
let commandName = (CommandLine.arguments[0] as NSString).lastPathComponent
var database: Connection?
var jsonOutput = false
var tagList = false
var customDbPath: String?
var processedArgs: [String] = []

// Exit codes
let exitSuccess: Int32 = 0
let exitUsageError: Int32 = 1
let exitDatabaseError: Int32 = 2
let exitInvalidExpression: Int32 = 3

func getDatabasePath() -> String {
    return customDbPath ?? databaseFilePath
}

func printUsage() {
    let usageString =
        """
        \(commandName) \(genieVersion)
        zach wick
        filesystem tagger

        USAGE:
            genie [SUBCOMMAND]

        FLAGS:
            -h, --help       Prints help information
            -v, --version    Prints version information
            -j, --json       Gives output as json string for use in Alfred (only used by the 'search' subcommand)
            -l, --list       Prints out a listing of all tags used in genie (only used by the 'tag' subcommand)
            --db PATH        Specify a custom database file path (useful for testing)

        EXAMPLES:
            genie search "tag1 and not tag2"     # Files with tag1 but not tag2
            genie search "tag1 & !tag2"          # Same as above using single char operators
            genie search "tag1 and (tag2 or tag3)" # Files with tag1 and either tag2 or tag3
            genie search "tag1 & (tag2 | tag3)"  # Same as above using single char operators
            genie search "tag1 xor tag2"         # Files with exactly one of tag1 or tag2
            genie search "tag1 ^ tag2"           # Same as above using single char operators
            genie tag "*.py" python              # Tag all Python files in current directory
            genie tag "src/**/*.ts" typescript   # Tag all TypeScript files recursively in src/
            genie rm "*.log" debug               # Remove debug tag from all log files

        OPERATORS:
            AND: "and" or "&"
            OR:  "or"  or "|"
            NOT: "not" or "!"
            XOR: "xor" or "^"

        GLOB PATTERNS:
            *               Matches any sequence of characters
            ?               Matches any single character
            **              Matches directories recursively (double splat)

        SUBCOMMANDS:
            help       Prints this help message
            rm         remove from the given PATH the given TAG (supports glob patterns)
            search (s) search for and return all PATHS using boolean expressions (e.g., "tag1 and not tag2", "tag1 and (tag2 or tag3)")
            print  (p) show all tags applied to the given PATH
            tag    (t) tag the given PATH with the given TAG (supports glob patterns)
        """
    print(usageString)
}

func unknownCommand() {
    print("Command \(processedArgs[1]) not found.")
    printUsage()
    Foundation.exit(exitUsageError)
}

func checkDB() -> Bool {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: getDatabasePath()) {
        // Open existing database and check if the genie table exists
        do {
            database = try Connection(getDatabasePath())

            // Check if the genie table exists
            guard let dbase = database else {
                print("Error: Database connection failed")
                return false
            }
            let tableExists = try dbase.scalar("SELECT name FROM sqlite_master WHERE type='table' AND name='genie'") != nil

            if !tableExists {
                // Create the genie table if it doesn't exist
                let genieTable = Table("genie")
                let id = Expression<Int64>("id")
                let host = Expression<String>("host")
                let path = Expression<String?>("path")
                let tag = Expression<String>("tag")
                let timeCreated = Expression<String>("time_created")

                try dbase.run(genieTable.create { table in
                    table.column(id, primaryKey: true)
                    table.column(host)
                    table.column(path)
                    table.column(tag)
                    table.column(timeCreated)
                })
            }
            return true
        } catch {
            print("Error: Unable to open existing database at \(getDatabasePath()): \(error)")
            return false
        }
    } else {
        // Create the SQLite db and structure it correctly
        do {
            database = try Connection(getDatabasePath())
            guard let dbase = database else {
                print("Error: Database connection failed")
                return false
            }
            let genieTable = Table("genie")
            let id = Expression<Int64>("id")
            let host = Expression<String>("host")
            let path = Expression<String?>("path")
            let tag = Expression<String>("tag")
            let timeCreated = Expression<String>("time_created")

            try dbase.run(genieTable.create { table in
                table.column(id, primaryKey: true)
                table.column(host)
                table.column(path)
                table.column(tag)
                table.column(timeCreated)
            })
            return true
        } catch {
            print("Error: Unable to create database at \(getDatabasePath()): \(error)")
            return false
        }
    }
}

func expandGlobPattern(_ pattern: String) -> [String] {
    let fileManager = FileManager.default
    let currentDirectory = fileManager.currentDirectoryPath

    // Convert glob pattern to a regular expression
    var regexPattern = pattern
        .replacingOccurrences(of: ".", with: "\\.")
        .replacingOccurrences(of: "*", with: ".*")
        .replacingOccurrences(of: "?", with: ".")

    // Handle ** (double splat) for recursive directory matching
    regexPattern = regexPattern.replacingOccurrences(of: "\\*\\*", with: ".*")

    // Add start and end anchors
    regexPattern = "^" + regexPattern + "$"

    guard let regex = try? NSRegularExpression(pattern: regexPattern) else {
        return []
    }

    var matchingPaths: [String] = []

    func enumerateFiles(at path: String, isRecursive: Bool = false) {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for item in contents {
                let fullPath = (path as NSString).appendingPathComponent(item)
                let relativePath = (fullPath as NSString).replacingOccurrences(of: currentDirectory + "/", with: "")

                // Check if this path matches our pattern
                let range = NSRange(location: 0, length: relativePath.count)
                if regex.firstMatch(in: relativePath, range: range) != nil {
                    matchingPaths.append(relativePath)
                }

                // If we're doing recursive search and this is a directory, recurse
                if isRecursive {
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                        enumerateFiles(at: fullPath, isRecursive: true)
                    }
                }
            }
        } catch {
            // Silently ignore errors for individual directories
        }
    }

    // Check if pattern contains ** for recursive search
    let isRecursive = pattern.contains("**")

    // Start enumeration from current directory
    enumerateFiles(at: currentDirectory, isRecursive: isRecursive)

    return matchingPaths
}

func tagCommand() {
    if checkDB() {
        guard let dbase = database else {
            print("Error: Database connection failed")
            Foundation.exit(exitDatabaseError)
        }
        // The second part of this if clause is because if the user passes the --json
        // flag (which is ignored by this command), then CommandLine.argc is 5
        if processedArgs.count == 4 || (processedArgs.count == 5 && (jsonOutput || tagList)) {
            let pathToTag = processedArgs[2]
            let tagToUse = processedArgs[3]

            // Check if the path contains glob patterns
            let pathsToTag: [String]
            if pathToTag.contains("*") || pathToTag.contains("?") {
                pathsToTag = expandGlobPattern(pathToTag)
                if pathsToTag.isEmpty {
                    print("Warning: No files match the pattern '\(pathToTag)'")
                    return
                }
            } else {
                // Single file path - convert to relative path
                let dirURL = URL(fileURLWithPath: pathToTag)
                let index = dirURL.absoluteString.index(dirURL.absoluteString.startIndex, offsetBy: 7)
                let relativePath = "\(dirURL.absoluteString[index...])"
                pathsToTag = [relativePath]
            }

            // ProcessInfo.processInfo.hostName
            let hostName = ProcessInfo.processInfo.hostName

            let genieTable = Table("genie")
            let host = Expression<String>("host")
            let path = Expression<String?>("path")
            let tag = Expression<String>("tag")
            let timeCreated = Expression<String>("time_created")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd h:mm a Z"
            let now = dateFormatter.string(from: Date())

            // Tag each matching path
            for pathToTag in pathsToTag {
                let insert = genieTable.insert(host <- hostName,
                                               path <- pathToTag,
                                               tag <- tagToUse,
                                               timeCreated <- now)
                do {
                    _ = try dbase.run(insert)
                } catch {
                    print("Error: Unable to insert into database: \(error)")
                    Foundation.exit(exitDatabaseError)
                }
            }

            if pathsToTag.count > 1 {
                print("Tagged \(pathsToTag.count) files with '\(tagToUse)'")
            }
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
            Foundation.exit(exitUsageError)
        }
    } else {
        Foundation.exit(exitDatabaseError)
    }
}

func listTagsCommand() {
    // Fetch all distinct tags from the db and print them out
    if checkDB() {
        guard let dbase = database else {
            print("Error: Database connection failed")
            Foundation.exit(exitDatabaseError)
        }
        if processedArgs.count == 2 {
            let genieTable = Table("genie")
            let tag = Expression<String>("tag")
            let query = genieTable.select(distinct: tag)

            do {
                for item in try dbase.prepare(query) {
                    print("\(item[tag])")
                }
            } catch {
                print("Error: Unable to query database: \(error)")
                Foundation.exit(exitDatabaseError)
            }

        }
    } else {
        Foundation.exit(exitDatabaseError)
    }
}

func removeCommand() {
    if checkDB() {
        guard let dbase = database else {
            print("Error: Database connection failed")
            Foundation.exit(exitDatabaseError)
        }
        // The second part of this if clause is because if the user passes the --json
        // flag (which is ignored by this command), then CommandLine.argc is 5
        if processedArgs.count == 4 || (processedArgs.count == 5 && (jsonOutput || tagList)) {
            let pathToUntag = processedArgs[2]
            let tagToRemove = processedArgs[3]

            // Check if the path contains glob patterns
            let pathsToUntag: [String]
            if pathToUntag.contains("*") || pathToUntag.contains("?") {
                pathsToUntag = expandGlobPattern(pathToUntag)
                if pathsToUntag.isEmpty {
                    print("Warning: No files match the pattern '\(pathToUntag)'")
                    return
                }
            } else {
                // Single file path - convert to relative path
                let dirURL = URL(fileURLWithPath: pathToUntag)
                let index = dirURL.absoluteString.index(dirURL.absoluteString.startIndex, offsetBy: 7)
                let relativePath = "\(dirURL.absoluteString[index...])"
                pathsToUntag = [relativePath]
            }

            let genieTable = Table("genie")
            let path = Expression<String?>("path")
            let tag = Expression<String>("tag")

            // Remove tag from each matching path
            var removedCount = 0
            for pathToUntag in pathsToUntag {
                let rowToDelete = genieTable.filter(path == pathToUntag).filter(tag == tagToRemove)
                do {
                    let deletedRows = try dbase.run(rowToDelete.delete())
                    removedCount += deletedRows
                } catch {
                    print("Error: Unable to delete from database: \(error)")
                    Foundation.exit(exitDatabaseError)
                }
            }

            if pathsToUntag.count > 1 {
                print("Removed tag '\(tagToRemove)' from \(removedCount) files")
            }
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
            Foundation.exit(exitUsageError)
        }
    } else {
        Foundation.exit(exitDatabaseError)
    }
}

func searchCommand() {
    if checkDB() {
        guard let dbase = database else {
            print("Error: Database connection failed")
            Foundation.exit(exitDatabaseError)
        }
        // The second part of this if clause is because if the user passes either of
        // the --json or --list flags, then CommandLine.argc is at least 4
        if processedArgs.count >= 3 || (processedArgs.count >= 4 && (jsonOutput || tagList)) {
            let searchExpression = processedArgs[2..<processedArgs.count].joined(separator: " ")

            let parser = BooleanExpressionParser()
            if let expression = parser.parse(searchExpression) {
                let evaluator = BooleanExpressionEvaluator(database: dbase)
                let matchingPaths = evaluator.evaluate(expression)

                var outputArray: [String: [Dictionary<String, String>]] = [:]
                var items: [Dictionary<String, String>] = []

                for pathValue in matchingPaths {
                    if jsonOutput {
                        let result: [String: String] = [
                            "title": pathValue,
                            "subtitle": pathValue,
                            "arg": pathValue,
                            "autocomplete": pathValue,
                            "quicklookurl": pathValue,
                            "type": "file"
                        ]
                        items.append(result)
                    } else {
                        print(pathValue)
                    }
                }

                if jsonOutput {
                    let encoder = JSONEncoder()
                    outputArray["items"] = items
                    if let jsonData = try? encoder.encode(outputArray) {
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            print(jsonString)
                        }
                    }
                }
            } else {
                print("Error: Invalid boolean expression")
                printUsage()
                Foundation.exit(exitInvalidExpression)
            }
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
            Foundation.exit(exitUsageError)
        }
    } else {
        Foundation.exit(exitDatabaseError)
    }
}

func printCommand() {
    if checkDB() {
        guard let dbase = database else {
            print("Error: Database connection failed")
            Foundation.exit(exitDatabaseError)
        }
        // The second part of this if clause is because if the user passes the --json
        // flag (which is ignored by this command), then CommandLine.argc is 4
        if processedArgs.count == 3 || (processedArgs.count == 4 && (jsonOutput || tagList)) {
            var searchPath = processedArgs[2]
            let genieTable = Table("genie")

            let dirURL = URL(fileURLWithPath: searchPath)
            let index = dirURL.absoluteString.index(dirURL.absoluteString.startIndex, offsetBy: 7)
            searchPath = "\(dirURL.absoluteString[index...])"

            let path = Expression<String?>("path")
            let tag = Expression<String>("tag")
            let query = genieTable.select(tag).filter(path == searchPath)
            do {
                for item in try dbase.prepare(query) {
                    print("\(item[tag])")
                }
            } catch {
                print("Error: Unable to query database: \(error)")
                Foundation.exit(exitDatabaseError)
            }
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
            Foundation.exit(exitUsageError)
        }
    } else {
        Foundation.exit(exitDatabaseError)
    }
}

// Boolean expression structures
// swiftlint:disable identifier_name
enum BooleanOperator {
    case and, or, not, xor
}
// swiftlint:enable identifier_name

enum BooleanExpression {
    case tag(String)
    case operation(BooleanOperator, [BooleanExpression])
    indirect case not(BooleanExpression)
}

class BooleanExpressionParser {
    private var tokens: [String] = []
    private var currentIndex = 0

    func parse(_ expression: String) -> BooleanExpression? {
        // Tokenize the expression
        tokens = tokenize(expression)
        currentIndex = 0

        return parseExpression()
    }

    private func tokenize(_ expression: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for char in expression {
            if char.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else if char == "(" || char == ")" || char == "&" || char == "|" || char == "^" || char == "!" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private func parseExpression() -> BooleanExpression? {
        var expressions: [BooleanExpression] = []
        var operators: [BooleanOperator] = []

        while currentIndex < tokens.count {
            let token = tokens[currentIndex]

            if token == "(" {
                currentIndex += 1
                if let subExpr = parseExpression() {
                    expressions.append(subExpr)
                }
            } else if token == ")" {
                currentIndex += 1
                break
            } else if token == "not" || token == "!" {
                currentIndex += 1
                if currentIndex < tokens.count {
                    if tokens[currentIndex] == "(" {
                        currentIndex += 1
                        if let subExpr = parseExpression() {
                            expressions.append(.not(subExpr))
                        }
                    } else {
                        let tag = tokens[currentIndex]
                        currentIndex += 1
                        expressions.append(.not(.tag(tag)))
                    }
                }
            } else if ["and", "or", "xor", "&", "|", "^"].contains(token) {
                let oper: BooleanOperator
                switch token {
                case "and", "&": oper = .and
                case "or", "|": oper = .or
                case "xor", "^": oper = .xor
                default: oper = .and
                }
                operators.append(oper)
                currentIndex += 1
            } else {
                // Assume it's a tag
                expressions.append(.tag(token))
                currentIndex += 1
            }
        }

        // Evaluate expressions with operators
        if expressions.isEmpty {
            return nil
        }

        var result = expressions[0]
        for index in 0..<operators.count where index + 1 < expressions.count {
            result = .operation(operators[index], [result, expressions[index + 1]])
        }

        return result
    }
}

class BooleanExpressionEvaluator {
    private let database: Connection
    private let genieTable: Table

    init(database: Connection) {
        self.database = database
        self.genieTable = Table("genie")
    }

    func evaluate(_ expression: BooleanExpression) -> Set<String> {
        switch expression {
        case .tag(let tag):
            return getPathsWithTag(tag)
        case .operation(let oper, let expressions):
            switch oper {
            case .and:
                guard expressions.count == 2 else { return [] }
                let left = evaluate(expressions[0])
                let right = evaluate(expressions[1])
                return left.intersection(right)
            case .or:
                guard expressions.count == 2 else { return [] }
                let left = evaluate(expressions[0])
                let right = evaluate(expressions[1])
                return left.union(right)
            case .xor:
                guard expressions.count == 2 else { return [] }
                let left = evaluate(expressions[0])
                let right = evaluate(expressions[1])
                return left.symmetricDifference(right)
            case .not:
                return []
            }
        case .not(let expr):
            let pathsWithExpr = evaluate(expr)
            let allPaths = getAllPaths()
            return allPaths.subtracting(pathsWithExpr)
        }
    }

    private func getPathsWithTag(_ tag: String) -> Set<String> {
        let path = Expression<String?>("path")
        let tagExpr = Expression<String>("tag")
        let query = genieTable.select(distinct: path).filter(tagExpr == tag)

        var paths: Set<String> = []
        do {
            for item in try database.prepare(query) {
                if let pathValue = item[path] {
                    paths.insert(pathValue)
                }
            }
        } catch {
            print("Error: Unable to query database: \(error)")
            return []
        }
        return paths
    }

    private func getAllPaths() -> Set<String> {
        let path = Expression<String?>("path")
        let query = genieTable.select(distinct: path)

        var paths: Set<String> = []
        do {
            for item in try database.prepare(query) {
                if let pathValue = item[path] {
                    paths.insert(pathValue)
                }
            }
        } catch {
            print("Error: Unable to query database: \(error)")
            return []
        }
        return paths
    }
}

// Process command line arguments without modifying CommandLine.arguments
processedArgs = CommandLine.arguments

if processedArgs.contains("-j") || processedArgs.contains("--json") {
    jsonOutput = true
    processedArgs = processedArgs.filter { $0 != "-j" && $0 != "--json" }
}

if processedArgs.contains("-l") || processedArgs.contains("--list") {
    tagList = true
    processedArgs = processedArgs.filter { $0 != "-l" && $0 != "--list" }
}

// Process --db flag
if let dbIndex = processedArgs.firstIndex(of: "--db") {
    if dbIndex + 1 < processedArgs.count {
        customDbPath = processedArgs[dbIndex + 1]
        // Remove both --db and its value from processedArgs
        processedArgs.remove(at: dbIndex + 1)
        processedArgs.remove(at: dbIndex)
    } else {
        print("Error: --db flag requires a path argument")
        Foundation.exit(exitUsageError)
    }
}

if processedArgs.count == 1 || (processedArgs.count == 2 && jsonOutput) {
    print("Error: Not enough arguments\n")
    printUsage()
    Foundation.exit(exitUsageError)
}

if processedArgs.count > 1 {
    switch processedArgs[1] {
    case "-h",
        "--help":
        printUsage()
    case "-v",
        "--version":
        print("\(commandName) \(genieVersion)")
    case "t",
        "tag":
        if tagList {
            listTagsCommand()
        } else {
            tagCommand()
        }
    case "rm",
        "remove":
        removeCommand()
    case "s",
        "search":
        searchCommand()
    case "p",
        "print":
        printCommand()
    default:
        unknownCommand()
    }
}
