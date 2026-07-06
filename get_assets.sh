#!/bin/sh
# Download the assets required to run stanford-stages:
#   - the LSTM hypnodensity models (ac.zip, ~770 MiB -> ml/ac/)
#   - the sample CHP040.edf recording (~399 MiB -> data/input/)
#
# Run from anywhere; all paths are relative to the repository root
# (this script's directory).
#
# Usage:
#   ./get_assets.sh             # download both models and sample EDF
#   ./get_assets.sh models      # models only
#   ./get_assets.sh edf         # sample EDF only
#   ./get_assets.sh --force     # re-download even if already present
#
# Re-running is safe: existing files are skipped unless --force is given.

set -eu

# All paths are relative to the repository root (this script's directory).
cd "$(dirname "$0")"

MODELS_URL="https://www.informaton.org/narco/ml/ac.zip"
EDF_URL="https://stanfordmedicine.box.com/shared/static/0lvvyaprzinzz7dult87t7hr96s2dnqq.edf"
EDF_NAME="CHP040.edf"

FORCE=0
TARGET=all
for arg in "$@"; do
    case "$arg" in
        models) TARGET=models ;;
        edf)    TARGET=edf ;;
        all)    TARGET=all ;;
        --force|-f) FORCE=1 ;;
        *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

log()  { printf '\n%s\n' "$*"; }
note() { printf '  %s\n' "$*"; }
die()  { printf '\nError: %s\n' "$*" >&2; exit 1; }

require() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not found in PATH."
}

download_models() {
    [ "$TARGET" = models ] || [ "$TARGET" = all ] || return 0
    require curl
    require unzip
    mkdir -p ml
    count=0
    if [ -d ml/ac ]; then
        count=$(find ml/ac -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
    fi
    if [ "$count" -ge 16 ] && [ "$FORCE" -eq 0 ]; then
        note "ml/ac/ already has $count model directories; skipping. (use --force to re-download)"
        return 0
    fi
    log "Downloading LSTM models (~770 MiB) from"
    note "$MODELS_URL"
    if [ "$FORCE" -eq 1 ]; then rm -rf ml/ac; fi
    curl -L --retry 3 --connect-timeout 30 -o ml/ac.zip "$MODELS_URL" \
        || die "failed to download the models archive"
    note "extracting ml/ac.zip ..."
    (cd ml && unzip -q ac.zip) || die "failed to extract ml/ac.zip"
    rm -f ml/ac.zip
    count=$(find ml/ac -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
    [ "$count" -ge 16 ] || die "expected at least 16 model directories under ml/ac/, found $count"
    note "Done. $count model directories present in ml/ac/"
}

download_edf() {
    [ "$TARGET" = edf ] || [ "$TARGET" = all ] || return 0
    require curl
    mkdir -p data/input
    dest="data/input/$EDF_NAME"
    if [ -s "$dest" ] && [ "$FORCE" -eq 0 ]; then
        note "$dest already exists; skipping. (use --force to re-download)"
        return 0
    fi
    log "Downloading sample recording $EDF_NAME (~399 MiB) from"
    note "$EDF_URL"
    curl -L --retry 3 --connect-timeout 30 -o "$dest" "$EDF_URL" \
        || die "failed to download the sample EDF"
    [ -s "$dest" ] || die "$dest is empty after download"
    note "Done. $(du -h "$dest" | cut -f1) written to $dest"
}

download_models
download_edf

log "All requested assets are in place."
