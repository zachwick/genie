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
let genieVersion = "0.0.1"
let commandName = (CommandLine.arguments[0] as NSString).lastPathComponent

let db = try Connection(databaseFilePath)

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
            -V, --version    Prints version information

        SUBCOMMANDS:
            help      Prints this help message
            rm        remove from the given PATH the given TAG
            search    search for and return all PATHS that have TAG
            show      show all tags applied to the given PATH
            tag       tag the given PATH with the given TAG
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
        //print("database file exists")
        return true
    } else {
        //print("database file doesnt exist. creating now")
        // Create the SQLite db and structure it correctly
        let genieTable = Table("genie")
        let id = Expression<Int64>("id")
        let path = Expression<String?>("path")
        let tag = Expression<String>("tag")
        let timeCreated = Expression<String>("time_created")
        
        try! db.run(genieTable.create { t in
            t.column(id, primaryKey: true)
            t.column(path)
            t.column(tag)
            t.column(timeCreated)
        })
        return true
    }

}

func tagCommand() {
    if checkDB() {
        if CommandLine.argc >= 4 {
            var pathToTag = CommandLine.arguments[2]
            let tagToUse = CommandLine.arguments[3]
            
            let dirURL = URL(fileURLWithPath: pathToTag)
            let index = dirURL.absoluteString.index(dirURL.absoluteString.startIndex, offsetBy: 7)
            pathToTag = "\(dirURL.absoluteString[index...])"

            let genieTable = Table("genie")
            let path = Expression<String?>("path")
            let tag = Expression<String>("tag")
            let timeCreated = Expression<String>("time_created")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd h:mm a Z"
            let now = dateFormatter.string(from: Date())
            
            let insert = genieTable.insert(path <- pathToTag,
                                           tag <- tagToUse,
                                           timeCreated <- now)
            let _ = try! db.run(insert)
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
        }
    }
}

func removeCommand() {
    if checkDB() {
        if CommandLine.argc >= 4 {
            var pathToUntag = CommandLine.arguments[2]
            let tagToRemove = CommandLine.arguments[3]
            
            let dirURL = URL(fileURLWithPath: pathToUntag)
            let index = dirURL.absoluteString.index(dirURL.absoluteString.startIndex, offsetBy: 7)
            pathToUntag = "\(dirURL.absoluteString[index...])"
            
            let genieTable = Table("genie")
            let path = Expression<String?>("path")
            let tag = Expression<String>("tag")
            
            let rowToDelete = genieTable.filter(path == pathToUntag).filter(tag == tagToRemove)
            try! db.run(rowToDelete.delete())
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
        }
    }
}

func searchCommand() {
    if checkDB() {
        // TODO: This should be able to search for paths that match a set of tags
        if CommandLine.argc == 3 {
            let searchTag = CommandLine.arguments[2]
            let genieTable = Table("genie")
            let path = Expression<String?>("path")
            let tag = Expression<String>("tag")
            let query = genieTable.select(path).filter(tag == searchTag)
            for item in try! db.prepare(query) {
                print("\(item[path]!)")
            }
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
        }
    }
}

func printCommand() {
    if checkDB() {
        if CommandLine.argc == 3 {
            var searchPath = CommandLine.arguments[2]
            let genieTable = Table("genie")
            
            let dirURL = URL(fileURLWithPath: searchPath)
            let index = dirURL.absoluteString.index(dirURL.absoluteString.startIndex, offsetBy: 7)
            searchPath = "\(dirURL.absoluteString[index...])"
            
            let path = Expression<String?>("path")
            let tag = Expression<String>("tag")
            let query = genieTable.select(tag).filter(path == searchPath)
            for item in try! db.prepare(query) {
                print("\(item[tag])")
            }
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
        }
    }
}

if CommandLine.argc == 1 { exit(0) }

switch CommandLine.arguments[1] {
case "-h",
     "--help":
    printUsage()
case "-v",
     "--version":
    print("\(commandName) \(genieVersion)")
case "t",
     "tag":
    tagCommand()
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
