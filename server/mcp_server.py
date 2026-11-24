"""MCP server exposing checklist tools to AI agents (stdio transport).

Run:  python mcp_server.py
Requires an API key with the desired scope, preferably from a 0600 file
(see mcp_setup.py, which creates it):
      export CHECKLISTS_API_KEY_FILE=~/.config/tapitask/agent.key
      export CHECKLISTS_URL=https://checklists.example.com
CHECKLISTS_API_KEY (the key itself in the environment) still works; when both
are set the file wins. The file is re-read on every request, so a rotated key
is picked up without restarting the server.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

URL = os.environ.get("CHECKLISTS_URL", "http://localhost:8000")
TIMEOUT = float(os.environ.get("CHECKLISTS_TIMEOUT", "30"))
KEY = os.environ.get("CHECKLISTS_API_KEY", "")
KEY_FILE = os.environ.get("CHECKLISTS_API_KEY_FILE", "")


def _load_key() -> str:
    """The API key: from CHECKLISTS_API_KEY_FILE when set, else the env var."""
    if KEY_FILE:
        try:
            with open(os.path.expanduser(KEY_FILE), encoding="utf-8") as f:
                key = f.read().strip()
        except OSError as e:
            # Never echo the file content; the path and the OS reason are enough.
            raise RuntimeError(f"cannot read CHECKLISTS_API_KEY_FILE: {e.strerror}") from None
        if not key:
            raise RuntimeError("CHECKLISTS_API_KEY_FILE is empty")
        return key
    return KEY


def _key_file_warning() -> str | None:
    """POSIX only: a key file that other users can read is worth a warning."""
    if not KEY_FILE or os.name == "nt":
        return None
    try:
        mode = os.stat(os.path.expanduser(KEY_FILE)).st_mode & 0o777
    except OSError:
        return None
    if mode & 0o077:
        return (f"warning: {KEY_FILE} is accessible by other users "
                f"(mode {mode:04o}); run chmod 600 on it")
    return None


def _api(method: str, path: str, body: dict | None = None) -> str:
    req = urllib.request.Request(
        f"{URL}{path}",
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {_load_key()}", "Content-Type": "application/json"},
        method=method,
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read().decode()


TOOLS = [
    {
        "name": "list_lists",
        "description": "List the checklists the API key can access.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "get_list",
        "description": "Get the items of a list. Set unchecked_only to focus on what remains to do.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "list_id": {"type": "string"},
                "unchecked_only": {"type": "boolean", "default": False},
            },
            "required": ["list_id"],
        },
    },
    {
        "name": "add_items",
        "description": "Add items to a list. One line in `text` = one item.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "list_id": {"type": "string"},
                "text": {"type": "string", "description": "One item per line"},
            },
            "required": ["list_id", "text"],
        },
    },
    {
        "name": "check_item",
        "description": "Check (or uncheck) an item by id.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "list_id": {"type": "string"},
                "item_id": {"type": "string"},
                "done": {"type": "boolean", "default": True},
            },
            "required": ["list_id", "item_id"],
        },
    },
    {
        "name": "update_item",
        "description": (
            "Edit an item's text, notes, due date or recurrence. Only the fields given are "
            "changed. Cannot check/uncheck (use check_item), delete, or clear a due date."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "list_id": {"type": "string"},
                "item_id": {"type": "string"},
                "label": {"type": "string", "minLength": 1, "maxLength": 2000},
                "notes": {"type": "string"},
                "due_date": {
                    "type": "string",
                    "description": "ISO 8601 date-time with offset, e.g. 2026-11-28T09:00:00+01:00",
                },
                "recurrence": {"type": "string", "enum": ["none", "daily", "weekly", "monthly"]},
            },
            "required": ["list_id", "item_id"],
        },
    },
]

# update_item whitelist: `done`, position, parent and assignee are never
# forwarded, so completion stays on check_item.
UPDATE_FIELDS = ("label", "notes", "due_date", "recurrence")


def _handle(name: str, args: dict) -> str:
    if name == "list_lists":
        return _api("GET", "/lists")
    if name == "get_list":
        flag = "true" if args.get("unchecked_only") else "false"
        return _api("GET", f"/lists/{args['list_id']}/items?unchecked_only={flag}")
    if name == "add_items":
        return _api("POST", f"/lists/{args['list_id']}/items/bulk", {"text": args["text"]})
    if name == "check_item":
        return _api(
            "PATCH",
            f"/lists/{args['list_id']}/items/{args['item_id']}",
            {"done": args.get("done", True)},
        )
    if name == "update_item":
        patch = {k: args[k] for k in UPDATE_FIELDS if args.get(k) is not None}
        if not patch:
            raise ValueError("update_item needs at least one of: " + ", ".join(UPDATE_FIELDS))
        return _api("PATCH", f"/lists/{args['list_id']}/items/{args['item_id']}", patch)
    raise ValueError(f"Unknown tool: {name}")


def _error(req_id, code: int, message: str) -> dict:
    return {"jsonrpc": "2.0", "id": req_id, "error": {"code": code, "message": message}}


def handle_line(line: str) -> dict | None:
    """Process one JSON-RPC line; return the reply, or None when none is due.

    Every error reply carries the id of the request that caused it, so the
    client can settle that request immediately instead of waiting for a
    timeout. Only an unparseable line gets id null (JSON-RPC 2.0, §5).
    Notifications (no "id" member) never get a reply, not even on failure.
    """
    try:
        request = json.loads(line)
    except json.JSONDecodeError as e:
        return _error(None, -32700, f"Parse error: {e}")
    if not isinstance(request, dict):
        return _error(None, -32600, "Invalid Request")
    is_notification = "id" not in request
    req_id = request.get("id")
    method = request.get("method")
    try:
        if method == "initialize":
            result = {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "checklists", "version": "0.1.0"},
            }
        elif method == "tools/list":
            result = {"tools": TOOLS}
        elif method == "tools/call":
            params = request.get("params")
            if not isinstance(params, dict) or not isinstance(params.get("name"), str):
                return None if is_notification else _error(
                    req_id, -32602, "Invalid params: 'name' is required")
            text = _handle(params["name"], params.get("arguments") or {})
            result = {"content": [{"type": "text", "text": text}]}
        elif is_notification:
            return None  # notifications/initialized, cancelled, ...
        else:
            return _error(req_id, -32601, f"Unknown method {method}")
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:500]
        return None if is_notification else _error(
            req_id, -32603, f"HTTP {e.code}: {detail or e.reason}")
    except KeyError as e:
        return None if is_notification else _error(
            req_id, -32602, f"Invalid params: missing {e}")
    except Exception as e:
        return None if is_notification else _error(req_id, -32603, str(e))
    if is_notification:
        return None
    return {"jsonrpc": "2.0", "id": req_id, "result": result}


def main() -> None:
    try:
        key = _load_key()
    except RuntimeError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
    if not key:
        print("CHECKLISTS_API_KEY_FILE (or CHECKLISTS_API_KEY) is not set", file=sys.stderr)
        sys.exit(1)
    warning = _key_file_warning()
    if warning:
        print(warning, file=sys.stderr)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        reply = handle_line(line)
        if reply is not None:
            sys.stdout.write(json.dumps(reply) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
