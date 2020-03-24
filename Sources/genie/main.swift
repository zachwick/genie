/**
* genie - filesystem tagger
*
* Copyright 2017, 2018, 2019, 2020 zachwick <zach@zachwick.com>
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
let databaseFilePath = "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/\(dbPath)"
let genieVersion = "1.1.1"
let commandName = (CommandLine.arguments[0] as NSString).lastPathComponent
var db: Connection?
var jsonOutput = false
var tagList = false

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

        SUBCOMMANDS:
            help       Prints this help message
            rm         remove from the given PATH the given TAG
            search (s) search for and return all PATHS that have all of the given TAGs
            print  (p) show all tags applied to the given PATH
            tag    (t) tag the given PATH with the given TAG
        """
    print(usageString)
}

func unknownCommand() {
    print("Command \(CommandLine.arguments[1]) not found.")
    printUsage()
}

func checkDB() -> Bool  {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: databaseFilePath) {
        // This call to `Connection` will createthe database file if it is not already present at the given filepath
        db = try! Connection(databaseFilePath)
        return true
    } else {
        // Create the SQLite db and structure it correctly
        // This call to `Connection` will createthe database file if it is not already present at the given filepath
        db = try! Connection(databaseFilePath)
        let genieTable = Table("genie")
        let id = Expression<Int64>("id")
        let host = Expression<String>("host")
        let path = Expression<String?>("path")
        let tag = Expression<String>("tag")
        let timeCreated = Expression<String>("time_created")
        
        try! db!.run(genieTable.create { t in
            t.column(id, primaryKey: true)
            t.column(host)
            t.column(path)
            t.column(tag)
            t.column(timeCreated)
        })
        return true
    }

}

func tagCommand() {
    if checkDB() {
        // The second part of this if clause is because if the user passes the --json
        // flag (which is ignored by this command), then CommandLine.argc is 5
        if CommandLine.argc == 4 || (CommandLine.argc == 5 && (jsonOutput || tagList)) {
            var pathToTag = CommandLine.arguments[2]
            let tagToUse = CommandLine.arguments[3]
            
            let dirURL = URL(fileURLWithPath: pathToTag)
            let index = dirURL.absoluteString.index(dirURL.absoluteString.startIndex, offsetBy: 7)
            pathToTag = "\(dirURL.absoluteString[index...])"

            let hostName = Host.current().localizedName ?? ""
            
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
        }
    }
}

func listTagsCommand() {
    // Fetch all distinct tags from the db and print them out
    if checkDB() {
        if CommandLine.argc == 3 {
            let genieTable = Table("genie")
            let tag = Expression<String>("tag")
            let query = genieTable.select(distinct: tag)

            for item in try! db!.prepare(query) {
                print("\(item[tag])")
            }

        }
    }
}

func removeCommand() {
    if checkDB() {
        // The second part of this if clause is because if the user passes the --json
        // flag (which is ignored by this command), then CommandLine.argc is 5
        if CommandLine.argc == 4 || (CommandLine.argc == 5 && (jsonOutput || tagList)) {
            var pathToUntag = CommandLine.arguments[2]
            let tagToRemove = CommandLine.arguments[3]
            
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
        }
    }
}

func searchCommand() {
    if checkDB() {
        // TODO: This should be able to search for paths that match a set of tags
        // The second part of this if clause is because if the user passes the --json
        // flag, then CommandLine.argc is 4
        if CommandLine.argc == 3 || (CommandLine.argc == 4 && (jsonOutput || tagList)) {
            let searchTag = CommandLine.arguments[2]
            let genieTable = Table("genie")
            let host = Expression<String?>("host")
            let path = Expression<String?>("path")
            let tag = Expression<String>("tag")
            let query = genieTable.select(path, host).filter(tag == searchTag)
            var outputArray: Dictionary<String, [Dictionary<String, String>]> = [:]
            var items: [Dictionary<String, String>] = []

            for item in try! db!.prepare(query) {
                if jsonOutput {
                    let result: Dictionary<String, String> = [
                        "title": item[path]!,
                        "subtitle": item[path]!,
                        "arg": item[path]!,
                        "autocomplete": item[path]!,
                        "quicklookurl": item[path]!,
                        "type": "file"
                    ]
                    items.append(result)
                } else {
                    print("\(item[host]!): \(item[path]!)")
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
            print("Error: Not enough arguments\n")
            printUsage()
        }
    }
}

func printCommand() {
    if checkDB() {
        // The second part of this if clause is because if the user passes the --json
        // flag (which is ignored by this command), then CommandLine.argc is 4
        if CommandLine.argc == 3 || (CommandLine.argc == 4 && (jsonOutput || tagList)) {
            var searchPath = CommandLine.arguments[2]
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
        }
    }
}

if CommandLine.arguments.contains("-j") || CommandLine.arguments.contains("--json") {
    jsonOutput = true
    if let index = CommandLine.arguments.firstIndex(of: "-j") {
        CommandLine.arguments.remove(at: index)
    }
    if let index = CommandLine.arguments.firstIndex(of: "--json") {
        CommandLine.arguments.remove(at: index)
    }
}

if CommandLine.arguments.contains("-l") || CommandLine.arguments.contains("--list") {
    tagList = true
    if let index = CommandLine.arguments.firstIndex(of: "-l") {
        CommandLine.arguments.remove(at: index)
    }
    if let index = CommandLine.arguments.firstIndex(of: "--list") {
        CommandLine.arguments.remove(at: index)
    }
}

if CommandLine.argc == 1  || (CommandLine.argc == 2 && jsonOutput) {
    print("Error: Not enough arguments\n")
    printUsage()
}

switch CommandLine.arguments[1] {
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
