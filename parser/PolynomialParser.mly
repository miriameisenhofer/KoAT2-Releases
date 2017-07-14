%parameter<Var : PolyTypes.ID>

%token	<string>	ID
%token	<int>		UINT
%token			PLUS MINUS TIMES POW
%token			LPAR RPAR
%token			EOF
			
%left			PLUS MINUS
%left			TIMES
%left			POW
			
%start <PolyTypes.PolynomialAST(Var).t> polynomial

%type <PolyTypes.PolynomialAST(Var).t> expression

%{
  module P = PolyTypes.PolynomialAST(Var)
%}
			
%%

polynomial :
	|	ex = expression EOF { ex };

expression :
	|	v = ID
                  { P.Variable (Var.of_string v) }
	| 	c = UINT
                  { P.Constant c }
	|	LPAR; ex = expression; RPAR
                  { ex }
	|       MINUS; ex = expression
	          { P.Neg ex }
	|       ex1 = expression; PLUS; ex2 = expression
	          { P.Plus (ex1, ex2) }
	|       ex1 = expression; TIMES; ex2 = expression
	          { P.Times (ex1, ex2) }
	|       ex1 = expression; MINUS; ex2 = expression
	          { P.Plus (ex1, P.Neg ex2) }
	|       ex = expression; POW; c = UINT
	          { P.Pow (ex, c) } ;
