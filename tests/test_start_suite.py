from __future__ import annotations

import builtins
from pathlib import Path
from unittest.mock import mock_open

from fastapi.testclient import TestClient

import start_suite


def test_read_lines_tails_without_loading_unbounded_file(tmp_path: Path) -> None:
    path = tmp_path / "large.log"
    path.write_text("".join(f"line-{idx}\n" for idx in range(100)), encoding="utf-8")

    assert start_suite._read_lines(str(path), 3) == ["line-97\n", "line-98\n", "line-99\n"]


def test_parse_pihole_log_returns_recent_queries(monkeypatch) -> None:
    monkeypatch.setattr(
        start_suite,
        "_read_lines",
        lambda _path, _limit: [
            "Jan  1 12:00:00 dnsmasq[1234]: query[A] example.com from 192.168.1.10\n",
            "Jan  1 12:00:01 dnsmasq[1234]: cached example.com is 93.184.216.34\n",
            "Jan  1 12:00:02 dnsmasq[1234]: query[AAAA] debian.org from 192.168.1.11\n",
        ],
    )

    assert start_suite._parse_pihole_log(2) == [
        {
            "timestamp": "Jan  1 12:00:00",
            "client": "192.168.1.10",
            "query": "example.com",
            "action": "query",
        },
        {
            "timestamp": "Jan  1 12:00:02",
            "client": "192.168.1.11",
            "query": "debian.org",
            "action": "query",
        },
    ]


def test_read_pihole_v6_upstreams_from_dns_section(monkeypatch) -> None:
    content = """
[other]
upstreams = ["ignored"]

[dns]
upstreams = ["127.0.0.1#5335", "1.1.1.1#53"]
"""
    opener = mock_open(read_data=content)
    monkeypatch.setattr(builtins, "open", opener)

    assert start_suite._read_pihole_v6_upstreams() == ["127.0.0.1#5335", "1.1.1.1#53"]


def test_health_requires_api_key(monkeypatch) -> None:
    monkeypatch.setenv("SUITE_API_KEY", "secret")
    client = TestClient(start_suite.app)

    assert client.get("/health").status_code == 401
    response = client.get("/health", headers={"X-API-Key": "secret"})

    assert response.status_code == 200
    assert response.json()["ok"] is True
