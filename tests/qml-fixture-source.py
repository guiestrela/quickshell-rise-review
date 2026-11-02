#!/usr/bin/env python3
"""Print an inert source view for shell assertions on shared QML methods."""
import sys
from qml_fixture_source import qml_fixture_text
sys.stdout.write(qml_fixture_text(sys.argv[1]))
