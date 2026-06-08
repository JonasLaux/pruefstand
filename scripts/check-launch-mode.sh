#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

swiftc \
    Sources/Pruefstand/LaunchMode.swift \
    Sources/Pruefstand/PRActions.swift \
    Tests/LaunchModeChecks/main.swift \
    -o .build/launch-mode-check

.build/launch-mode-check

swiftc \
    Sources/Pruefstand/Labels.swift \
    Tests/TagFilterChecks/main.swift \
    -o .build/tag-filter-check

.build/tag-filter-check

swiftc \
    Sources/Pruefstand/LaunchMode.swift \
    Sources/Pruefstand/PRActions.swift \
    Tests/ActionModeChecks/main.swift \
    -o .build/action-mode-check

.build/action-mode-check

swiftc \
    Sources/Pruefstand/Labels.swift \
    Sources/Pruefstand/PRActions.swift \
    Sources/Pruefstand/Settings.swift \
    Tests/SettingsChecks/main.swift \
    -o .build/settings-check

.build/settings-check

swiftc \
    Sources/Pruefstand/Models.swift \
    Sources/Pruefstand/Labels.swift \
    Sources/Pruefstand/PRActions.swift \
    Sources/Pruefstand/Settings.swift \
    Sources/Pruefstand/IgnoredPullRequests.swift \
    Sources/Pruefstand/PRStore.swift \
    Tests/IgnoreChecks/main.swift \
    -o .build/ignore-check

.build/ignore-check

swiftc \
    Sources/Pruefstand/Models.swift \
    Sources/Pruefstand/Labels.swift \
    Sources/Pruefstand/PRCommand.swift \
    Tests/NudgeCommandChecks/main.swift \
    -o .build/nudge-command-check

.build/nudge-command-check

swiftc \
    Sources/Pruefstand/Models.swift \
    Sources/Pruefstand/Labels.swift \
    Sources/Pruefstand/PRCommand.swift \
    Tests/CommandRunnerChecks/main.swift \
    -o .build/command-runner-check

.build/command-runner-check
