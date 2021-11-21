#ifndef PROJECT_H
#define PROJECT_H

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <ctype.h>
#include <string.h>
#include <locale.h>

extern void yyerror(char* str, ...);
extern int yylineno;

typedef enum { typeCon, typeId, typeOpr } nodeEnum;

typedef struct
{
    int value;
} conNodeType;

typedef struct 
{
    int i;
} idNodeType;

typedef struct 
{
    int oper;
    int nops;
    struct nodeTypeTag* op[1];
} oprNodeType;

typedef struct nodeTypeTag 
{
    nodeEnum type;
    union 
    {
        conNodeType con;
        idNodeType id;
        oprNodeType opr;
    };
} nodeType;

#endif