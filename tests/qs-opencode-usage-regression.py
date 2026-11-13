#!/usr/bin/env python3
"""Regression tests for OpenCode's changing local SQLite schema."""
from __future__ import annotations

import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
COLLECTOR = ROOT / "scripts/opencode-usage"


def run_collector(seed_database):
    with tempfile.TemporaryDirectory(prefix="rise-opencode-usage-") as temp:
        base = Path(temp)
        home = base / "home"
        data_dir = base / "opencode-data"
        home.mkdir()
        data_dir.mkdir()
        db_path = data_dir / "opencode.db"
        seed_database(db_path)
        env = dict(os.environ)
        env.update({
            "HOME": str(home),
            "OPENCODE_DATA_DIR": str(data_dir),
            "OPENCODE_USAGE_5H_LIMIT": "1000",
            "OPENCODE_USAGE_7D_LIMIT": "5000",
        })
        result = subprocess.run(
            [sys.executable, str(COLLECTOR)],
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0, result.stderr
        cache = home / ".cache/opencode-usage.json"
        assert cache.is_file(), "collector produced no cache for a readable database"
        return json.loads(cache.read_text(encoding="utf-8"))


def seed_current_schema(path: Path) -> None:
    now = int(time.time() * 1000)
    con = sqlite3.connect(path)
    try:
        con.execute("""
            create table session_message (
                id text primary key,
                session_id text not null,
                type text not null,
                seq integer not null,
                time_created integer not null,
                time_updated integer not null,
                data text not null
            )
        """)
        assistant = {
            "model": {"id": "gpt-4.1", "providerID": "openai"},
            "tokens": {"input": 100, "output": 50, "reasoning": 10,
                       "cache": {"read": 200, "write": 5}},
            "cost": 0.03,
            "time": {"created": now, "completed": now},
        }
        con.execute(
            "insert into session_message values (?, ?, ?, ?, ?, ?, ?)",
            ("m1", "s1", "assistant", 1, now, now,
             json.dumps(assistant)),
        )
        user = {"time": {"created": now, "completed": now}}
        con.execute(
            "insert into session_message values (?, ?, ?, ?, ?, ?, ?)",
            ("m2", "s1", "user", 2, now, now, json.dumps(user)),
        )
        con.commit()
    finally:
        con.close()


def seed_legacy_schema(path: Path) -> None:
    now = int(time.time() * 1000)
    con = sqlite3.connect(path)
    try:
        con.execute("""
            create table message (
                session_id text not null,
                time_created integer not null,
                time_updated integer not null,
                data text not null
            )
        """)
        assistant = {
            "role": "assistant",
            "modelID": "gpt-4.1",
            "providerID": "openai",
            "tokens": {"input": 100, "output": 50, "reasoning": 10,
                       "cache": {"read": 200, "write": 5}},
            "cost": 0.03,
        }
        con.execute(
            "insert into message values (?, ?, ?, ?)",
            ("s1", now, now, json.dumps(assistant)),
        )
        con.commit()
    finally:
        con.close()


def verify_usage(data: dict) -> None:
    assert data["_source"] == "sqlite", data
    assert data["_model"] == "gpt-4.1 (openai)", data
    assert data["_tokens_used"] == 165, data
    assert data["_tokens_used_with_cache_read"] == 365, data
    assert data["_today_tokens"] == 165, data
    assert data["5h-utilization"] == "0.1650", data
    assert data["7d-utilization"] == "0.0330", data
    assert data["_models"][0]["name"] == "gpt-4.1 (openai)", data


def verify_unknown_schema_fails() -> None:
    with tempfile.TemporaryDirectory(prefix="rise-opencode-unsupported-schema-") as temp:
        base = Path(temp)
        home = base / "home"
        data_dir = base / "opencode-data"
        home.mkdir()
        data_dir.mkdir()
        con = sqlite3.connect(data_dir / "opencode.db")
        try:
            con.execute("create table unrelated (id integer)")
            con.commit()
        finally:
            con.close()
        env = dict(os.environ)
        env.update({"HOME": str(home), "OPENCODE_DATA_DIR": str(data_dir)})
        result = subprocess.run(
            [sys.executable, str(COLLECTOR)], env=env,
            capture_output=True, text=True, check=False,
        )
        assert result.returncode != 0, "unsupported database schema was reported as success"
        assert "OpenCode message table not found" in result.stderr, result.stderr


def main() -> None:
    verify_usage(run_collector(seed_current_schema))
    verify_usage(run_collector(seed_legacy_schema))
    verify_unknown_schema_fails()
    print("OPENCODE_USAGE_SCHEMA_PASS current, legacy, and unsupported schemas")


if __name__ == "__main__":
    main()
