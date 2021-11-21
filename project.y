%{
#include "project.h"

nodeType *opr(int oper, int nops, ...);
nodeType *id(int i);
nodeType *con(int value);
void freeNode(nodeType *p);
int ex(nodeType *p);
int yylex(void);
static int lbl;
FILE *outpFile;

%}

%union 
{
    int iValue;
    char sIndex;
    nodeType *nPtr;
};

%token <iValue> INTEGER
%token <sIndex> VARIABLE
%token WHILE IF PRINT RETURN
%nonassoc IFX
%nonassoc ELSE

%left GE LE EQ NE '>' '<'
%left '+' '-'
%left '*' '/'
%nonassoc UMINUS

%type <nPtr> stmt expr stmt_list

%%

program:
        function
        ;

function:
          function stmt         { ex($2); freeNode($2); }
        |
        ;

stmt:
          ';'                            { $$ = opr(';', 2, NULL, NULL); }
        | expr ';'                       { $$ = $1; }
        | PRINT expr ';'                 { $$ = opr(PRINT, 1, $2); }
        | RETURN expr ';'                { $$ = opr(RETURN, 1, $2); }
        | VARIABLE '=' expr ';'          { $$ = opr('=', 2, id($1), $3); }
        | WHILE '(' expr ')' stmt        { $$ = opr(WHILE, 2, $3, $5); }
        | IF '(' expr ')' stmt %prec IFX { $$ = opr(IF, 2, $3, $5); }
        | IF '(' expr ')' stmt ELSE stmt { $$ = opr(IF, 3, $3, $5, $7); }
        | '{' stmt_list '}'              { $$ = $2; }
        ;

stmt_list:
          stmt                  { $$ = $1; }
        | stmt_list stmt        { $$ = opr(';', 2, $1, $2); }
        ;

expr:
          INTEGER               { $$ = con($1); }
        | VARIABLE              { $$ = id($1); }
        | '-' expr %prec UMINUS { $$ = opr(UMINUS, 1, $2); }
        | expr '+' expr         { $$ = opr('+', 2, $1, $3); }
        | expr '-' expr         { $$ = opr('-', 2, $1, $3); }
        | expr '*' expr         { $$ = opr('*', 2, $1, $3); }
        | expr '/' expr         { $$ = opr('/', 2, $1, $3); }
        | expr '<' expr         { $$ = opr('<', 2, $1, $3); }
        | expr '>' expr         { $$ = opr('>', 2, $1, $3); }
        | expr GE expr          { $$ = opr(GE, 2, $1, $3); }
        | expr LE expr          { $$ = opr(LE, 2, $1, $3); }
        | expr NE expr          { $$ = opr(NE, 2, $1, $3); }
        | expr EQ expr          { $$ = opr(EQ, 2, $1, $3); }
        | '(' expr ')'          { $$ = $2; }
        ;

%%

nodeType *con(int value) 
{
    nodeType *p;

    if ((p = malloc(sizeof(nodeType))) == NULL)
        yyerror(" out of memory\n");

    p->type = typeCon;
    p->con.value = value;

    return p;
}

nodeType *id(int i) 
{
    nodeType *p;

    if ((p = malloc(sizeof(nodeType))) == NULL)
        yyerror(" out of memory\n");

    p->type = typeId;
    p->id.i = i;

    return p;
}

nodeType *opr(int oper, int nops, ...) 
{
    va_list ap;
    nodeType *p;
    int i;

    if ((p = malloc(sizeof(nodeType) + (nops-1) * sizeof(nodeType *))) == NULL)
        yyerror(" out of memory\n");

    p->type = typeOpr;
    p->opr.oper = oper;
    p->opr.nops = nops;
    va_start(ap, nops);
    for (i = 0; i < nops; i++)
        p->opr.op[i] = va_arg(ap, nodeType*);
    va_end(ap);
    return p;
}

void freeNode(nodeType *p) 
{
    int i;

    if (!p) return;
    if (p->type == typeOpr) 
    {
        for (i = 0; i < p->opr.nops; i++)
            freeNode(p->opr.op[i]);
    }
    free (p);
}

int ex(nodeType* p) 
{
    int lbl1, lbl2;

    if (!p) return 0;
    switch (p->type) 
    {
    case typeCon:
        fprintf(outpFile, "\tpush  %d\n", p->con.value);
        break;
    case typeId:
        fprintf(outpFile, "\tpush  %c\n", p->id.i + 'a');
        break;
    case typeOpr:
        switch (p->opr.oper) 
        {
        case WHILE:
            fprintf(outpFile, "L%03d:\n", lbl1 = lbl++);
            ex(p->opr.op[0]);
            fprintf(outpFile, "\tjz\tL%03d\n", lbl2 = lbl++);
            ex(p->opr.op[1]);
            fprintf(outpFile, "\tjmp\tL%03d\n", lbl1);
            fprintf(outpFile, "L%03d:\n", lbl2);
            break;
        case IF:
            ex(p->opr.op[0]);
            if (p->opr.nops > 2) 
            {
                /* if else */
                fprintf(outpFile, "\tjz\tL%03d\n", lbl1 = lbl++);
                ex(p->opr.op[1]);
                fprintf(outpFile, "\tjmp\tL%03d\n", lbl2 = lbl++);
                fprintf(outpFile, "L%03d:\n", lbl1);
                ex(p->opr.op[2]);
                fprintf(outpFile, "L%03d:\n", lbl2);
            }
            else 
            {
                /* if */
                fprintf(outpFile, "\tjz\tL%03d\n", lbl1 = lbl++);
                ex(p->opr.op[1]);
                fprintf(outpFile, "L%03d:\n", lbl1);
            }
            break;
        case PRINT:
            ex(p->opr.op[0]);
            fprintf(outpFile, "\tprint\n");
            break;
        case RETURN:
            ex(p->opr.op[0]);
            fprintf(outpFile, "\tret\n");
            break;
        case '=':
            ex(p->opr.op[1]);
            fprintf(outpFile, "\tpop   %c\n", p->opr.op[0]->id.i + 'a');
            break;
        case UMINUS:
            ex(p->opr.op[0]);
            fprintf(outpFile, "\tneg\n");
            break;
        default:
            ex(p->opr.op[0]);
            ex(p->opr.op[1]);
            switch (p->opr.oper) 
            {
            case '+':   fprintf(outpFile, "\tadd\n"); break;
            case '-':   fprintf(outpFile, "\tsub\n"); break;
            case '*':   fprintf(outpFile, "\tmul\n"); break;
            case '/':   fprintf(outpFile, "\tdiv\n"); break;
            case '<':   fprintf(outpFile, "\tcompLT\n"); break;
            case '>':   fprintf(outpFile, "\tcompGT\n"); break;
            case GE:    fprintf(outpFile, "\tcompGE\n"); break;
            case LE:    fprintf(outpFile, "\tcompLE\n"); break;
            case NE:    fprintf(outpFile, "\tcompNE\n"); break;
            case EQ:    fprintf(outpFile, "\tcompEQ\n"); break;
            }
        }
    }
    return 0;
}

int main(int argc, char *argv[])
{
	extern FILE *yyin;
    
	if (argc == 2)
	{
		yyin = fopen(argv[1], "r");
		
		if (yyin == NULL)
		{
			yyerror(" input file was not opened\n");
			system("pause");
			return 0;
		}
	}
	else goto usage;
    
	outpFile = fopen ("output.txt","w");
    if (outpFile == NULL)
		{
			yyerror(" output file was not opened\n");
			system("pause");
			return 0;
		}
    
    if (!yyparse()) printf("\nyyparse(): parsing successful!\n\n");

    fclose(outpFile);
    fclose(yyin);
	system("pause");
	return 0;

usage:  printf("\nusage: %s [input file]\n\n", argv[0]);
		system("pause");

		return 0;
}

void yyerror(char *str, ...)
{
	if (str == NULL) return;

	printf("\nERROR: ");

	va_list ap;
	va_start(ap, str);
	while (*str != '\0')
	{
		if (*str == '%' && *(str + 1) != '\0')
		{
			str++;
			switch (*str)
			{
				case 'd':
				{
					int i = va_arg(ap, int);
					printf("%d", i);
					break;
				}
				case 'c':
				{
					char c = va_arg(ap, char);
					printf("%c", c);
					break;
				}
				case 's':
				{
					char *s = va_arg(ap, char *);
					printf("%s", s);
					break;
				}
				default:
				{
					printf("yyerror: unknown parameter '%c'\n\n", *str);
					break;
				}
			}
		} else
			printf("%c", *str);
			str++;
	}
	va_end(ap);

	fprintf(outpFile, " :: (line #%d of the input file)\n\n", yylineno);

	system("pause");
	exit(-1);
}