%{
#include "project.h"
#include "y.tab.h"
%}

%option stack yylineno noyywrap

%%

[a-z]			{ yylval.sIndex = *yytext - 'a'; return VARIABLE; }
0				{ yylval.iValue = atoi(yytext); return INTEGER; }
[1-9][0-9]*		{ yylval.iValue = atoi(yytext); return INTEGER; }
[-()<>=+*/;{}.]	{ return *yytext;}
">="            return GE;
"<="            return LE;
"=="            return EQ;
"!="            return NE;
"while"         return WHILE;
"if"            return IF;
"else"          return ELSE;
"print"         return PRINT;
"return"        return RETURN;
[ \t\n\r]+      ; 
.               {printf("Unknown character %s (code: %d)\n", yytext, *yytext); yyerror("ERROR");}

%%
