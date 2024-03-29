{
open Parser
exception FAIL
}

rule token = parse
     | [' ' '\t' '\n'] {token lexbuf}
     | ("//" | '#')[^'\n']* {token lexbuf}
     | ['0'-'9']+ | "true" | "false" | "null" | '"'[^'"']*'"' | "{}" {
       CONST(Lexing.lexeme_start lexbuf, Lexing.lexeme_end lexbuf)
       }
     |	'(' {LPAREN}
     |	')' {RPAREN}
     |	'{' {LBRACE(Lexing.lexeme_start lexbuf)}
     |	'}' {RBRACE(Lexing.lexeme_start lexbuf)}
     |	',' {COMMA}
     |  ['+''-''*''/''>''<'] | "<=" | ">="
     | "==" | "!=" | "||" | "&&" | "%" {
       BINOP(Lexing.lexeme_start lexbuf, Lexing.lexeme_end lexbuf)
       }
     |	'!' {
     	UNOP(Lexing.lexeme_start lexbuf, Lexing.lexeme_end lexbuf)
	}
     | '.' {
        DOT(Lexing.lexeme_start lexbuf, Lexing.lexeme_end lexbuf)
	}
     |  '=' {EQ}
     |	"->" {TO}
     |  "if"	{IF}
     |	"else"	{ELSE}
     |  ';' {SEMI}
     |	"skip" {SKIP}
     |	"def"  {DEF(Lexing.lexeme_start lexbuf)}
     | 	"assert" {ASSERT}
     |	"return" {RETURN}
     |	"by" {BY}
     | ['a'-'z''A'-'Z']['a'-'z''A'-'Z''0'-'9'''''_']* as ident {
       IDENT(ident, Lexing.lexeme_start lexbuf, Lexing.lexeme_end lexbuf)
       }
     | 	eof {EOF}
