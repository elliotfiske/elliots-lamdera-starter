#!/usr/bin/env bash
# PostToolUse hook: run elm-review after edits to .elm files.
# Receives tool-use JSON on stdin.

set -euo pipefail

INPUT=$(cat)

# Extract the file_path from the tool input (Edit / Write / NotebookEdit)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ti = data.get('tool_input', {})
print(ti.get('file_path', ''))
" 2>/dev/null || true)

# Only act on .elm files
if [[ "$FILE_PATH" != *.elm ]]; then
  exit 0
fi

# Determine project root: walk up from the file until we find elm.json
DIR=$(dirname "$FILE_PATH")
while [[ "$DIR" != "/" ]]; do
  if [[ -f "$DIR/elm.json" ]]; then
    break
  fi
  DIR=$(dirname "$DIR")
done

if [[ ! -f "$DIR/elm.json" ]]; then
  echo "elm-review: could not find elm.json for $FILE_PATH" >&2
  exit 0
fi

# Run elm-review from the project root (plain-text output)
cd "$DIR"
if OUTPUT=$(elm-review 2>&1); then
  echo "elm-review: no errors." >&2
  exit 0
fi

# elm-review found errors — print its output and block the tool use
echo "$OUTPUT" >&2
exit 2
