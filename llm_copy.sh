#!/bin/bash
# llm_copy.sh: Collects file contents from folders and files,
# optionally grepping for a pattern, adds folder structure at the beginning,
# adds obvious file path headers, compresses unnecessary whitespace,
# copies the result to the clipboard (macOS pbcopy),
# and logs an approximate token count (assuming ~1 token per 4 characters).

set -euo pipefail

PRUNE_DIRS=("node_modules" "venv" ".venv" "build" "__pycache__" ".git")
EXCLUDE_FILES=("*.pyc" "*.log" "*.tmp" "package-lock.json" "go.sum" "*.out" "*env")

usage() {
    echo "Usage: $0 [-p pattern] <folder_or_file> [more folders/files...]"
    exit 1
}

if [ "$#" -eq 0 ]; then
    usage
fi

PATTERN=""
if [ "$1" == "-p" ]; then
    if [ "$#" -lt 3 ]; then
        usage
    fi
    PATTERN="$2"
    shift 2
fi

TMPFILE=$(mktemp /tmp/llm_output.XXXXXX)
TOTAL_CHARS=0

should_exclude() {
    local file="$1"
    local base=$(basename "$file")
    for pattern in "${EXCLUDE_FILES[@]}"; do
        if [[ "$base" == $pattern ]]; then
            return 0
        fi
    done
    return 1
}

print_folder_structure() {
    local dir="$1"
    echo "----- FOLDER STRUCTURE: $dir -----" >> "$TMPFILE"
    FIND_CMD=(find "$dir")
    for d in "${PRUNE_DIRS[@]}"; do
        FIND_CMD+=(-not -path "*/$d/*")
    done
    FIND_CMD+=(-not -name "$(printf " %s " "${EXCLUDE_FILES[@]}" | sed 's/ / -not -name /g')")
    "${FIND_CMD[@]}" | sed "s|$dir||" | tree --fromfile -a --noreport >> "$TMPFILE" 2>/dev/null || \
        "${FIND_CMD[@]}" | sed "s|$dir||" >> "$TMPFILE"
    echo "" >> "$TMPFILE"
}

process_file() {
    local file="$1"
    echo "----- FILE: $file -----" >> "$TMPFILE"
    local content_chars=0
    if file -b "$file" | grep -q "text"; then
        if [ -n "$PATTERN" ]; then
            grep -I "$PATTERN" "$file" 2>/dev/null | \
                sed '/^[[:space:]]*$/d; s/^[[:space:]]\+//; s/[[:space:]]\+$//' >> "$TMPFILE" || true
            content_chars=$(grep -I "$PATTERN" "$file" 2>/dev/null | \
                sed '/^[[:space:]]*$/d; s/^[[:space:]]\+//; s/[[:space:]]\+$//' | \
                iconv -f UTF-8 -t UTF-8 -c | wc -m)
        else
            sed '/^[[:space:]]*$/d; s/[[:space:]]\+$//' "$file" >> "$TMPFILE"
            content_chars=$(sed '/^[[:space:]]*$/d; s/^[[:space:]]\+//; s/[[:space:]]\+$//' "$file" | \
                iconv -f UTF-8 -t UTF-8 -c | wc -m)
        fi
    else
        echo "[Skipping non-text file]" >> "$TMPFILE"
    fi
    echo "" >> "$TMPFILE"
    TOTAL_CHARS=$((TOTAL_CHARS + content_chars))
}

count_files_in_dir() {
    local dir="$1"
    local find_cmd=(find "$dir")
    for d in "${PRUNE_DIRS[@]}"; do
        find_cmd+=(\( -type d -name "$d" -prune \))
        find_cmd+=(-o)
    done
    find_cmd+=(\( -type f)
    for pattern in "${EXCLUDE_FILES[@]}"; do
        find_cmd+=(-not -name "$pattern")
    done
    find_cmd+=(-print0 \))
    "${find_cmd[@]}" | tr -dc '\0' | wc -c
}

TOTAL_FILES=0
for arg in "$@"; do
    if [ -d "$arg" ]; then
        TOTAL_FILES=$((TOTAL_FILES + $(count_files_in_dir "$arg")))
    elif [ -f "$arg" ] && ! should_exclude "$arg"; then
        TOTAL_FILES=$((TOTAL_FILES + 1))
    fi
done

PROCESSED_FILES=0

show_progress() {
    local current="$1"
    local total="$2"
    local percent=$((current * 100 / total))
    echo -ne "Processing files: $current of $total ($percent%)\r"
}

for arg in "$@"; do
    if [ -d "$arg" ]; then
        print_folder_structure "$arg"
    fi
done

for arg in "$@"; do
    if [ -d "$arg" ]; then
        FIND_CMD=(find "$arg")
        for dir in "${PRUNE_DIRS[@]}"; do
            FIND_CMD+=(\( -type d -name "$dir" -prune \))
            FIND_CMD+=(-o)
        done
        FIND_CMD+=(\( -type f)
        for pattern in "${EXCLUDE_FILES[@]}"; do
            FIND_CMD+=(-not -name "$pattern")
        done
        FIND_CMD+=(-print0 \))

        while IFS= read -r -d '' file; do
            process_file "$file"
            PROCESSED_FILES=$((PROCESSED_FILES + 1))
            show_progress "$PROCESSED_FILES" "$TOTAL_FILES"
        done < <("${FIND_CMD[@]}")
    elif [ -f "$arg" ]; then
        if should_exclude "$arg"; then
            echo "Skipping excluded file: $arg" >&2
            continue
        fi
        process_file "$arg"
        PROCESSED_FILES=$((PROCESSED_FILES + 1))
        show_progress "$PROCESSED_FILES" "$TOTAL_FILES"
    else
        echo "Warning: $arg is not a valid file or directory" >&2
    fi
done

echo ""

cat "$TMPFILE" | pbcopy

TOKENS=$(echo "$TOTAL_CHARS / 4" | bc -l | awk '{printf "%d", $1}')
echo "Approx token count: $(printf "%'d" $TOKENS) tokens"

rm "$TMPFILE"