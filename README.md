# llm_copy

A Bash script to collect file contents from folders or files, optionally grep for patterns, add file path headers, compress whitespace, copy results to the clipboard (macOS), and estimate token counts (~1 token per 4 characters). Perfect for feeding code to LLMs or quick analysis.

## Features
- Processes directories or individual files.
- Filters with `-p <pattern>` (grep).
- Excludes common junk (e.g., `node_modules`, `*.pyc`).
- Adds clear file headers (e.g., `----- FILE: path/to/file -----`).
- Copies output to clipboard (`pbcopy` on macOS).
- Shows progress and token estimate.
- Displays folder structure hierarchically.

## Prerequisites
- Bash (tested on macOS).
- `pbcopy` (macOS; modify for other OSes).

## Installation
1. Clone the repo:
   ```bash
   git clone https://github.com/yourusername/llm_copy.git
   ```
2. Make it executable:
   ```bash
   chmod +x llm_copy.sh
   ```

## Usage
```bash
./llm_copy.sh [-p pattern] <folder_or_file> [more folders/files...]
```
- `-p <pattern>`: Grep for lines matching `<pattern>`.
- `<folder_or_file>`: Target directory or file.

## Examples
1. **Copy all files in current directory:**
   ```bash
   ./llm_copy.sh .
   ```
   Output includes folder structure and file contents, copied to clipboard.

2. **Grep for "error" in a folder:**
   ```bash
   ./llm_copy.sh -p error src/
   ```
   Copies only lines with "error" from `src/`.

3. **Process specific files:**
   ```bash
   ./llm_copy.sh main.py utils.py
   ```
   Copies contents of `main.py` and `utils.py`.

## Output Sample
```
----- FOLDER STRUCTURE: . -----
.
main.py
utils.py

----- FILE: ./main.py -----
print("Hello, world!")

----- FILE: ./utils.py -----
def add(a, b):
    return a + b
```
(Token count displayed in terminal.)

## Configuration
- Edit `PRUNE_DIRS` to skip directories (e.g., `.git`).
- Edit `EXCLUDE_FILES` to ignore file patterns (e.g., `*.log`).

## Contributing
Feel free to contribute! Open issues, submit PRs, or suggest features. Help make `llm_copy` better for everyone.

## License
MIT License - see [LICENSE](LICENSE) for details.

---