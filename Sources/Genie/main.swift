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

// global modal for the application
var verbose = false

try! ArgTree(description:
"""
usage: \(CommandLine.arguments[0])) [flags...]

hello world demo

flags:
""",
    parsers: [
        Flag(longName: "verbose", shortName: "v", description: "print verbose output") { _ in
            verbose = true
        }
    ]).parse()
    
// here comes the real program code after parsing the command line arguments
if verbose {
    print("SQLite DB at: \(dbPath)")
} else {
    print("\(dbPath)")
}
