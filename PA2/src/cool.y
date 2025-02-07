/*
 *  cool.y
 *              Parser definition for the COOL language.
 *
 */
%{
#include <iostream>
#include "cool-tree.h"
#include "stringtab.h"
#include "utilities.h"

/* Add your own C declarations here */


/************************************************************************/
/*                DONT CHANGE ANYTHING IN THIS SECTION                  */

extern int yylex();           /* the entry point to the lexer  */
extern int curr_lineno;
extern char *curr_filename;
Program ast_root;            /* the result of the parse  */
Classes parse_results;       /* for use in semantic analysis */
int omerrs = 0;              /* number of errors in lexing and parsing */

/*
   The parser will always call the yyerror function when it encounters a parse
   error. The given yyerror implementation (see below) justs prints out the
   location in the file where the error was found. You should not change the
   error message of yyerror, since it will be used for grading puproses.
*/
void yyerror(const char *s);

/*
   The VERBOSE_ERRORS flag can be used in order to provide more detailed error
   messages. You can use the flag like this:

     if (VERBOSE_ERRORS)
       fprintf(stderr, "semicolon missing from end of declaration of class\n");

   By default the flag is set to 0. If you want to set it to 1 and see your
   verbose error messages, invoke your parser with the -v flag.

   You should try to provide accurate and detailed error messages. A small part
   of your grade will be for good quality error messages.
*/
extern int VERBOSE_ERRORS;

%}

/* A union of all the types that can be the result of parsing actions. */
%union {
  Boolean boolean;
  Symbol symbol;
  Program program;
  Class_ class_;
  Classes classes;
  Feature feature;
  Features features;
  Formal formal;
  Formals formals;
  Case case_;
  Cases cases;
  Expression expression;
  Expressions expressions;
  char *error_msg;
}

/*
   Declare the terminals; a few have types for associated lexemes.
   The token ERROR is never used in the parser; thus, it is a parse
   error when the lexer returns it.

   The integer following token declaration is the numeric constant used
   to represent that token internally.  Typically, Bison generates these
   on its own, but we give explicit numbers to prevent version parity
   problems (bison 1.25 and earlier start at 258, later versions -- at
   257)
*/
%token CLASS 258 ELSE 259 FI 260 IF 261 IN 262
%token INHERITS 263 LET 264 LOOP 265 POOL 266 THEN 267 WHILE 268
%token CASE 269 ESAC 270 OF 271 DARROW 272 NEW 273 ISVOID 274
%token <symbol>  STR_CONST 275 INT_CONST 276
%token <boolean> BOOL_CONST 277
%token <symbol>  TYPEID 278 OBJECTID 279
%token ASSIGN 280 NOT 281 LE 282 ERROR 283

/*  DON'T CHANGE ANYTHING ABOVE THIS LINE, OR YOUR PARSER WONT WORK       */
/**************************************************************************/

   /* Complete the nonterminal list below, giving a type for the semantic
      value of each non terminal. (See section 3.6 in the bison
      documentation for details). */

/* Declare types for the grammar's non-terminals. */
%type <program> program
%type <classes> class_list
%type <class_> class
%type <features> feature_list
%type <feature> feature
%type <formals> formal_list
%type <formal> formal
%type <expressions> expr_comma_list expr_semicolon_list
%type <expression> expr let_body let_opt_assign
%type <cases> case_list
%type <case_> case

/* Precedence declarations go here. */
%left low_pri
%left IN
%right ASSIGN
%left NOT
%nonassoc LE '<' '='
%left '+' '-'
%left '*' '/'
%left ISVOID
%left '~'
%left '@'
%left '.'

%%
/*
   Save the root of the abstract syntax tree in a global variable.
*/
program : class_list { ast_root = program($class_list); }
        ;

/* Class list cannot be empty, and no empty classes in list. */
class_list
        : class            /* single class */
                { $$ = single_Classes($class); }
        | class_list[p_classes] class /* several classes */
                { $$ = append_Classes($p_classes, single_Classes($class)); }
        ;

/* If no parent is specified, the class inherits from the Object class. */
class   : CLASS TYPEID '{' feature_list '}' ';'
                { $$ = class_($TYPEID, idtable.add_string("Object"), $feature_list,
                              stringtable.add_string(curr_filename)); }
        | CLASS TYPEID[c_type] INHERITS TYPEID[p_type] '{' feature_list '}' ';'
                { $$ = class_($c_type, $p_type, $feature_list, stringtable.add_string(curr_filename)); }
        /* Error handling for calss */
        | error ';'                                                     /* Error inside a class body, need clear lookahead */
                { yyclearin; };
        | CLASS error CLASS                                             /* Error between classes, restart at the next class */
                { YYBACKUP(CLASS, yylval); yyerrok; }
        | CLASS TYPEID '{' feature_list '}' error                       /* Error due to missing semicolon */
                { yyerrok; }
        | CLASS TYPEID INHERITS TYPEID '{' feature_list '}' error       /* Error due to missing semicolon */
                { yyerrok; }
        ;

/* Feature list may be empty, but no empty features in list. */
feature_list
        : /* empty */
                { $$ = nil_Features(); }
        | feature_list[p_features] feature
                { $$ = append_Features($p_features, single_Features($feature)); }
        ;

/* Rule for a single feature */
feature : OBJECTID '(' formal_list ')' ':' TYPEID '{' expr '}' ';'
                { $$ = method($OBJECTID, $formal_list, $TYPEID, $expr); }
        | OBJECTID ':' TYPEID ASSIGN expr ';'
                { $$ = attr($OBJECTID, $TYPEID, $expr); }
        | OBJECTID ':' TYPEID ';'
                { $$ = attr($OBJECTID, $TYPEID, no_expr()); }
        /* Error handling for feature */
	| error ';'                                                     /* Error inside a feature body, need clear lookahead */
                { yyclearin; }
        ;

/* Formal list may be empty, but no empty formals in list. */
formal_list
        : /* empty */
                { $$ = nil_Formals(); }
        | formal
                { $$ = single_Formals($formal); }
        | formal_list[p_formals] ',' formal
                { $$ = append_Formals($p_formals, single_Formals($formal)); }
        ;

/* Rule for a single formal */
formal  : OBJECTID ':' TYPEID
                { $$ = formal($OBJECTID, $TYPEID); }
        ;

/* Expression (with comma) list may be empty, but no empty expressions in list. */
expr_comma_list
        : /* empty */
                { $$ = nil_Expressions(); }
        | expr
                { $$ = single_Expressions($expr); }
        | expr_comma_list[p_exprs] ',' expr
                { $$ = append_Expressions($p_exprs, single_Expressions($expr)); }
        ;

/* Expression (with semicolon) cannot be empty, and no empty expressions in list. */
expr_semicolon_list
        : expr ';'
                { $$ = single_Expressions($expr); }
        | expr_semicolon_list[p_exprs] expr ';'
                { $$ = append_Expressions($p_exprs, single_Expressions($expr)); }
        /* Error handling for expression inside block */
	| error ';'                                                     /* Error inside a expr_semicolon_list body, need clear lookahead */
                { yyclearin; }
        | expr error                                                    /* Error due to missing semicolon */
                { yyerrok; }
        ;

/* The following rule is CRUCIAL, it CANNOT be inserted into let_body,
   otherwise the line number of MULTI-LINE let expression will be WRONG. */
let_opt_assign
        : /* empty */
                { $$ = no_expr(); }
        | ASSIGN expr
                { $$ = $expr; }
        ;

/* Rules for the part after LET token */
let_body: OBJECTID ':' TYPEID let_opt_assign IN expr %prec low_pri
                { $$ = let($OBJECTID, $TYPEID, $let_opt_assign, $expr); }
        | OBJECTID ':' TYPEID let_opt_assign ',' let_body[p_lets]
                { $$ = let($OBJECTID, $TYPEID, $let_opt_assign, $p_lets); }
        /* Error handling for let binding */
	| error IN expr                                                 /* Error inside a let body, need clear lookahead */
                { yyclearin; }
	| error ',' let_body                                            /* Error inside a expr_semicolon_list body, need clear lookahead */
                { yyclearin; }
        ;

/* Case list cannot be empty, and no empty cases in list. */
case_list
        : case
                { $$ = single_Cases($case); }
        | case_list[p_cases] case
                { $$ = append_Cases($p_cases, single_Cases($case)); }
        ;

/* Rule for a single case */
case    : OBJECTID ':' TYPEID DARROW expr ';'
                { $$ = branch($OBJECTID, $TYPEID, $expr); }
        ;

/* Rule for a single expression, but may contain multiple sub-expressions */
expr    : OBJECTID ASSIGN expr[src]                                                                     /* Assignment */
                { $$ = assign($OBJECTID, $src); }
        | expr[src] '.' OBJECTID '(' expr_comma_list ')'                                                /* Dynamic dispatch */
                { $$ = dispatch($src, $OBJECTID, $expr_comma_list); }
        | expr[src] '@' TYPEID '.' OBJECTID '(' expr_comma_list ')'                                     /* Static dispatch */
                { $$ = static_dispatch($src, $TYPEID, $OBJECTID, $expr_comma_list); }
        | OBJECTID '(' expr_comma_list ')'                                                              /* Dynamic dispatch */
                { $$ = dispatch(object(idtable.add_string("self")), $OBJECTID, $expr_comma_list); }
        | IF expr[condition] THEN expr[then_body] ELSE expr[else_body] FI                               /* If */
                { $$ = cond($condition, $then_body, $else_body); }
        | WHILE expr[condition] LOOP expr[loop_body] POOL                                               /* While */
                { $$ = loop($condition, $loop_body); }
        | '{' expr_semicolon_list '}'                                                                   /* Block */
                { $$ = block($expr_semicolon_list); }
        | LET let_body                                                                                  /* Let */
                { $$ = $let_body; }
        | CASE expr[be_cased] OF case_list ESAC                                                         /* Case */
                { $$ = typcase($be_cased, $case_list); }
        | NEW TYPEID                                                                                    /* New */
                { $$ = new_($TYPEID); }
        | ISVOID expr[check]                                                                            /* Isvoid */
                { $$ = isvoid($check); }
        | expr[left] '+' expr[right]                                                                    /* Plus */
                { $$ = plus($left, $right); }
        | expr[left] '-' expr[right]                                                                    /* Sub */
                { $$ = sub($left, $right); }
        | expr[left] '*' expr[right]                                                                    /* Multiply */
                { $$ = mul($left, $right); }
        | expr[left] '/' expr[right]                                                                    /* Devide */
                { $$ = divide($left, $right); }
        | '~' expr[src]                                                                                 /* Negation */
                { $$ = neg($src); }
        | expr[left] '<' expr[right]                                                                    /* Less */
                { $$ = lt($left, $right); }
        | expr[left] LE expr[right]                                                                     /* Less or equal */
                { $$ = leq($left, $right); }
        | expr[left] '=' expr[right]                                                                    /* Equal */
                { $$ = eq($left, $right); }
        | NOT expr[src]                                                                                 /* Not */
                { $$ = comp($src); }
        | '(' expr[src] ')'                                                                             /* Parenthesis */
                { $$ = $src; }
        | OBJECTID
                { $$ = object($OBJECTID); }
        | INT_CONST
                { $$ = int_const($INT_CONST); }
        | STR_CONST
                { $$ = string_const($STR_CONST); }
        | BOOL_CONST
                { $$ = bool_const($BOOL_CONST); }
        /* Error handling for expression */
        | WHILE error POOL                                                                              /* Error inside a while expr, need clear lookhead */
                { yyclearin; }
        ;

/* end of grammar */
%%

/* This function is called automatically when Bison detects a parse error. */
void yyerror(const char *s)
{
  cerr << "\"" << curr_filename << "\", line " << curr_lineno << ": " \
    << s << " at or near ";
  print_cool_token(yychar);
  cerr << endl;
  omerrs++;

  if(omerrs>20) {
      if (VERBOSE_ERRORS)
         fprintf(stderr, "More than 20 errors\n");
      exit(1);
  }
}

