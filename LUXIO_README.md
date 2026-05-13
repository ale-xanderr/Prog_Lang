# Luxio — Lexical Analyzer

## Full-Stack Setup

### 1. Prerequisites
```bash
sudo apt install flex gcc
pip install fastapi uvicorn
```

### 2. Compile the Flex Lexer
```bash
flex lexer.l
gcc lex.yy.c -o lexer -lfl
```

### 3. Start the FastAPI Backend
```bash
uvicorn backend_main:app --host 0.0.0.0 --port 8765
```

### 4. Open the Frontend
Open `luxio.html` in your browser.

---

## Architecture

```
Browser (luxio.html)
  └── React Frontend
        └── POST /analyze → FastAPI (backend_main.py)
              └── subprocess → ./lexer (Flex binary)
                    └── JSON token output
```

## Token Types Recognized
| Type | Example | Color |
|------|---------|-------|
| KEYWORD | `if`, `int`, `return` | Purple |
| IDENTIFIER | `myVar`, `main` | Blue |
| INT_LITERAL | `42` | Green |
| FLOAT_LITERAL | `3.14` | Teal |
| STRING_LITERAL | `"hello"` | Amber |
| OPERATOR | `+`, `==`, `&&` | Cyan |
| DELIMITER | `(`, `{`, `;` | Gray |
| COMMENT | `// ...` | Dark |
| INVALID_TOKEN | `@` `$` | Red |

## Features
- Real-time line-numbered code editor
- Token table with type, lexeme, line#, description
- Visual render with hover tooltips per token
- Token distribution stats with clickable filters
- Search and filter controls
- Red alert on invalid tokens
- Ctrl+Enter hotkey to analyze
- Sample code presets
