from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import subprocess
import json
import os

app = FastAPI(title="Luxio Lexer API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

LEXER_PATH = os.path.join(os.path.dirname(__file__), "lexer")

TOKEN_DESCRIPTIONS = {
    "KEYWORD": "Reserved language keyword",
    "IDENTIFIER": "User-defined name",
    "INT_LITERAL": "Integer constant",
    "FLOAT_LITERAL": "Floating-point constant",
    "STRING_LITERAL": "String constant",
    "CHAR_LITERAL": "Character constant",
    "BOOLEAN": "Boolean literal",
    "NULL_LITERAL": "Null pointer literal",
    "OPERATOR": "Arithmetic/logical operator",
    "DELIMITER": "Punctuation delimiter",
    "COMMENT": "Source code comment",
    "PREPROCESSOR": "Preprocessor symbol",
    "DIRECTIVE": "Preprocessor directive",
    "HEADER": "Include header file",
    "INVALID_TOKEN": "Unrecognized token — lexical error",
}

class AnalyzeRequest(BaseModel):
    code: str

@app.post("/analyze")
async def analyze(req: AnalyzeRequest):
    if not req.code.strip():
        return {"tokens": [], "has_errors": False}

    try:
        result = subprocess.run(
            [LEXER_PATH],
            input=req.code,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="Lexer binary not found.")
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=408, detail="Lexer timed out.")

    tokens = []
    has_errors = False

    for line in result.stdout.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            tok = json.loads(line)
            tok["description"] = TOKEN_DESCRIPTIONS.get(tok.get("type", ""), "Unknown token type")
            if tok.get("error"):
                has_errors = True
            tokens.append(tok)
        except json.JSONDecodeError:
            continue

    return {"tokens": tokens, "has_errors": has_errors}

@app.get("/health")
async def health():
    return {"status": "ok", "lexer": os.path.exists(LEXER_PATH)}
