#!/usr/bin/env bash
set -euo pipefail

# Match the Flutter version used for this project's local builds.
flutter_version="3.35.7"
flutter_dir="${TMPDIR:-/tmp}/smart-pocket-flutter-${flutter_version}"

if [ ! -x "${flutter_dir}/bin/flutter" ]; then
  git clone --depth 1 --branch "${flutter_version}" https://github.com/flutter/flutter.git "${flutter_dir}"
fi

export PATH="${flutter_dir}/bin:${PATH}"
flutter --version
flutter config --no-analytics
flutter pub get --enforce-lockfile
flutter build web --release --no-pub
