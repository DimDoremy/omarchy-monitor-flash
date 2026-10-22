#!/bin/bash

# Everything the marketplace will check, plus the parts only a running shell
# can answer. Run from the repository root.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== manifest =="
omarchy plugin validate .

echo "== QML syntax =="
qmllint -I "${OMARCHY_PATH:-/usr/share/omarchy}/shell" -I /usr/lib/qt6/qml \
  MonitorFlash.qml MonitorCard.qml

echo "== label logic =="
node --test tests/monitor-label.test.cjs

echo "ok"
