%{ 
/* P1. Implements scanner.  Some changes are needed! */

#include "llvm-c/Core.h"
#include "llvm-c/BitReader.h"
#include "llvm-c/BitWriter.h"

typedef struct myvalue {
  int size;
  LLVMValueRef val[32];
} MyValue;

 int line=1;

#include "parser.h" 
%}

%option nounput
%option noinput
 
%% 

\n           line++;
[\t ]        ;

vars            { return VARS; }
"min"   { return MIN;      }
"max"   { return MAX;      }
"sum"   { return SUM;      }


\$[a-z0-9][a-z0-9]?	{ yylval.tmp = strdup(yytext); return TMP; } 
[a-zA-Z_]+          { yylval.id = strdup(yytext); return ID; } 

[0-9]+          { yylval.num = atoi(yytext); return NUM; }


"="	{ return ASSIGN;   } 
";"	{ return SEMI;     } 
"-"	{ return MINUS;    } 
"+"	{ return PLUS;     }  
"*"	{ return MULTIPLY; } 
"/"	{ return DIVIDE;   } 
","     { return COMMA;    }
"["     { return LBRACE;   }
"]"     { return RBRACE;   }

%%
