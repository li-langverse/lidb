"""Embedded engine bridge tests."""

from liorm.embed_engine import engine_ready, probe_engine_ready


def test_probe_engine_ready():
    assert probe_engine_ready()
    assert engine_ready()
