"""Test configuration: force headless drivers before anything imports pygame."""

import os

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
os.environ.setdefault("BIG_RIG_HORIZON_NO_SPEECH", "1")
os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")

import pytest


@pytest.fixture(autouse=True)
def isolated_data_dir(tmp_path, monkeypatch):
    """Keep saves and settings out of the real user data directory."""
    monkeypatch.setenv("BIG_RIG_HORIZON_DATA_DIR", str(tmp_path / "data"))
    yield


@pytest.fixture(scope="session")
def world():
    from big_rig_horizon.data import get_world

    return get_world()
