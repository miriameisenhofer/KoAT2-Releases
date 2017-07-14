{
  module Make(Var : PolyTypes.ID) =
    struct
      open Lexing
      module P = PolynomialParser.Make(Var)
         
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
  | newline  { next_line lexbuf; read lexbuf }
  | int      { P.UINT (int_of_string (Lexing.lexeme lexbuf)) }
  | id       { P.ID (Lexing.lexeme lexbuf) }
  | '('      { P.LPAR }
  | ')'      { P.RPAR }
  | '+'      { P.PLUS }
  | '*'      { P.TIMES }
  | '-'      { P.MINUS }
  | '^'      { P.POW }
  | eof      { P.EOF }
  | _        { raise (SyntaxError ("Unexpected char: " ^ Lexing.lexeme lexbuf)) }

{
  end
}
