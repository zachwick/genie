# Genie

A powerful filesystem tagger for organizing and searching files with arbitrary tags.

## What is Genie?

Genie is a command-line tool that allows you to tag arbitrary file paths with arbitrary tags, making it easy to organize and search through your filesystem using boolean expressions. It's particularly useful for developers, researchers, and anyone who needs to categorize files across different projects and contexts.

## Features

- **Flexible Tagging**: Tag any file path with multiple tags
- **Boolean Search**: Search files using complex boolean expressions (`and`, `or`, `not`, `xor`)
- **Alfred Integration**: Built-in Alfred workflow for quick file access
- **MCP Support**: Python MCP server for integration with AI assistants
- **Cross-platform**: Works on macOS, Linux, and other Unix-like systems
- **SQLite Backend**: Reliable data storage with optional cloud sync support

## Installation

### Download Binary
Download the latest release and place the binary in your shell's PATH. A popular choice is `/usr/local/bin`:

```bash
# Example installation
cp genie /usr/local/bin
```

### Build from Source
1. Clone the repository
2. Build with Swift: `swift build` (or `swift build -c release` for optimized build)
3. Install the binary:
```bash
cp .build/x86_64-apple-macosx/release/genie /usr/local/bin
```

## Quick Start

### Basic Usage

```bash
# Tag a file
genie tag /path/to/file work

# Search for files with a tag
genie search work

# Show all tags for a file
genie print /path/to/file

# Remove a tag from a file
genie rm /path/to/file work
```

### Boolean Search Examples

```bash
# Find files with both "work" and "urgent" tags
genie search "work and urgent"

# Find files with either "work" or "personal" tags
genie search "work or personal"

# Find files with "project" tag but not "archived"
genie search "project and not archived"

# Complex expressions with parentheses
genie search "work and (urgent or important) and not archived"
```

### Alfred Integration

1. Install the [Genie Alfred Workflow](Genie.alfredworkflow)
2. Use `g search TAG` in Alfred to quickly find and action files
3. Quick Look files with `shift` or `cmd + y` for additional actions

## MCP Integration

For AI assistant integration, the project includes a Python MCP server that can be run locally from a clone of the repository. Add something like the following to your Claude configuration:

```json
{
  "genie": {
    "command": "uv",
    "args": [
      "--directory",
      "/path/to/genie/mcp",
      "run",
      "genie.py"
    ]
  }
}
```

## Advanced Features

- **Cloud Sync**: Move the SQLite database to cloud storage and symlink back for cross-machine sync
- **JSON Output**: Use `-j` flag for JSON output suitable for automation
- **Custom Database Location**: Modify `~/Documents/.geniedb` location as needed

## Documentation

For complete documentation, including detailed usage examples, boolean search operators, and advanced features, visit:

**[📖 Full Documentation](https://zachwick.github.io/genie/)**

## License

Genie is copyright 2017-2025 zach wick (zach@zachwick.com) and is licensed under the GNU GPLv3 or later.

## Contributing

This project is maintained by [zachwick](https://github.com/zachwick). Contributions are welcome!

