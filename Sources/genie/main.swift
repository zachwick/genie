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
var db: Connection?
var jsonOutput = false
var tagList = false
var customDbPath: String?
var processedArgs: [String] = []

// Exit codes
let EXIT_SUCCESS: Int32 = 0
let EXIT_USAGE_ERROR: Int32 = 1
let EXIT_DATABASE_ERROR: Int32 = 2
let EXIT_INVALID_EXPRESSION: Int32 = 3

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

        OPERATORS:
            AND: "and" or "&"
            OR:  "or"  or "|"
            NOT: "not" or "!"
            XOR: "xor" or "^"

        SUBCOMMANDS:
            help       Prints this help message
            rm         remove from the given PATH the given TAG
            search (s) search for and return all PATHS using boolean expressions (e.g., "tag1 and not tag2", "tag1 and (tag2 or tag3)")
            print  (p) show all tags applied to the given PATH
            tag    (t) tag the given PATH with the given TAG
        """
    print(usageString)
}

func unknownCommand() {
    print("Command \(processedArgs[1]) not found.")
    printUsage()
    Foundation.exit(EXIT_USAGE_ERROR)
}

func checkDB() -> Bool  {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: getDatabasePath()) {
        // Open existing database and check if the genie table exists
        do {
            db = try Connection(getDatabasePath())
            
            // Check if the genie table exists
            let tableExists = try db!.scalar("SELECT name FROM sqlite_master WHERE type='table' AND name='genie'") != nil
            
            if !tableExists {
                // Create the genie table if it doesn't exist
                let genieTable = Table("genie")
                let id = Expression<Int64>("id")
                let host = Expression<String>("host")
                let path = Expression<String?>("path")
                let tag = Expression<String>("tag")
                let timeCreated = Expression<String>("time_created")

                try db!.run(genieTable.create { t in
                    t.column(id, primaryKey: true)
                    t.column(host)
                    t.column(path)
                    t.column(tag)
                    t.column(timeCreated)
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
            db = try Connection(getDatabasePath())
            let genieTable = Table("genie")
            let id = Expression<Int64>("id")
            let host = Expression<String>("host")
            let path = Expression<String?>("path")
            let tag = Expression<String>("tag")
            let timeCreated = Expression<String>("time_created")
            
            try db!.run(genieTable.create { t in
                t.column(id, primaryKey: true)
                t.column(host)
                t.column(path)
                t.column(tag)
                t.column(timeCreated)
            })
            return true
        } catch {
            print("Error: Unable to create database at \(getDatabasePath()): \(error)")
            return false
        }
    }
}

func tagCommand() {
    if checkDB() {
        // The second part of this if clause is because if the user passes the --json
        // flag (which is ignored by this command), then CommandLine.argc is 5
        if processedArgs.count == 4 || (processedArgs.count == 5 && (jsonOutput || tagList)) {
            var pathToTag = processedArgs[2]
            let tagToUse = processedArgs[3]
            
            let dirURL = URL(fileURLWithPath: pathToTag)
            let index = dirURL.absoluteString.index(dirURL.absoluteString.startIndex, offsetBy: 7)
            pathToTag = "\(dirURL.absoluteString[index...])"

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
            
            let insert = genieTable.insert(host <- hostName,
                                           path <- pathToTag,
                                           tag <- tagToUse,
                                           timeCreated <- now)
            let _ = try! db!.run(insert)
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
            Foundation.exit(EXIT_USAGE_ERROR)
        }
    } else {
        Foundation.exit(EXIT_DATABASE_ERROR)
    }
}

func listTagsCommand() {
    // Fetch all distinct tags from the db and print them out
    if checkDB() {
        if processedArgs.count == 2 {
            let genieTable = Table("genie")
            let tag = Expression<String>("tag")
            let query = genieTable.select(distinct: tag)

            for item in try! db!.prepare(query) {
                print("\(item[tag])")
            }

        }
    } else {
        Foundation.exit(EXIT_DATABASE_ERROR)
    }
}

func removeCommand() {
    if checkDB() {
        // The second part of this if clause is because if the user passes the --json
        // flag (which is ignored by this command), then CommandLine.argc is 5
        if processedArgs.count == 4 || (processedArgs.count == 5 && (jsonOutput || tagList)) {
            var pathToUntag = processedArgs[2]
            let tagToRemove = processedArgs[3]
            
            let dirURL = URL(fileURLWithPath: pathToUntag)
            let index = dirURL.absoluteString.index(dirURL.absoluteString.startIndex, offsetBy: 7)
            pathToUntag = "\(dirURL.absoluteString[index...])"
            
            let genieTable = Table("genie")
            let path = Expression<String?>("path")
            let tag = Expression<String>("tag")
            
            let rowToDelete = genieTable.filter(path == pathToUntag).filter(tag == tagToRemove)
            try! db!.run(rowToDelete.delete())
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
            Foundation.exit(EXIT_USAGE_ERROR)
        }
    } else {
        Foundation.exit(EXIT_DATABASE_ERROR)
    }
}

func searchCommand() {
    if checkDB() {
        // The second part of this if clause is because if the user passes either of
        //the --json or --list flags, then CommandLine.argc is at least 4
        if processedArgs.count >= 3 || (processedArgs.count >= 4 && (jsonOutput || tagList)) {
            let searchExpression = processedArgs[2..<processedArgs.count].joined(separator: " ")
            
            let parser = BooleanExpressionParser()
            if let expression = parser.parse(searchExpression) {
                let evaluator = BooleanExpressionEvaluator(db: db!)
                let matchingPaths = evaluator.evaluate(expression)
                
                var outputArray: Dictionary<String, [Dictionary<String, String>]> = [:]
                var items: [Dictionary<String, String>] = []
                
                for pathValue in matchingPaths {
                    if jsonOutput {
                        let result: Dictionary<String, String> = [
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
                Foundation.exit(EXIT_INVALID_EXPRESSION)
            }
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
            Foundation.exit(EXIT_USAGE_ERROR)
        }
    } else {
        Foundation.exit(EXIT_DATABASE_ERROR)
    }
}

func printCommand() {
    if checkDB() {
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
            for item in try! db!.prepare(query) {
                print("\(item[tag])")
            }
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
            Foundation.exit(EXIT_USAGE_ERROR)
        }
    } else {
        Foundation.exit(EXIT_DATABASE_ERROR)
    }
}

// Boolean expression structures
enum BooleanOperator {
    case and, or, not, xor
}

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
                let op: BooleanOperator
                switch token {
                case "and", "&": op = .and
                case "or", "|": op = .or
                case "xor", "^": op = .xor
                default: op = .and
                }
                operators.append(op)
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
        for i in 0..<operators.count {
            if i + 1 < expressions.count {
                result = .operation(operators[i], [result, expressions[i + 1]])
            }
        }
        
        return result
    }
}

class BooleanExpressionEvaluator {
    private let db: Connection
    private let genieTable: Table
    
    init(db: Connection) {
        self.db = db
        self.genieTable = Table("genie")
    }
    
    func evaluate(_ expression: BooleanExpression) -> Set<String> {
        switch expression {
        case .tag(let tag):
            return getPathsWithTag(tag)
        case .operation(let op, let expressions):
            switch op {
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
        for item in try! db.prepare(query) {
            if let pathValue = item[path] {
                paths.insert(pathValue)
            }
        }
        return paths
    }
    
    private func getAllPaths() -> Set<String> {
        let path = Expression<String?>("path")
        let query = genieTable.select(distinct: path)
        
        var paths: Set<String> = []
        for item in try! db.prepare(query) {
            if let pathValue = item[path] {
                paths.insert(pathValue)
            }
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
        Foundation.exit(EXIT_USAGE_ERROR)
    }
}

if processedArgs.count == 1 || (processedArgs.count == 2 && jsonOutput) {
    print("Error: Not enough arguments\n")
    printUsage()
    Foundation.exit(EXIT_USAGE_ERROR)
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
