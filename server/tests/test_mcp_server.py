"""update_item tool: field whitelist, never forwards completion state."""
import json

import mcp_server


def call(name, **arguments):
    msg = {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
           "params": {"name": name, "arguments": arguments}}
    return mcp_server.handle_line(json.dumps(msg))


def test_update_item_is_listed():
    names = [t["name"] for t in mcp_server.TOOLS]
    assert "update_item" in names


def test_update_item_forwards_only_whitelisted_fields(monkeypatch):
    seen = {}
    def fake(method, path, body=None):
        seen.update(method=method, path=path, body=body)
        return "[]"
    monkeypatch.setattr(mcp_server, "_api", fake)
    resp = call("update_item", list_id="L", item_id="I", label="New", notes="n",
                done=True, position=3, parent_id="P", recurrence="weekly")
    assert "result" in resp
    assert seen["method"] == "PATCH" and seen["path"] == "/lists/L/items/I"
    assert seen["body"] == {"label": "New", "notes": "n", "recurrence": "weekly"}


def test_update_item_without_fields_is_rejected(monkeypatch):
    monkeypatch.setattr(mcp_server, "_api", lambda *a, **k: (_ for _ in ()).throw(AssertionError("no call")))
    resp = call("update_item", list_id="L", item_id="I", done=True)
    assert resp["error"]["code"] == -32603
    assert "at least one" in resp["error"]["message"]
