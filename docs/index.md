# Genie

[![Build Status](https://travis-ci.com/zachwick/genie.svg?branch=master)](https://travis-ci.com/zachwick/genie) [![Swift5 compatible](https://img.shields.io/badge/swift-5-orange.svg?style=flat)](https://developer.apple.com/swift/)

genie - a tool for tagging arbitrary file paths with arbitrary tags

## Installation

Download the [latest release](https://github.com/zachwick/genie/releases/latest), and put the binary somewhere in your shell's PATH. Using an install location of `/usr/local/bin` is a popular choice.

## CLI Usage

Use `genie --help` to see usage instructions

### Invocation

`genie [SUBCOMMAND]`

### Flags

| short flag | long flag | description |
| -- | -- | -- |
| `-h` | `--help` | Prints help information |
| `-v` | `--version` | Prints version information |
| `-j` | `--json` | Gives output as json string for use in Alfred (only used by the `search` subcommand) |
| `-l` | `--list` | Prints out a listing of all tags used in genie (only used by the `tag` subcommand) |

### Subcommands

| command | short version | description |
| -- | -- | -- |
| `help` | n/a | Prints this help message |
| `rm [PATH] [TAG]` | n/a | remove from the given `PATH` the given `TAG` |
| `search [EXPRESSION] [FLAG]` | `s` | search for and return all paths using boolean expressions (e.g., "tag1 and not tag2", "tag1 and (tag2 or tag3)") |
| `print [PATH]` | `p` | show all tags applied to the given `PATH` |
| `tag [PATH] [TAG] [FLAG]` | `t` | tag the given `PATH` with the given `TAG`, or print a list of all tags used. |

## Search with Boolean Operators

The `search` command supports powerful boolean expressions for finding files with specific tag combinations. You can use both word-based and single-character operators.

### Supported Operators

| Operator | Word-based | Single-character | Description |
|----------|------------|------------------|-------------|
| AND | `and` | `&` | Files that have ALL specified tags |
| OR | `or` | `|` | Files that have ANY of the specified tags |
| NOT | `not` | `!` | Files that do NOT have the specified tag |
| XOR | `xor` | `^` | Files that have exactly ONE of the specified tags (not both) |

### Search Examples

#### Basic Tag Search
```bash
# Find all files tagged with "work"
genie search work

# Find all files tagged with "important"
genie search important
```

#### AND Operator
```bash
# Find files with both "work" and "urgent" tags
genie search "work and urgent"
genie search "work & urgent"

# Find files with "project" tag but not "archived"
genie search "project and not archived"
genie search "project & !archived"
```

#### OR Operator
```bash
# Find files with either "work" or "personal" tags
genie search "work or personal"
genie search "work | personal"

# Find files with "urgent" or "important" tags
genie search "urgent or important"
genie search "urgent | important"
```

#### NOT Operator
```bash
# Find files with "work" tag but not "archived"
genie search "work and not archived"
genie search "work & !archived"

# Find all files except those tagged "archived"
genie search "not archived"
genie search "!archived"
```

#### XOR Operator
```bash
# Find files with exactly one of "work" or "personal" (not both)
genie search "work xor personal"
genie search "work ^ personal"
```

#### Complex Expressions with Parentheses
```bash
# Find files with "work" tag AND either "urgent" or "important"
genie search "work and (urgent or important)"
genie search "work & (urgent | important)"

# Find files with "project" tag AND (either "frontend" or "backend") AND NOT "archived"
genie search "project and (frontend or backend) and not archived"
genie search "project & (frontend | backend) & !archived"

# Find files with either "urgent" or "important" but not "archived"
genie search "(urgent or important) and not archived"
genie search "(urgent | important) & !archived"
```

#### Mixed Operator Types
```bash
# Combine word-based and single-character operators
genie search "work & urgent | important"
genie search "project and (frontend | backend) & !archived"
```

### Tips for Boolean Search

1. **Use quotes** around expressions with spaces to avoid shell interpretation issues
2. **Parentheses** help group complex expressions for clarity
3. **Single-character operators** (`&`, `|`, `!`, `^`) are more concise for simple expressions
4. **Word-based operators** (`and`, `or`, `not`, `xor`) are more readable for complex expressions
5. **NOT operator** works best when combined with other operators using AND

### JSON Output

For use with Alfred or other tools, you can get JSON output:

```bash
# Get JSON output for Alfred workflow
genie search -j "work and urgent"
genie search --json "work & urgent"
```

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

## MCP Usage

A python MCP server is provided that can be used with a local MCP client. To use this local MCP server with Claude for instance, you will first need to clone the repository. Then add the following to your Claude configuration:

        "genie": {
      "command": "uv",
      "args": [
        "--directory",
        "/path/to/genie/mcp",
        "run",
        "genie.py"
      ]
    }

## Advanced Usage

On macOS, genie uses `~/Documents/.geniedb` as the location of its backing sqlite store. If there is not a file to be found at that location whenever `genie` is invoked, it will create the file and the requisite sqlite table(s).

If you are feeling adventurous, after you've invoked `genie` at least once to create the file and needed tables, you can move that sqlite document to any location and symlink it back to the original path of `~/Documents/.geniedb`. As an illustrative example, after you've invoked `genie` at least once, you can do something like

```
mv ~/Documents/.geniedb ~/Dropbox/geniedb
ln -s ~/Dropbox/geniedb ~/Documents/.geniedb
```

Once you've done this, genie will traverse the symlink and the backing store for genie can be synced and shared across multiple machines. This means that when using the `search` command, the returned paths may not live locally on the machine that you're invoking `genie` from. You will need to pay attention to the indicated host and then locate the file on the corresponding machine in order to interact with it.

## Running a development version

1. Clone the project
2. Build with `swift build` (or `swift build -c release` to build a version with debugging symbols stripped out)
3. Install by copying the binary from the architecture specific folder in `.build/` to a location in your PATH environment variable. This usually looks something like

```
cp .build/x86_64-apple-macosx/release/genie /usr/local/bin
```

4. Alternatively you can run the built version from within the `.build` folder

## License

genie is copyright 2017, 2018, 2019, 2020 zach wick <zach@zachwick.com> and is licensed
under the GNU GPLv3 or later. You can find a copy of the GNU GPLv3
included in the project as the file named [License](https://github.com/zachwick/genie/blob/master/LICENSE).
