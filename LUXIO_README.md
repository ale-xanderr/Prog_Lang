# Luxio — Interactive Lexical Analyzer

A full-stack interactive lexical analyzer built on GNU Flex, FastAPI, and React. Luxio takes raw C-family source code, runs it through a compiled finite automaton, and renders the token stream in a dark glassmorphism UI with real-time filtering, color-coded type tags, and hover tooltips.

---

## Overview

Luxio makes the lexical analysis phase of compilation **visible and interactive**. Type or paste any C/C++ code into the editor, click **Analyze**, and watch every identifier, keyword, literal, operator, and delimiter get classified and annotated — including invalid tokens flagged with a red alert.

---

## Features

- **Real Flex Engine** — grammar compiles to a native C binary (DFA), not a regex loop
- **Full Token Classification** — 15 distinct token types with descriptions
- **Live Token Table** — line number, lexeme, color-coded type chip, and description per token
- **Visual Code Render** — original source re-rendered with color-highlighted token spans
- **Hover Tooltips** — hover any token in the render view to see its type and description inline
- **Token Distribution Panel** — clickable bar chart per token type; click to filter the table
- **Search & Filter** — search by lexeme or type; filter dropdown to a single token type
- **Error Detection** — `INVALID_TOKEN` triggers a red alert banner; error rows highlighted in table
- **Sample Programs** — three presets: Hello World, Fibonacci, and a snippet with intentional errors
- **Keyboard Shortcut** — `Ctrl+Enter` / `Cmd+Enter` to trigger analysis from the editor
- **Zero Build Step** — frontend is a single HTML file, opens directly in any browser

---

## Architecture

```
Browser (luxio.html)
    └── POST /analyze  ──►  FastAPI (main.py)
                                 └── subprocess  ──►  ./lexer  (Flex + gcc)
                                                          └── JSON token stream
```

| Layer    | Technology           | Role                                        |
|----------|----------------------|---------------------------------------------|
| Engine   | GNU Flex + GCC       | Compiles `.l` grammar to DFA binary         |
| Bridge   | Python + FastAPI     | HTTP API, subprocess management, enrichment |
| Frontend | React + Tailwind CSS | UI rendering, state, interactivity          |

---

## Token Types

| Token Type     | Description                  | Example Lexemes                |
|----------------|------------------------------|--------------------------------|
| KEYWORD        | Reserved language keyword    | `if`, `int`, `return`, `class` |
| IDENTIFIER     | User-defined name            | `main`, `myVar`, `fibonacci`   |
| INT_LITERAL    | Integer constant             | `0`, `42`, `255`               |
| FLOAT_LITERAL  | Floating-point constant      | `3.14`, `0.5`                  |
| STRING_LITERAL | String constant              | `"hello"`, `"world\n"`         |
| CHAR_LITERAL   | Character constant           | `'a'`, `'\n'`                  |
| BOOLEAN        | Boolean literal              | `true`, `false`                |
| NULL_LITERAL   | Null pointer literal         | `null`, `NULL`, `nullptr`      |
| OPERATOR       | Arithmetic/logical operator  | `+`, `==`, `&&`, `->`, `::`    |
| DELIMITER      | Punctuation delimiter        | `(`, `{`, `;`, `,`             |
| COMMENT        | Source code comment          | `// ...`, `/* ... */`          |
| PREPROCESSOR   | Preprocessor `#` symbol      | `#`                            |
| DIRECTIVE      | Preprocessor directive word  | `include`, `define`, `ifdef`   |
| HEADER         | Angle-bracket include path   | `<stdio.h>`, `<iostream>`      |
| INVALID_TOKEN  | Unrecognized lexical element | `@`, `$`, `` ` ``              |

---

## Installation

### Prerequisites

| Tool   | Version | Purpose                       |
|--------|---------|-------------------------------|
| Python | 3.8+    | FastAPI runtime               |
| GCC    | any     | Compile Flex output to binary |
| Flex   | 2.6+    | Generate the lexer C source   |

### Linux (Ubuntu / Debian)

```bash
sudo apt update && sudo apt install -y flex gcc
pip install fastapi uvicorn
```

### Linux (Fedora / RHEL)

```bash
sudo dnf install flex gcc
pip install fastapi uvicorn
```

### macOS

```bash
brew install flex
pip install fastapi uvicorn
```

### Windows

Install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) and follow the Ubuntu instructions above.

---

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/luxio.git
cd luxio
```

### 2. Compile the Flex Lexer

```bash
cd backend
flex lexer.l
gcc lex.yy.c -o lexer -lfl
```

Verify it works:

```bash
echo "int main() { return 0; }" | ./lexer
```

Expected output (one JSON object per line):

```json
{"line":1,"token":"int","type":"KEYWORD"}
{"line":1,"token":"main","type":"IDENTIFIER"}
{"line":1,"token":"(","type":"DELIMITER"}
{"line":1,"token":")","type":"DELIMITER"}
{"line":1,"token":"{","type":"DELIMITER"}
{"line":1,"token":"return","type":"KEYWORD"}
{"line":1,"token":"0","type":"INT_LITERAL"}
{"line":1,"token":";","type":"DELIMITER"}
{"line":1,"token":"}","type":"DELIMITER"}
```

### 3. Start the FastAPI Backend

```bash
uvicorn main:app --host 0.0.0.0 --port 8765
```

Confirm it is alive:

```bash
curl http://localhost:8765/health
# → {"status":"ok","lexer":true}
```

### 4. Open the Frontend

Open `luxio.html` directly in any modern browser:

```bash
# macOS
open frontend/luxio.html

# Linux
xdg-open frontend/luxio.html

# Windows
start frontend/luxio.html
```

---

## API Reference

### `POST /analyze`

Tokenize a source code string.

**Request body:**

```json
{
    "code": "int main() { return 0; }"
}
```

**Response:**

```json
{
    "tokens": [
        {
            "line": 1,
            "token": "int",
            "type": "KEYWORD",
            "description": "Reserved language keyword"
        },
        {
            "line": 1,
            "token": "main",
            "type": "IDENTIFIER",
            "description": "User-defined name"
        }
    ],
    "has_errors": false
}
```

**Error token** (when `has_errors` is `true`):

```json
{
    "line": 2,
    "token": "@",
    "type": "INVALID_TOKEN",
    "error": true,
    "description": "Unrecognized token — lexical error"
}
```

**Status codes:**

| Code | Meaning                                |
|------|----------------------------------------|
| 200  | Success (even if `has_errors` is true) |
| 408  | Lexer process timed out (10s limit)    |
| 500  | Lexer binary not found on disk         |

---

### `GET /health`

Check server and binary status.

**Response:**

```json
{
    "status": "ok",
    "lexer": true
}
```

`lexer: false` means the binary is missing or was not compiled.

---

## Usage Examples

### Analyze via curl

```bash
curl -X POST http://localhost:8765/analyze \
     -H "Content-Type: application/json" \
     -d '{"code": "float pi = 3.14; // pi constant"}'
```

### Analyze via Python

```python
import requests

code = """
int fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}
"""

response = requests.post("http://localhost:8765/analyze", json={"code": code})
data = response.json()

for token in data["tokens"]:
    print(f"Line {token['line']:2d}  {token['type']:16s}  {token['token']}")
```

### Filter Tokens by Type

```python
tokens = data["tokens"]

keywords    = [t for t in tokens if t["type"] == "KEYWORD"]
identifiers = [t for t in tokens if t["type"] == "IDENTIFIER"]
errors      = [t for t in tokens if t["type"] == "INVALID_TOKEN"]

print(f"Keywords:    {[t['token'] for t in keywords]}")
print(f"Identifiers: {[t['token'] for t in identifiers]}")
print(f"Errors:      {len(errors)}")
```

### Save Token Output to JSON

```python
import json, requests

resp = requests.post("http://localhost:8765/analyze",
                     json={"code": open("source.c").read()})

with open("tokens.json", "w") as f:
    json.dump(resp.json(), f, indent=2)
```

---

## Project Structure

```
luxio/
├── README.md                  # This file
├── CODE_EXPLANATION.md        # Deep technical breakdown of every component
├── backend/
│   ├── lexer.l                # Flex grammar source
│   ├── lex.yy.c               # Generated by flex (do not edit manually)
│   ├── lexer                  # Compiled binary (generated by gcc)
│   └── main.py                # FastAPI application
└── frontend/
    └── luxio.html             # Self-contained React frontend
```

---

## Troubleshooting

**`"Cannot reach backend"` banner in the UI**

The FastAPI server is not running. Start it:

```bash
cd backend && uvicorn main:app --port 8765
```

---

**`{"status":"ok","lexer":false}` from `/health`**

The `lexer` binary is missing. Recompile:

```bash
cd backend
flex lexer.l && gcc lex.yy.c -o lexer -lfl
```

---

**`error while loading shared libraries: libfl.so`**

Install the Flex development libraries:

```bash
# Ubuntu/Debian
sudo apt install libfl-dev

# Fedora
sudo dnf install flex-devel
```

---

**Port 8765 already in use**

```bash
# Kill the existing process
kill $(lsof -t -i:8765)

# Or start on a different port (update BACKEND_URL in luxio.html too)
uvicorn main:app --port 9000
```

---

**Tokens appear on wrong lines**

Ensure line endings are Unix-style (`\n`). Convert Windows `\r\n` line endings first:

```bash
dos2unix source.c
```

---

## How It Works (Summary)

1. User types C/C++ code into the browser editor
2. On clicking **Analyze**, the React app sends the code as JSON to `POST /analyze`
3. FastAPI pipes the code string into the `./lexer` binary via `subprocess`
4. The Flex binary applies its DFA state machine, emitting one JSON token object per line
5. FastAPI reads stdout line by line, parses each JSON object, and enriches it with a description
6. The enriched token array is returned to the browser as a JSON response
7. React renders the token table, updates the stats panel, and re-renders the visual code view

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/NewTokenType`
3. Test the lexer directly: `echo "your code" | ./backend/lexer`
4. Verify the API response is correct
5. Commit and open a Pull Request

**Ideas for contributions:**

- Add Python comment syntax (`#`) and keyword support
- Add a Java keyword set with a language selector dropdown
- Token output export to CSV or downloadable JSON
- Light theme toggle

---

## License

MIT License. See `LICENSE` for details.

---

## Author

Created as a full-stack compiler tools demonstration project.

**Stack:** GNU Flex · GCC · Python 3 · FastAPI · React 18

---

## Version History

### Version 1.0 (Current)

- Initial release
- C/C++ lexical analysis via compiled Flex DFA
- 15 token types with color coding and descriptions
- FastAPI subprocess bridge with timeout and error handling
- React glassmorphism frontend with no build step required
- Token table, visual render view, and stats distribution panel
- Search, filter, and three sample code presets
- Invalid token detection with red alert UI and highlighted error rows
