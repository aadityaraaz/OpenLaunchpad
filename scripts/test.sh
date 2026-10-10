#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift run CoreChecks
swift build --product OpenLaunchpad
binary_dir="$(swift build --show-bin-path)"
"$binary_dir/OpenLaunchpad" --self-test
