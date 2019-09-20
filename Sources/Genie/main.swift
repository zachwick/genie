/**
* genie - filesystem tagger
*
* Copyright 2017, 2018, 2019 zachwick <zach@zachwick.com>
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

func checkDB() -> Bool {
    // Connect to the SQLite db and ensure that it is structured correctly
    return true
}

func initializeDB() {
    // Create the SQLite db and structure it correctly
    let genieTable = Table("genie")
    let id = Expression<Int64>("id")
    let path = Expression<String?>("path")
    let tag = Expression<String>("tag")

    guard let _ = try? db.run(genieTable.create { t in
        t.column(id, primaryKey: true)
        t.column(path)
        t.column(tag)
    }) else {
        print("Error: Unable to initialize the SQLite table.")
        return
    }
}

func tagCommand() {
    if checkDB() {
        if CommandLine.argc >= 4 {
            let path = CommandLine.arguments[2]
            let tag = CommandLine.arguments[3]
            print("tag PATH: \(path) with TAG: \(tag)")
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
        }
    }
}

func removeCommand() {
    if checkDB() {
        if CommandLine.argc >= 4 {
            let path = CommandLine.arguments[2]
            let tag = CommandLine.arguments[3]
            print("remove PATH: \(path) from TAG: \(tag)")
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
            let path = CommandLine.arguments[2]
            print("print all tags for PATH: \(path)")
        } else {
            print("Error: Not enough arguments\n")
            printUsage()
        }
    }
}

switch CommandLine.arguments[1] {
case "-h",
     "--help":
    printUsage()
case "-v",
     "--version":
    print("\(commandName) \(genieVersion)")
case "init":
    initializeDB()
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
