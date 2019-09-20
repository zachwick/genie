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

let dbPath = "~/.geniedb"
let genieVersion = "0.0.1"

var version = false
var path: String
var tag: String

func printUsage() {
    print("HELP DOC HERE")
}

func unknownCommand() {
    print("Command \(CommandLine.arguments[1]) not found.")
    printUsage()
}

switch CommandLine.arguments[1] {
case "-h",
     "--help":
    printUsage()
case "-v",
     "--version":
    print("\((CommandLine.arguments[0] as NSString).lastPathComponent) \(genieVersion)")
case "t",
     "tag":
    print("do tag command")
case "rm",
     "remove":
    print("do remove command")
case "s",
     "search":
    print("do search command")
case "p",
     "print":
    print("do print/show command")
default:
    unknownCommand()
}
