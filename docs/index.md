# Genie

[![Build Status](https://travis-ci.com/zachwick/genie.svg?branch=master)](https://travis-ci.com/zachwick/genie) [![Swift5 compatible](https://img.shields.io/badge/swift-5-orange.svg?style=flat)](https://developer.apple.com/swift/)

genie - a tool for tagging arbitrary file paths with arbitrary tags

## Installation

1. Clone the project
2. Build with `swift build -c release` (or `swift build` to build a debug version)
3. Install by copying the binary from the architecture specific folder in `.build/` to a location in your PATH environment variable. This usually looks something like

> cp ./.build/x86_64-apple-macosx/release/genie /usr/local/bin

## CLI Usage

Use `genie --help` to see usage instructions

### Invocation

`genie [SUBCOMMAND]`

### Flags

| short flag | long flag | description |
| -- | -- | -- |
| `-h` | `--help` | Prints help information |
| `-v` | `--version` | Prints version information |
| `-j` | `--json` | Gives output as json string for use in Alfred |

### Subcommands

| command | short version | description |
| -- | -- | -- |
| `help` | n/a | Prints this help message |
| `rm [PATH] [TAG]` | n/a | remove from the given `PATH` the given `TAG` |
| `search [TAG]` | `s` | search for and return all paths that have `TAG` |
| `print [PATH]` | `p` | show all tags applied to the given `PATH` |
| `tag [PATH] [TAG]` | `t` | tag the given `PATH` with the given `TAG` |

## Alfred Usage

Once you've started tagging your filepaths with meaningful tags, you may find yourself wanting to quickly find and action a particular filepath. One way to do this is using the `search` command in a terminal. A more graphical way is to use [Alfred](https://www.alfredapp.com).

### Installing the Alfred Workflow

In order to use genie's `search` command from within Alfred, you must first install the Genie Workflow for Alfred.

0. Install [Alfred](https://www.alfredapp.com)
1. Download the [Genie Workflow](https://github.com/zachwick/genie/raw/master/Genie.alfredworkflow)
2. Double-click on the downloaded file in Finder
3. Follow the on-screen instructions to install the workflow into Alfred

### Using the Alfred Workflow

While you _can_ use the Alfred workflow with the `tag`, `rm`, and `print` genie commands, it is most useful when used with the `search` command. To use the workflow to search for all filepaths with a given tag

1. Invoke your configured Alfred hotkey(s)
2. type `g search TAG` (or `g s TAG`) replacing `TAG` with the tag that you would like to search for
3. Select the filepath that you're interested in, and action it as desired.

Some common actions include quicklooking the file with either the `shift` key or `cmd + y`. Once you're quicklooking a filepath, Quick Look often has additional actions that you can take such as opening a file in a particular application.

## Advanced Usage

On macOS, genie uses `~/Documents/.geniedb` as the location of its backing sqlite store. If there is not a file to be found at that location whenever `genie` is invoked, it will create the file and the requisite sqlite table(s).

If you are feeling adventurous, after you've invoked `genie` at least once to create the file and needed tables, you can move that sqlite document to any location and symlink it back to the original path of `~/Documents/.geniedb`. As an illustrative example, after you've invoked `genie` at least once, you can do something like

> mv ~/Documents/.geniedb ~/Dropbox/geniedb
> ln -s ~/Dropbox/geniedb ~/Documents/.geniedb

Once you've done this, genie will traverse the symlink and the backing store for genie can be synced and shared across multiple machines. This means that when using the `search` command, the returned paths may not live locally on the machine that you're invoking `genie` from. You will need to pay attention to the indicated host and then locate the file on the corresponding machine in order to interact with it.

## License

genie is copyright 2017, 2018, 2019, 2020 zach wick <zach@zachwick.com> and is licensed
under the GNU GPLv3 or later. You can find a copy of the GNU GPLv3
included in the project as the file named [License](https://github.com/zachwick/genie/blob/master/LICENSE).
