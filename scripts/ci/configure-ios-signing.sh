#!/usr/bin/env bash

# Toggles code signing in the generated Xcode project so `tauri ios build` can
# produce a bundle without an Apple developer account. The signed TestFlight
# pipeline still needs the real identity, so the committed project keeps it.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTION="${1:-}"

if [[ "${ACTION}" != "enable" && "${ACTION}" != "disable" ]]; then
    echo "Usage: $0 <enable|disable>" >&2
    exit 1
fi

PBXPROJ="${ROOT_DIR}/src-tauri/crates/tauritavern/gen/apple/tauritavern.xcodeproj/project.pbxproj"

[[ -f "${PBXPROJ}" ]] || { echo "Missing file: ${PBXPROJ}" >&2; exit 1; }

SIGNED=$'\t\t\t\tCODE_SIGN_IDENTITY = "iPhone Developer";\n'
UNSIGNED=$'\t\t\t\tCODE_SIGN_IDENTITY = "";\n\t\t\t\tCODE_SIGNING_ALLOWED = NO;\n\t\t\t\tCODE_SIGNING_REQUIRED = NO;\n'

contains_block() {
    TT_TEXT="$2" perl -0ne 'exit(index($_, $ENV{"TT_TEXT"}) >= 0 ? 0 : 1)' "$1"
}

# The identity is declared once per build configuration, so every occurrence has
# to move together or the project stops parsing.
replace_all() {
    local from="$1"
    local to="$2"

    contains_block "${PBXPROJ}" "${from}" || { echo "expected signing block not found" >&2; exit 1; }
    TT_FROM="${from}" TT_TO="${to}" perl -0pi -e '
        BEGIN {
            $from = $ENV{"TT_FROM"};
            $to = $ENV{"TT_TO"};
        }
        index($_, $from) >= 0 or die "expected source text not found\n";
        s/\Q$from\E/$to/g;
    ' "${PBXPROJ}"
}

if [[ "${ACTION}" == "enable" ]]; then
    contains_block "${PBXPROJ}" "${UNSIGNED}" || replace_all "${SIGNED}" "${UNSIGNED}"
    expected="${UNSIGNED}"
else
    contains_block "${PBXPROJ}" "${SIGNED}" || replace_all "${UNSIGNED}" "${SIGNED}"
    expected="${SIGNED}"
fi

contains_block "${PBXPROJ}" "${expected}" || { echo "signing toggle did not apply" >&2; exit 1; }
echo "iOS code signing ${ACTION}d"
