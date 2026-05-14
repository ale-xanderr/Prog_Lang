# Code Explanation: Luxio — Lexical Analyzer

This document provides a detailed explanation of how Luxio works, breaking down each component across the full three-layer stack: the Flex grammar engine, the FastAPI Python bridge, and the React frontend.

---

## Table of Contents

1. [Overview](#overview)
2. [Core Concepts](#core-concepts)
3. [Architecture](#architecture)
4. [Layer 1 — The Flex Lexer (`lexer.l`)](#layer-1--the-flex-lexer-lexerl)
5. [Layer 2 — The FastAPI Bridge (`main.py`)](#layer-2--the-fastapi-bridge-mainpy)
6. [Layer 3 — The React Frontend (`luxio.html`)](#layer-3--the-react-frontend-luxiohtml)
7. [Token Types Reference](#token-types-reference)
8. [Tokenization Process (End-to-End)](#tokenization-process-end-to-end)
9. [Error Handling](#error-handling)
10. [Example Walkthrough](#example-walkthrough)
11. [Complexity Analysis](#complexity-analysis)

---

## Overview

Luxio is a full-stack interactive lexical analyzer. It takes raw C-family source code as input and decomposes it into a structured list of **tokens** — the smallest meaningful units of a program. Each token is annotated with its type, lexeme, line number, and a human-readable description.

**Key Purpose:** Make the lexical analysis phase of compilation visible and interactive, with a professional dark glassmorphism UI that renders token data in real time.

**Stack at a Glance:**

```
Browser (React UI)
    └── POST /analyze → FastAPI (Python)
              └── subprocess → Flex binary (C)
                        └── JSON token stream → response
```

---

## Core Concepts

### What Is a Token?

A token is the smallest meaningful chunk of source code. Consider:

```c
int x = 42;
```

This line produces five tokens:

| Lexeme | Type         |
|--------|--------------|
| `int`  | KEYWORD      |
| `x`    | IDENTIFIER   |
| `=`    | OPERATOR     |
| `42`   | INT_LITERAL  |
| `;`    | DELIMITER    |

Whitespace between tokens is consumed and discarded — it has no token representation.

### What Is Lexical Analysis?

Lexical analysis (scanning) is the **first phase** of a compiler or interpreter. It converts a flat stream of characters into a structured stream of tokens. No grammar rules are checked at this stage — that's the parser's job. The lexer only answers: *"what kind of thing is this character sequence?"*

### What Is a Finite Automaton?

Flex compiles the grammar rules in `lexer.l` into a **Deterministic Finite Automaton (DFA)** — a mathematical state machine where every possible input character causes a well-defined state transition. There is no backtracking. Every character is visited exactly once. This gives Flex its O(n) linear-time performance guarantee.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   luxio.html                        │
│   React + Tailwind  ·  Glassmorphism UI             │
│                                                     │
│  ┌─────────────┐    ┌──────────────┐               │
│  │ Code Editor │    │ Token Table  │               │
│  │ Line numbers│    │ Visual Render│               │
│  │ Syntax hints│    │ Stats Panel  │               │
│  └──────┬──────┘    └──────▲───────┘               │
│         │  POST /analyze   │ JSON response          │
└─────────┼──────────────────┼───────────────────────┘
          │                  │
┌─────────▼──────────────────┴───────────────────────┐
│                  main.py (FastAPI)                  │
│                                                     │
│  • Receives code string via HTTP                    │
│  • Spawns subprocess → pipes code to ./lexer        │
│  • Parses JSON lines from stdout                    │
│  • Enriches tokens with descriptions                │
│  • Returns structured JSON array                    │
└─────────────────────┬───────────────────────────────┘
                      │ stdin/stdout pipe
┌─────────────────────▼───────────────────────────────┐
│               lexer (compiled binary)               │
│                                                     │
│  Source: lexer.l  →  flex lexer.l                  │
│          lex.yy.c →  gcc lex.yy.c -o lexer -lfl    │
│                                                     │
│  • Reads code from stdin                            │
│  • Applies DFA state machine                        │
│  • Emits one JSON object per token to stdout        │
│  • Returns exit code 1 if any INVALID_TOKEN found   │
└─────────────────────────────────────────────────────┘
```

---

## Layer 1 — The Flex Lexer (`lexer.l`)

`lexer.l` is the grammar source file. It has three sections separated by `%%`.

### Section 1 — C Declarations (`%{ ... %}`)

```c
%{
#include <stdio.h>
#include <string.h>

int line_num = 1;
int error_found = 0;

void print_token(const char* type, const char* lexeme) {
    char escaped[1024];
    int j = 0;
    for (int i = 0; lexeme[i] != '\0' && j < 1020; i++) {
        if (lexeme[i] == '"') { escaped[j++] = '\\'; escaped[j++] = '"'; }
        else if (lexeme[i] == '\\') { escaped[j++] = '\\'; escaped[j++] = '\\'; }
        else escaped[j++] = lexeme[i];
    }
    escaped[j] = '\0';
    printf("{\"line\":%d,\"token\":\"%s\",\"type\":\"%s\"}\n",
           line_num, escaped, type);
}
%}
```

**`line_num`** — a global integer that tracks the current line. It starts at 1 and increments whenever the lexer encounters a newline character.

**`error_found`** — a flag set to `1` if any INVALID_TOKEN is emitted. The process exits with code `1` in this case, signaling the FastAPI layer that errors exist.

**`print_token()`** — the core output function. Before printing, it escapes any double-quote or backslash characters inside the lexeme so the output is valid JSON. Every token is emitted as a single newline-terminated JSON object:

```json
{"line":3,"token":"fibonacci","type":"IDENTIFIER"}
```

### Section 2 — Pattern Definitions

```flex
DIGIT       [0-9]
LETTER      [a-zA-Z_]
ID          {LETTER}({LETTER}|{DIGIT})*
INT         {DIGIT}+
FLOAT       {DIGIT}+\.{DIGIT}+
STRING      \"([^\"\\]|\\.)*\"
CHAR        \'([^\'\\]|\\.)\'
COMMENT_SL  \/\/[^\n]*
COMMENT_ML  \/\*([^*]|\*+[^*/])*\*+\/
```

These are named macros — regular expression abbreviations used in the rules section. They make the grammar readable and reusable.

| Macro        | Meaning                                                          |
|--------------|------------------------------------------------------------------|
| `DIGIT`      | Any single decimal digit 0–9                                     |
| `LETTER`     | Any letter a–z, A–Z, or underscore (valid identifier start)     |
| `ID`         | An identifier: starts with a letter, followed by letters/digits |
| `INT`        | One or more digits                                               |
| `FLOAT`      | Digits, a literal dot, more digits                               |
| `STRING`     | A double-quoted string; handles `\"` and `\\` escape sequences   |
| `CHAR`       | A single-quoted character literal                                |
| `COMMENT_SL` | Everything from `//` to end of line                             |
| `COMMENT_ML` | A `/* ... */` block; the pattern handles nested `*` correctly    |

### Section 3 — Rules (`%% ... %%`)

Each rule is a pattern-action pair:

```flex
"if"        { print_token("KEYWORD", yytext); }
{FLOAT}     { print_token("FLOAT_LITERAL", yytext); }
\n          { line_num++; }
[ \t\r]+    { }
.           { error_found = 1; printf(...INVALID_TOKEN...); }
```

**`yytext`** is a built-in Flex variable containing the matched text of the current rule.

**Rule ordering matters.** Flex uses two principles to resolve ambiguity:

1. **Maximal munch** — always match the longest possible string. This ensures `==` is matched as one OPERATOR rather than two `=` OPERATOR tokens.
2. **First match wins** for ties of equal length. This is why `"if"` appears before `{ID}` — without it, the word "if" would match the general identifier pattern.

**Whitespace rules:**

```flex
\n          { line_num++; }   // newlines increment the line counter
[ \t\r]+    { }               // spaces/tabs are silently consumed
```

Whitespace produces no output. The line counter is managed manually using the `\n` rule rather than letting Flex handle it automatically, which gives us precise control.

**The catch-all error rule:**

```flex
.           {
    error_found = 1;
    printf("{\"line\":%d,\"token\":\"%s\",\"type\":\"INVALID_TOKEN\",\"error\":true}\n",
           line_num, yytext);
}
```

The `.` pattern in Flex matches any single character that no other rule matched. This is the lexer's error recovery mechanism — it flags the character and continues rather than crashing.

---

## Layer 2 — The FastAPI Bridge (`main.py`)

The Python layer is the orchestrator. It speaks HTTP to the frontend and speaks subprocess I/O to the compiled Flex binary.

### Application Setup

```python
app = FastAPI(title="Luxio Lexer API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
```

CORS middleware is enabled globally so the HTML frontend served from any origin (including `file://`) can make requests to the API without browser security blocks.

### Binary Path Resolution

```python
LEXER_PATH = os.path.join(os.path.dirname(__file__), "lexer")
```

This resolves the path to the compiled `lexer` binary relative to `main.py`, so the server works regardless of the working directory it's launched from.

### Token Description Enrichment

```python
TOKEN_DESCRIPTIONS = {
    "KEYWORD":       "Reserved language keyword",
    "IDENTIFIER":    "User-defined name",
    "INT_LITERAL":   "Integer constant",
    "FLOAT_LITERAL": "Floating-point constant",
    ...
    "INVALID_TOKEN": "Unrecognized token — lexical error",
}
```

The Flex binary only emits `type` strings. The Python layer adds a `description` field to each token by mapping `type` to this dictionary. This keeps the Flex grammar clean and language-agnostic.

### The `/analyze` Endpoint

```python
@app.post("/analyze")
async def analyze(req: AnalyzeRequest):
    result = subprocess.run(
        [LEXER_PATH],
        input=req.code,
        capture_output=True,
        text=True,
        timeout=10,
    )
```

**`subprocess.run()`** is the Python–C bridge. Key parameters:

| Parameter        | Purpose                                                   |
|------------------|-----------------------------------------------------------|
| `input=req.code` | Pipes the code string into the lexer's `stdin`            |
| `capture_output` | Captures `stdout` (tokens) and `stderr` (any C errors)    |
| `text=True`      | Decodes bytes to string automatically                     |
| `timeout=10`     | Kills the process if it hangs (malformed input protection) |

**JSON parsing loop:**

```python
for line in result.stdout.strip().splitlines():
    try:
        tok = json.loads(line)
        tok["description"] = TOKEN_DESCRIPTIONS.get(tok.get("type", ""), "Unknown")
        if tok.get("error"):
            has_errors = True
        tokens.append(tok)
    except json.JSONDecodeError:
        continue
```

Each line of stdout is one JSON object. The loop parses them individually, enriches with `description`, checks for the `error` flag, and appends to the result list. Lines that fail JSON parsing are silently skipped.

### The `/health` Endpoint

```python
@app.get("/health")
async def health():
    return {"status": "ok", "lexer": os.path.exists(LEXER_PATH)}
```

A simple diagnostic endpoint. Returns whether the lexer binary is present on disk. Useful for debugging deployment issues.

---

## Layer 3 — The React Frontend (`luxio.html`)

The frontend is a self-contained single-file React application. All CSS, JavaScript, and HTML live in one file — no build step required.

### Key State Variables

```javascript
const [code, setCode] = useState(SAMPLES['Fibonacci']);   // editor content
const [tokens, setTokens] = useState([]);                 // parsed token array
const [loading, setLoading] = useState(false);            // spinner control
const [hasErrors, setHasErrors] = useState(false);        // red alert trigger
const [analyzed, setAnalyzed] = useState(false);          // show/hide results
const [activeTab, setActiveTab] = useState('table');       // table vs. render
const [filter, setFilter] = useState('ALL');               // type filter
const [search, setSearch] = useState('');                  // search query
```

### The `analyze()` Function

```javascript
const analyze = useCallback(async () => {
    setLoading(true);
    const resp = await fetch(`${BACKEND_URL}/analyze`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code }),
    });
    const data = await resp.json();
    setTokens(data.tokens);
    setHasErrors(data.has_errors);
    setAnalyzed(true);
    setLoading(false);
}, [code]);
```

`useCallback` memoizes the function so it is only recreated when `code` changes. The function is triggered by the Analyze button or the `Ctrl+Enter` keyboard shortcut.

### Token Color Mapping

```javascript
const TOKEN_COLORS = {
    KEYWORD:       { color: '#c084fc', bg: 'rgba(192,132,252,0.12)', label: 'KW' },
    IDENTIFIER:    { color: '#60a5fa', bg: 'rgba(96,165,250,0.12)',  label: 'ID' },
    INT_LITERAL:   { color: '#34d399', bg: 'rgba(52,211,153,0.12)',  label: 'INT' },
    ...
    INVALID_TOKEN: { color: '#ef4444', bg: 'rgba(239,68,68,0.15)',   label: 'ERR' },
};
```

Every token type maps to an exact RGB color for text, a semi-transparent version for backgrounds, and a short label for compact chips. This single object drives the token table chips, the visual render highlights, the stat bars, and the legend.

### The `CodeRenderer` Component

```javascript
function CodeRenderer({ code, tokens }) {
    const segments = [];
    let lastIdx = 0;

    tokens.forEach((tok, i) => {
        const idx = code.indexOf(tok.token, lastIdx);
        if (idx > lastIdx) {
            segments.push(<span>{code.slice(lastIdx, idx)}</span>); // whitespace
        }
        segments.push(<TokenSpan key={i} token={tok} />);
        lastIdx = idx + tok.token.length;
    });

    return <div className="code-render">{segments}</div>;
}
```

This component reconstructs the original source code by interleaving plain-text whitespace segments with colored `<TokenSpan>` components. It walks through the token array in order, tracking the position in the original string to recover whitespace that the lexer discarded.

### The `TokenSpan` Tooltip

```javascript
function TokenSpan({ token }) {
    return (
        <span className="token-span" style={{ color: info.color, background: info.bg }}>
            {token.token}
            <span className="tooltip">
                <div className="tt-type">{token.type}</div>
                <div className="tt-desc">{token.description}</div>
            </span>
        </span>
    );
}
```

The tooltip is pure CSS — it uses `display: none` on `.tooltip` and `display: block` on `.token-span:hover .tooltip`. No JavaScript event handlers needed, which keeps hover response instant.

### Filtered Token Table

```javascript
const filteredTokens = useMemo(() => {
    let t = tokens;
    if (filter !== 'ALL') t = t.filter(x => x.type === filter);
    if (search) t = t.filter(x =>
        x.token.toLowerCase().includes(search.toLowerCase()) ||
        x.type.toLowerCase().includes(search.toLowerCase())
    );
    return t;
}, [tokens, filter, search]);
```

`useMemo` recomputes the filtered array only when `tokens`, `filter`, or `search` changes. Filtering happens entirely client-side — no additional API calls after the initial analysis.

---

## Token Types Reference

| Token Type     | Description                  | Example Lexemes              | Color  |
|----------------|------------------------------|------------------------------|--------|
| KEYWORD        | Reserved language keyword    | `if`, `int`, `return`, `class` | Purple |
| IDENTIFIER     | User-defined name            | `main`, `myVar`, `fibonacci` | Blue   |
| INT_LITERAL    | Integer constant             | `0`, `42`, `255`             | Green  |
| FLOAT_LITERAL  | Floating-point constant      | `3.14`, `0.5`, `1.0`         | Teal   |
| STRING_LITERAL | String constant              | `"hello"`, `"world\n"`       | Amber  |
| CHAR_LITERAL   | Character constant           | `'a'`, `'\n'`, `'\\'`        | Yellow |
| BOOLEAN        | Boolean literal              | `true`, `false`              | Orange |
| NULL_LITERAL   | Null pointer literal         | `null`, `NULL`, `nullptr`    | Red    |
| OPERATOR       | Arithmetic/logical operator  | `+`, `==`, `&&`, `->`, `::`  | Cyan   |
| DELIMITER      | Punctuation delimiter        | `(`, `{`, `;`, `,`, `.`      | Gray   |
| COMMENT        | Source code comment          | `// ...`, `/* ... */`        | Dark   |
| PREPROCESSOR   | Preprocessor `#` symbol      | `#`                          | Magenta|
| DIRECTIVE      | Preprocessor directive word  | `include`, `define`, `ifdef` | Pink   |
| HEADER         | Angle-bracket include path   | `<stdio.h>`, `<iostream>`    | Indigo |
| INVALID_TOKEN  | Unrecognized lexical element | `@`, `$`, `` ` ``            | Red    |

---

## Tokenization Process (End-to-End)

Let's trace what happens when the user analyzes this code:

```c
int x = 42;
```

**Step 1 — Browser sends HTTP request:**
```json
POST http://localhost:8765/analyze
{ "code": "int x = 42;" }
```

**Step 2 — FastAPI spawns the lexer process:**
```python
subprocess.run(["./lexer"], input="int x = 42;", capture_output=True, text=True)
```

**Step 3 — Flex processes stdin character by character:**

```
Position 0: 'i'
├─ Begins matching against all patterns simultaneously
├─ "int" matches the literal rule before {ID}
└─ Emit: {"line":1,"token":"int","type":"KEYWORD"}

Position 3: ' '
└─ Matches [ \t\r]+ → silently consumed, no output

Position 4: 'x'
├─ Matches {ID} pattern: {LETTER}({LETTER}|{DIGIT})*
├─ Reads 'x', next char is ' ' — not letter or digit, stop
└─ Emit: {"line":1,"token":"x","type":"IDENTIFIER"}

Position 5: ' '
└─ Consumed, no output

Position 6: '='
├─ Not followed by '=' (peek ahead shows ' ')
├─ Matches single '=' OPERATOR rule
└─ Emit: {"line":1,"token":"=","type":"OPERATOR"}

Position 7: ' '
└─ Consumed

Position 8–9: '4', '2'
├─ Matches {INT}: {DIGIT}+
├─ Next char is ';' — not a digit, stop
└─ Emit: {"line":1,"token":"42","type":"INT_LITERAL"}

Position 10: ';'
├─ Matches ";" DELIMITER rule
└─ Emit: {"line":1,"token":";","type":"DELIMITER"}

Position 11: End of input
└─ yywrap() returns 1 → yylex() returns → main() exits
```

**Step 4 — FastAPI parses stdout:**
```python
[
    {"line": 1, "token": "int", "type": "KEYWORD",      "description": "Reserved language keyword"},
    {"line": 1, "token": "x",   "type": "IDENTIFIER",   "description": "User-defined name"},
    {"line": 1, "token": "=",   "type": "OPERATOR",     "description": "Arithmetic/logical operator"},
    {"line": 1, "token": "42",  "type": "INT_LITERAL",  "description": "Integer constant"},
    {"line": 1, "token": ";",   "type": "DELIMITER",    "description": "Punctuation delimiter"},
]
```

**Step 5 — React renders the results:**
- Token table rows appear with staggered fade-in animation
- Token Distribution panel shows 5 bars: KEYWORD×1, IDENTIFIER×1, OPERATOR×1, INT_LITERAL×1, DELIMITER×1
- Visual Render tab shows the code with each token in its corresponding color

---

## Error Handling

### Lexer Level (Flex)

The catch-all rule handles any character that matches no other pattern:

```flex
.   {
    error_found = 1;
    printf("{\"line\":%d,\"token\":\"%s\",\"type\":\"INVALID_TOKEN\",\"error\":true}\n",
           line_num, yytext);
}
```

The lexer **does not abort** on errors. It emits an INVALID_TOKEN for the unrecognized character and continues scanning. This allows all errors in a file to be detected in a single pass.

### FastAPI Level (Python)

```python
except FileNotFoundError:
    raise HTTPException(status_code=500, detail="Lexer binary not found.")
except subprocess.TimeoutExpired:
    raise HTTPException(status_code=408, detail="Lexer timed out.")
```

Two categories of server-side errors are handled explicitly: a missing binary (deployment issue) and a timeout (malformed infinite-loop input protection).

### Frontend Level (React)

```javascript
} catch (e) {
    setBackendError(e.message.includes('Failed to fetch')
        ? 'Cannot reach backend. Start FastAPI: uvicorn main:app --port 8765'
        : e.message
    );
}
```

Network failures show an instructional error banner with the exact command to start the server. Invalid token errors trigger the red alert box:

```javascript
{hasErrors && (
    <div className="alert-error">
        🔴 Invalid Token Detected
        One or more lexemes could not be recognized...
    </div>
)}
```

---

## Example Walkthrough

### Input: Fibonacci Function

```c
int fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}
```

**Token output (abbreviated):**

```
Line 1: int → KEYWORD
Line 1: fibonacci → IDENTIFIER
Line 1: ( → DELIMITER
Line 1: int → KEYWORD
Line 1: n → IDENTIFIER
Line 1: ) → DELIMITER
Line 1: { → DELIMITER
Line 2: if → KEYWORD
Line 2: ( → DELIMITER
Line 2: n → IDENTIFIER
Line 2: <= → OPERATOR
Line 2: 1 → INT_LITERAL
Line 2: ) → DELIMITER
Line 2: return → KEYWORD
Line 2: n → IDENTIFIER
Line 2: ; → DELIMITER
...
```

**Token distribution:**

| Type        | Count |
|-------------|-------|
| KEYWORD     | 5     |
| IDENTIFIER  | 7     |
| INT_LITERAL | 3     |
| OPERATOR    | 5     |
| DELIMITER   | 12    |

### Input: Code with Errors

```c
int main() {
    char bad = @invalid;
}
```

The `@` character matches no rule in the grammar. The lexer emits:

```json
{"line":2,"token":"@","type":"INVALID_TOKEN","error":true}
```

FastAPI sets `has_errors: true` in the response. The frontend renders the red alert banner and highlights the INVALID_TOKEN row in red in the table.

---

## Complexity Analysis

| Operation             | Time Complexity | Space Complexity |
|-----------------------|-----------------|------------------|
| Flex lexing           | O(n)            | O(k)             |
| FastAPI JSON parsing  | O(t)            | O(t)             |
| React table render    | O(t)            | O(t)             |
| Token filtering       | O(t)            | O(t)             |
| Code renderer         | O(n + t)        | O(n + t)         |

Where:
- `n` = number of characters in source code
- `t` = number of tokens produced
- `k` = length of the longest single token

The Flex DFA runs in strict O(n) time — no backtracking, no lookahead beyond one character (for two-character operators like `==`). The overall system bottleneck for large inputs is subprocess startup overhead and HTTP serialization, not the lexer itself.

---

## Key Design Decisions

**Why Flex instead of a hand-written lexer?**
Flex compiles regular expressions into an optimized DFA. A hand-written character-by-character loop would be slower, harder to maintain, and more error-prone for complex patterns like multi-line comments.

**Why subprocess instead of a Python Flex binding?**
The subprocess model gives complete isolation. The lexer process runs in its own memory space, cannot affect the server, and is trivially replaceable — swap the binary for a different language's grammar without touching the API.

**Why JSON output from the Flex binary instead of a binary format?**
JSON is self-describing and trivially parseable. The overhead is acceptable for the input sizes Luxio targets (interactive code snippets), and it makes debugging the lexer output simple — you can run `echo "code" | ./lexer` and read the output directly.

**Why one-line-per-token instead of a JSON array?**
Line-delimited JSON (NDJSON) means the FastAPI layer can parse tokens as they arrive, enabling future streaming support. A single JSON array would require the entire output to be buffered before any parsing could begin.

**Why a single-file React app instead of a build system?**
Zero setup friction. The frontend runs by opening a file in a browser. No npm, no webpack, no node_modules. The tradeoff is no TypeScript and slightly larger file size — acceptable for a focused tool like this.
