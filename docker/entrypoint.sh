#!/bin/sh
# Entrypoint for the stanford-stages container.
#
# Usage:
#   docker run ...                       # runs stanford_stages.docker.json
#   docker run ... <path/to/config.json> # runs a specific config
#   docker run ... python <script>       # drop into an arbitrary command

if [ "$1" = "python" ] || [ "$1" = "python3" ] || [ "$1" = "sh" ] || [ "$1" = "bash" ]; then
    exec "$@"
fi

JSON_FILE="${1:-/app/stanford_stages.docker.json}"

if [ ! -f "$JSON_FILE" ]; then
    printf '\nError: configuration file not found: %s\n' "$JSON_FILE" >&2
    printf 'Mount it with -v or pass its container path as the first argument.\n' >&2
    exit 1
fi

printf 'Stanford Stages: running with config %s\n' "$JSON_FILE"
exec python run_stanford_stages.py "$JSON_FILE"
