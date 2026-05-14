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
    printf("{\"line\":%d,\"token\":\"%s\",\"type\":\"%s\"}\n", line_num, escaped, type);
}
%}

DIGIT       [0-9]
LETTER      [a-zA-Z_]
ID          {LETTER}({LETTER}|{DIGIT})*
INT         {DIGIT}+
FLOAT       {DIGIT}+\.{DIGIT}+
STRING      \"([^\"\\]|\\.)*\"
CHAR        \'([^\'\\]|\\.)\'
COMMENT_SL  \/\/[^\n]*
COMMENT_ML  \/\*([^*]|\*+[^*/])*\*+\/

%%

"if"        { print_token("KEYWORD", yytext); }
"else"      { print_token("KEYWORD", yytext); }
"while"     { print_token("KEYWORD", yytext); }
"for"       { print_token("KEYWORD", yytext); }
"do"        { print_token("KEYWORD", yytext); }
"return"    { print_token("KEYWORD", yytext); }
"int"       { print_token("KEYWORD", yytext); }
"float"     { print_token("KEYWORD", yytext); }
"char"      { print_token("KEYWORD", yytext); }
"void"      { print_token("KEYWORD", yytext); }
"bool"      { print_token("KEYWORD", yytext); }
"string"    { print_token("KEYWORD", yytext); }
"double"    { print_token("KEYWORD", yytext); }
"long"      { print_token("KEYWORD", yytext); }
"short"     { print_token("KEYWORD", yytext); }
"unsigned"  { print_token("KEYWORD", yytext); }
"struct"    { print_token("KEYWORD", yytext); }
"class"     { print_token("KEYWORD", yytext); }
"public"    { print_token("KEYWORD", yytext); }
"private"   { print_token("KEYWORD", yytext); }
"protected" { print_token("KEYWORD", yytext); }
"new"       { print_token("KEYWORD", yytext); }
"delete"    { print_token("KEYWORD", yytext); }
"true"      { print_token("BOOLEAN", yytext); }
"false"     { print_token("BOOLEAN", yytext); }
"null"      { print_token("NULL_LITERAL", yytext); }
"NULL"      { print_token("NULL_LITERAL", yytext); }
"nullptr"   { print_token("NULL_LITERAL", yytext); }
"include"   { print_token("DIRECTIVE", yytext); }
"define"    { print_token("DIRECTIVE", yytext); }
"ifdef"     { print_token("DIRECTIVE", yytext); }
"ifndef"    { print_token("DIRECTIVE", yytext); }
"endif"     { print_token("DIRECTIVE", yytext); }

{COMMENT_ML}    {
    for (int i = 0; yytext[i]; i++) if (yytext[i] == '\n') line_num++;
    print_token("COMMENT", yytext);
}
{COMMENT_SL}    { print_token("COMMENT", yytext); }

{STRING}    { print_token("STRING_LITERAL", yytext); }
{CHAR}      { print_token("CHAR_LITERAL", yytext); }
{FLOAT}     { print_token("FLOAT_LITERAL", yytext); }
{INT}       { print_token("INT_LITERAL", yytext); }

{ID}        { print_token("IDENTIFIER", yytext); }

"#"         { print_token("PREPROCESSOR", yytext); }
"<"[a-zA-Z][a-zA-Z0-9._/]*">"  { print_token("HEADER", yytext); }

"+"         { print_token("OPERATOR", yytext); }
"-"         { print_token("OPERATOR", yytext); }
"*"         { print_token("OPERATOR", yytext); }
"/"         { print_token("OPERATOR", yytext); }
"%"         { print_token("OPERATOR", yytext); }
"="         { print_token("OPERATOR", yytext); }
"=="        { print_token("OPERATOR", yytext); }
"!="        { print_token("OPERATOR", yytext); }
"<="        { print_token("OPERATOR", yytext); }
">="        { print_token("OPERATOR", yytext); }
">"         { print_token("OPERATOR", yytext); }
"&&"        { print_token("OPERATOR", yytext); }
"||"        { print_token("OPERATOR", yytext); }
"!"         { print_token("OPERATOR", yytext); }
"++"        { print_token("OPERATOR", yytext); }
"--"        { print_token("OPERATOR", yytext); }
"+="        { print_token("OPERATOR", yytext); }
"-="        { print_token("OPERATOR", yytext); }
"*="        { print_token("OPERATOR", yytext); }
"/="        { print_token("OPERATOR", yytext); }
"<<"        { print_token("OPERATOR", yytext); }
">>"        { print_token("OPERATOR", yytext); }
"->"        { print_token("OPERATOR", yytext); }
"::"        { print_token("OPERATOR", yytext); }
"&"         { print_token("OPERATOR", yytext); }
"|"         { print_token("OPERATOR", yytext); }
"^"         { print_token("OPERATOR", yytext); }
"~"         { print_token("OPERATOR", yytext); }

"("         { print_token("DELIMITER", yytext); }
")"         { print_token("DELIMITER", yytext); }
"{"         { print_token("DELIMITER", yytext); }
"}"         { print_token("DELIMITER", yytext); }
"["         { print_token("DELIMITER", yytext); }
"]"         { print_token("DELIMITER", yytext); }
";"         { print_token("DELIMITER", yytext); }
","         { print_token("DELIMITER", yytext); }
"."         { print_token("DELIMITER", yytext); }
":"         { print_token("DELIMITER", yytext); }
"?"         { print_token("DELIMITER", yytext); }

\n          { line_num++; }
[ \t\r]+    { }

.           {
    error_found = 1;
    printf("{\"line\":%d,\"token\":\"%s\",\"type\":\"INVALID_TOKEN\",\"error\":true}\n", line_num, yytext);
}

%%

int yywrap() { return 1; }

int main() {
    yylex();
    return error_found ? 1 : 0;
}
