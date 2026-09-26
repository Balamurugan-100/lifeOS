#!/usr/bin/env bash
# Build the LifeOS Android APK: resolve deps, run drift codegen, assemble release APK.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo $ROOT

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found on PATH" >&2
  exit 1
fi

REL_PACKAGES=(
  "packages/core"
  "packages/storage"
  "packages/export"
)

for dir in "$ROOT"/packages/domains/*/; do
  [ -d "$dir" ] || continue
  REL_PACKAGES+=("packages/domains/$(basename "$dir")")
done

echo "==> Resolving dependencies (${#REL_PACKAGES[@]} packages)"
for rel in "${REL_PACKAGES[@]}"; do
  echo "  -> $rel"
  (cd "$ROOT/$rel" && flutter pub get)
done

if [ "${SKIP_CODEGEN:-0}" != "1" ]; then
  CODEGEN_PACKAGES=()
  for rel in "${REL_PACKAGES[@]}"; do
    if grep -rlqE "part '.*\.g\.dart'" "$ROOT/$rel/lib" 2>/dev/null; then
      CODEGEN_PACKAGES+=("$rel")
    fi
  done

  echo "==> Running drift codegen (${#CODEGEN_PACKAGES[@]} packages)"
  for rel in "${CODEGEN_PACKAGES[@]}"; do
    echo "  -> $rel"
    (cd "$ROOT/$rel" && dart run build_runner build --delete-conflicting-outputs)
  done
fi

echo "==> Building Android release APK"
(cd "$ROOT/app" && flutter build apk --release)

APK="$ROOT/app/build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "Build complete."
echo "APK: $APK"
[ -f "$APK" ] && ls -lh "$APK"
