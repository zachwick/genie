# Genie

[![Build Status](https://travis-ci.com/zachwick/genie.svg?branch=master)](https://travis-ci.com/zachwick/genie) [![Swift5 compatible](https://img.shields.io/badge/swift-5-orange.svg?style=flat)](https://developer.apple.com/swift/)

genie - a tool for tagging arbitrary file paths with arbitrary tags

## Installation

1. Clone the project
2. Build with `swift build`
3. Install by copying the binary from the architecture specific folder in `.build/` to a location in your PATH environment variable.

## Usage

Use `genie --help` to see usage instructions

### Invocation

`genie [SUBCOMMAND]`

### Flags

| short flag | long flag | description |
| -- | -- | -- |
| `-h` | `--help` | Prints help information |
| `-v` | `--version` | Prints version information |
| `-j` | `--json` | Gives output as json string |

### Subcommands

| command | short version | description |
| -- | -- | -- |
| `help` | n/a | Prints this help message |
| `rm [PATH] [TAG]` | n/a | remove from the given `PATH` the given `TAG` |
| `search [TAG]` | `s` | search for and return all paths that have `TAG` |
| `print [PATH]` | `p` | show all tags applied to the given `PATH` |
| `tag [PATH] [TAG]` | `t` | tag the given `PATH` with the given `TAG` |

## License

genie is copyright 2017, 2018, 2019, 2020 zach wick <zach@zachwick.com> and is licensed
under the GNU GPLv3 or later. You can find a copy of the GNU GPLv3
included in the project as the file named [License](https://github.com/zachwick/genie/blob/master/LICENSE).
