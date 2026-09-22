#!/usr/bin/env bash
# Bootstrap the LifeOS monorepo: resolve dependencies and run drift codegen.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> packages/core"
(cd "$ROOT/packages/core" && flutter pub get)

echo "==> packages/storage"
(cd "$ROOT/packages/storage" && flutter pub get && dart run build_runner build --delete-conflicting-outputs)

echo "==> packages/domains/tasks"
(cd "$ROOT/packages/domains/tasks" && flutter pub get && dart run build_runner build --delete-conflicting-outputs)

echo "==> packages/domains/habits"
(cd "$ROOT/packages/domains/habits" && flutter pub get && dart run build_runner build --delete-conflicting-outputs)

echo "==> packages/export"
(cd "$ROOT/packages/export" && flutter pub get)

echo "==> app"
(cd "$ROOT/app" && flutter pub get)

echo "Bootstrap complete."