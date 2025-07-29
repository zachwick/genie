#!/usr/bin/env python3
"""
Genie MCP Server using FastMCP

A Model Context Protocol server that provides access to the genie file tagging tool.
Genie allows you to tag arbitrary file paths with arbitrary tags for easy organization and search.
"""

import subprocess
import json
import os
from typing import List, Optional, Dict, Any
from pathlib import Path

from mcp.server.fastmcp import FastMCP

# Initialize the MCP server
mcp = FastMCP("genie")


def run_genie_command(args: List[str]) -> Dict[str, Any]:
    """
    Run a genie command and return the result.

    Args:
        args: List of command arguments (excluding 'genie')

    Returns:
        Dictionary with 'success', 'output', and optionally 'error' keys
    """
    try:
        # Check if genie is available
        result = subprocess.run(["which", "genie"], capture_output=True, text=True)
        if result.returncode != 0:
            return {
                "success": False,
                "error": "genie command not found. Please install genie and ensure it is in your PATH.",
            }

        # Run the genie command
        cmd = ["genie"] + args
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        return {
            "success": result.returncode == 0,
            "output": result.stdout.strip(),
            "error": result.stderr.strip() if result.stderr else None,
            "return_code": result.returncode,
        }

    except subprocess.TimeoutExpired:
        return {"success": False, "error": "Command timed out after 30 seconds"}
    except Exception as e:
        return {"success": False, "error": f"Error running genie command: {str(e)}"}


@mcp.tool()
def tag_file(file_path: str, tag: str) -> str:
    """
    Tag a file path with a given tag.

    Args:
        file_path: The file path to tag
        tag: The tag to apply to the file path

    Returns:
        Success message or error details
    """
    # Expand user path and resolve to absolute path
    expanded_path = os.path.expanduser(file_path)
    absolute_path = os.path.abspath(expanded_path)

    result = run_genie_command(["tag", absolute_path, tag])

    if result["success"]:
        return f"Successfully tagged '{absolute_path}' with tag '{tag}'"
    else:
        error_msg = result.get("error", "Unknown error")
        return f"Failed to tag file: {error_msg}"


@mcp.tool()
def remove_tag(file_path: str, tag: str) -> str:
    """
    Remove a specific tag from a file path.

    Args:
        file_path: The file path to remove the tag from
        tag: The tag to remove

    Returns:
        Success message or error details
    """
    # Expand user path and resolve to absolute path
    expanded_path = os.path.expanduser(file_path)
    absolute_path = os.path.abspath(expanded_path)

    result = run_genie_command(["rm", absolute_path, tag])

    if result["success"]:
        return f"Successfully removed tag '{tag}' from '{absolute_path}'"
    else:
        error_msg = result.get("error", "Unknown error")
        return f"Failed to remove tag: {error_msg}"


@mcp.tool()
def search_by_simple_tags(tags: str, json_output: bool = False) -> str:
    """
    Search for file paths that have all of the specified tags (simple AND logic).

    Args:
        tags: Space-separated list of tags to search for (all tags must be present)
        json_output: Whether to return output in JSON format

    Returns:
        List of matching file paths or error details
    """
    # Split tags by space and filter out empty strings
    tag_list = [tag.strip() for tag in tags.split() if tag.strip()]

    if not tag_list:
        return "Error: No tags provided for search"

    # Convert to boolean expression with AND logic
    boolean_expression = " and ".join(tag_list)

    # Build command arguments - pass the entire expression as a single string
    args = ["search", boolean_expression]
    if json_output:
        args.insert(1, "--json")  # Add --json flag after 'search'

    result = run_genie_command(args)

    if result["success"]:
        if result["output"]:
            return result["output"]
        else:
            return f"No files found with tags: {', '.join(tag_list)}"
    else:
        error_msg = result.get("error", "Unknown error")
        return f"Search failed: {error_msg}"


@mcp.tool()
def search_by_tags(tags: str, json_output: bool = False) -> str:
    """
    Search for file paths using boolean tag expressions.

    Args:
        tags: Boolean expression of tags to search for (e.g., "tag1 and not tag2", "tag1 & (tag2 | tag3)")
        json_output: Whether to return output in JSON format

    Returns:
        List of matching file paths or error details
    """
    if not tags.strip():
        return "Error: No tags provided for search"

    # Build command arguments - pass the entire expression as a single string
    args = ["search", tags.strip()]
    if json_output:
        args.insert(1, "--json")  # Add --json flag after 'search'

    result = run_genie_command(args)

    if result["success"]:
        if result["output"]:
            return result["output"]
        else:
            return f"No files found matching expression: {tags}"
    else:
        error_msg = result.get("error", "Unknown error")
        return f"Search failed: {error_msg}"


@mcp.tool()
def print_tags(file_path: str) -> str:
    """
    Show all tags applied to a given file path.

    Args:
        file_path: The file path to check for tags

    Returns:
        List of tags for the file or error details
    """
    # Expand user path and resolve to absolute path
    expanded_path = os.path.expanduser(file_path)
    absolute_path = os.path.abspath(expanded_path)

    result = run_genie_command(["print", absolute_path])

    if result["success"]:
        if result["output"]:
            return f"Tags for '{absolute_path}':\n{result['output']}"
        else:
            return f"No tags found for '{absolute_path}'"
    else:
        error_msg = result.get("error", "Unknown error")
        return f"Failed to get tags: {error_msg}"


@mcp.tool()
def list_all_tags() -> str:
    """
    List all tags that have been used in genie.

    Returns:
        List of all tags in the system or error details
    """
    result = run_genie_command(["tag", "--list"])

    if result["success"]:
        if result["output"]:
            return f"All tags in genie:\n{result['output']}"
        else:
            return "No tags found in the system"
    else:
        error_msg = result.get("error", "Unknown error")
        return f"Failed to list tags: {error_msg}"


@mcp.tool()
def genie_help() -> str:
    """
    Show genie help information.

    Returns:
        Help text for genie commands
    """
    result = run_genie_command(["--help"])

    if result["success"]:
        return result["output"]
    else:
        error_msg = result.get("error", "Unknown error")
        return f"Failed to get help: {error_msg}"


@mcp.tool()
def genie_version() -> str:
    """
    Show genie version information.

    Returns:
        Version information for genie
    """
    result = run_genie_command(["--version"])

    if result["success"]:
        return result["output"]
    else:
        error_msg = result.get("error", "Unknown error")
        return f"Failed to get version: {error_msg}"


@mcp.tool()
def check_genie_status() -> str:
    """
    Check if genie is installed and accessible, and show database location.

    Returns:
        Status information about genie installation
    """
    # Check if genie command exists
    result = subprocess.run(["which", "genie"], capture_output=True, text=True)
    if result.returncode != 0:
        return "❌ genie is not installed or not in PATH. Please install genie from https://github.com/zachwick/genie/releases/latest"

    genie_path = result.stdout.strip()

    # Check if database exists
    db_path = os.path.expanduser("~/Documents/.geniedb")
    db_exists = os.path.exists(db_path)

    # Get version
    version_result = run_genie_command(["--version"])
    version = (
        version_result.get("output", "Unknown")
        if version_result["success"]
        else "Unknown"
    )

    status = f"""✅ Genie Status:
• Executable: {genie_path}
• Version: {version}
• Database: {db_path} ({'exists' if db_exists else 'will be created on first use'})
• Ready to use: {'Yes' if db_exists else 'Yes (database will be initialized)'}"""

    return status


@mcp.tool()
def search_examples() -> str:
    """
    Show examples of boolean tag expressions for search.

    Returns:
        Examples of boolean tag expressions and their meanings
    """
    examples = """Boolean Tag Expression Examples:

BASIC OPERATORS:
• "tag1 and tag2" - Files with both tag1 AND tag2
• "tag1 or tag2" - Files with either tag1 OR tag2 (or both)
• "tag1 and not tag2" - Files with tag1 but NOT tag2
• "tag1 xor tag2" - Files with exactly one of tag1 or tag2 (not both)

SINGLE CHARACTER OPERATORS:
• "tag1 & tag2" - Same as "tag1 and tag2"
• "tag1 | tag2" - Same as "tag1 or tag2"
• "tag1 & !tag2" - Same as "tag1 and not tag2"
• "tag1 ^ tag2" - Same as "tag1 xor tag2"

COMPLEX EXPRESSIONS:
• "tag1 and (tag2 or tag3)" - Files with tag1 AND (tag2 OR tag3)
• "tag1 & (tag2 | tag3)" - Same as above using single char operators
• "(tag1 or tag2) and not tag3" - Files with (tag1 OR tag2) but NOT tag3
• "tag1 xor (tag2 and tag3)" - Files with tag1 XOR (tag2 AND tag3)

USAGE:
Use search_by_tags() for boolean expressions
Use search_by_simple_tags() for simple space-separated tag lists (AND logic only)"""

    return examples


if __name__ == "__main__":
    # Run the MCP server
    mcp.run(transport="stdio")
