"""Shared pytest fixtures for native embed engine."""

import pytest

from liorm.embed_engine import reset_session_for_tests, seed_test_fixtures


@pytest.fixture(autouse=True)
def _fresh_embed_session():
    reset_session_for_tests()
    seed_test_fixtures()
    yield
    reset_session_for_tests()
