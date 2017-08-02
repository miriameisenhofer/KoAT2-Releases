{
  module Make(G : Parseable.TransitionGraph) =
    struct
      open Lexing
      module P = Parser.Make(G)
         
      exception SyntaxError of string
                             
      let next_line lexbuf =
        let pos = lexbuf.lex_curr_p in
        lexbuf.lex_curr_p <-
          { pos with pos_bol = lexbuf.lex_curr_pos;
                     pos_lnum = pos.pos_lnum + 1
          }

}

let int = ['0'-'9'] ['0'-'9']*
let white = [' ' '\t']+
let newline = '\r' | '\n' | "\r\n"
let id = ['a'-'z' 'A'-'Z' '_'] ['a'-'z' 'A'-'Z' '0'-'9' '_']* '\''?

rule read =
  parse
  | white    { read lexbuf }
  | newline  { next_line lexbuf; P.EOL }
  | "RULES"  { P.RULES }
  | "VAR"    { P.VAR }
  | int      { P.UINT (int_of_string (Lexing.lexeme lexbuf)) }
  | id       { P.ID (Lexing.lexeme lexbuf) }
  | "->"     { P.ARROW }
  | '('      { P.LPAR }
  | ')'      { P.RPAR }
  | '+'      { P.PLUS }
  | '*'      { P.TIMES }
  | '-'      { P.MINUS }
  | '^'      { P.POW }
  | "=="     { P.EQUAL }
  | "<>"     { P.NEQ }
  | "<="     { P.LESSEQUAL }
  | ">="     { P.GREATEREQUAL }
  | '<'      { P.LESSTHAN }
  | '>'      { P.GREATERTHAN }
  | "&&"     { P.AND }
  | ":|:"    { P.WITH }
  | ','      { P.COMMA }
  | eof      { P.EOF }
  | _        { raise (SyntaxError ("Unexpected char: " ^ Lexing.lexeme lexbuf)) }

{
  end
}