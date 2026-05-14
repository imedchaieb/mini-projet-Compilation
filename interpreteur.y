%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
extern int yylineno;
typedef struct Expr Expr;
typedef struct Stmt Stmt;
typedef struct StmtList StmtList;

/* AST definitions */
typedef enum { EXPR_INT, EXPR_VAR, EXPR_ARRAY, EXPR_UNARY, EXPR_BINARY } ExprKind;
typedef enum { ST_ASSIGN, ST_ASSIGN_ARRAY, ST_PRINT, ST_IF, ST_WHILE } StmtKind;
typedef enum { OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_EQ, OP_NE, OP_LT, OP_GT, OP_LE, OP_GE, OP_AND, OP_OR, OP_NOT, OP_NEG } OpCode;

struct Expr {
    ExprKind kind;
    int value;
    char *name;
    OpCode op;
    Expr *left;
    Expr *right;
    Expr *index;
};

struct Stmt {
    StmtKind kind;
    char *name;
    Expr *expr;
    Expr *index;
    Expr *value;
    StmtList *then_branch;
    StmtList *else_branch;
};

struct StmtList {
    Stmt *stmt;
    StmtList *next;
};

/* Symbol table */

typedef enum { SYM_SCALAR, SYM_ARRAY } SymbolType;
typedef struct {
    char name[64];
    SymbolType type;
    int scalar;
    int *array;
    int size;
} Symbol;

#define MAX_SYMBOLS 256
static Symbol symbols[MAX_SYMBOLS];
static int symbol_count = 0;

/* helpers */
static Expr *make_int_expr(int value) { Expr *e = calloc(1, sizeof(*e)); e->kind = EXPR_INT; e->value = value; return e; }
static Expr *make_var_expr(char *name) { Expr *e = calloc(1, sizeof(*e)); e->kind = EXPR_VAR; e->name = name; return e; }
static Expr *make_array_expr(char *name, Expr *index) { Expr *e = calloc(1, sizeof(*e)); e->kind = EXPR_ARRAY; e->name = name; e->index = index; return e; }
static Expr *make_unary_expr(OpCode op, Expr *child) { Expr *e = calloc(1, sizeof(*e)); e->kind = EXPR_UNARY; e->op = op; e->left = child; return e; }
static Expr *make_binary_expr(OpCode op, Expr *left, Expr *right) { Expr *e = calloc(1, sizeof(*e)); e->kind = EXPR_BINARY; e->op = op; e->left = left; e->right = right; return e; }

static Stmt *make_assign_stmt(char *name, Expr *value) { Stmt *s = calloc(1, sizeof(*s)); s->kind = ST_ASSIGN; s->name = name; s->expr = value; return s; }
static Stmt *make_array_assign_stmt(char *name, Expr *index, Expr *value) { Stmt *s = calloc(1, sizeof(*s)); s->kind = ST_ASSIGN_ARRAY; s->name = name; s->index = index; s->value = value; return s; }
static Stmt *make_print_stmt(Expr *expr) { Stmt *s = calloc(1, sizeof(*s)); s->kind = ST_PRINT; s->expr = expr; return s; }
static Stmt *make_if_stmt(Expr *cond, StmtList *then_branch, StmtList *else_branch) { Stmt *s = calloc(1, sizeof(*s)); s->kind = ST_IF; s->expr = cond; s->then_branch = then_branch; s->else_branch = else_branch; return s; }
static Stmt *make_while_stmt(Expr *cond, StmtList *body) { Stmt *s = calloc(1, sizeof(*s)); s->kind = ST_WHILE; s->expr = cond; s->then_branch = body; return s; }

static StmtList *append_stmt_list(StmtList *list, Stmt *stmt) {
    StmtList *node = calloc(1, sizeof(*node));
    node->stmt = stmt;
    if (!list) return node;
    StmtList *cur = list;
    while (cur->next) cur = cur->next;
    cur->next = node;
    return list;
}

static int find_symbol(const char *name) {
    for (int i = 0; i < symbol_count; ++i) if (strcmp(symbols[i].name, name) == 0) return i;
    return -1;
}

static Symbol *get_or_create_scalar(const char *name) {
    int idx = find_symbol(name);
    if (idx >= 0) return &symbols[idx];
    if (symbol_count >= MAX_SYMBOLS) { fprintf(stderr, "Erreur: table des symboles pleine\n"); exit(EXIT_FAILURE); }
    Symbol *sym = &symbols[symbol_count++];
    memset(sym, 0, sizeof(*sym));
    strncpy(sym->name, name, sizeof(sym->name) - 1);
    sym->type = SYM_SCALAR;
    return sym;
}

static Symbol *get_or_create_array(const char *name, int min_size) {
    Symbol *sym = get_or_create_scalar(name);
    if (sym->type == SYM_ARRAY) {
        if (sym->size < min_size) {
            int *new_data = realloc(sym->array, sizeof(int) * min_size);
            if (!new_data) { fprintf(stderr, "Erreur: allocation mémoire impossible\n"); exit(EXIT_FAILURE); }
            for (int i = sym->size; i < min_size; ++i) new_data[i] = 0;
            sym->array = new_data;
            sym->size = min_size;
        }
        return sym;
    }
    int old = sym->scalar;
    sym->array = calloc((size_t)min_size, sizeof(int));
    if (!sym->array) { fprintf(stderr, "Erreur: allocation mémoire impossible\n"); exit(EXIT_FAILURE); }
    sym->type = SYM_ARRAY;
    sym->size = min_size;
    sym->array[0] = old;
    return sym;
}

static void set_scalar_value(const char *name, int value) {
    Symbol *sym = get_or_create_scalar(name);
    if (sym->type == SYM_ARRAY) {
        free(sym->array);
        sym->array = NULL;
        sym->size = 0;
        sym->type = SYM_SCALAR;
    }
    sym->scalar = value;
}

static int get_scalar_value(const char *name) {
    int idx = find_symbol(name);
    if (idx < 0) return 0;
    Symbol *sym = &symbols[idx];
    return (sym->type == SYM_ARRAY) ? ((sym->size > 0) ? sym->array[0] : 0) : sym->scalar;
}

static void set_array_value(const char *name, int index, int value) {
    if (index < 0) { fprintf(stderr, "Erreur ligne %d : indice de tableau negatif (%d)\n", yylineno, index); return; }
    Symbol *sym = get_or_create_array(name, index + 1);
    if (index >= sym->size) {
        int *new_data = realloc(sym->array, sizeof(int) * (index + 1));
        if (!new_data) { fprintf(stderr, "Erreur: allocation mémoire impossible\n"); exit(EXIT_FAILURE); }
        for (int i = sym->size; i < index + 1; ++i) new_data[i] = 0;
        sym->array = new_data;
        sym->size = index + 1;
    }
    sym->array[index] = value;
}

static int get_array_value(const char *name, int index) {
    int idx = find_symbol(name);
    if (idx < 0) return 0;
    Symbol *sym = &symbols[idx];
    if (sym->type != SYM_ARRAY || index < 0 || index >= sym->size) return 0;
    return sym->array[index];
}

/* forward declarations */
static int eval_expr(Expr *expr);
static void exec_stmt_list(StmtList *list);
static void exec_stmt(Stmt *stmt);
static void free_expr(Expr *expr);
static void free_stmt(Stmt *stmt);
static void free_stmt_list(StmtList *list);

int yylex(void);
void yyerror(const char *s) { fprintf(stderr, "Erreur ligne %d : %s\n", yylineno, s); }

static StmtList *g_program = NULL;
%}

%code requires {
    typedef struct Expr Expr;
    typedef struct Stmt Stmt;
    typedef struct StmtList StmtList;
}

%union {
    int entier;
    char *chaine;
    Expr *expr;
    Stmt *stmt;
    StmtList *stmts;
}

%token <entier> NOMBRE
%token <chaine> VARIABLE
%token AFFECTATION SI ALORS SINON FIN AFFICHER TANTQUE FIN_INSTRUCTION
%token OUVRE_PARENTHESE FERME_PARENTHESE OUVRE_CROCHET FERME_CROCHET
%token PLUS MOINS FOIS DIVISE
%token EGAL DIFF INF SUP INFEG SUPEG ET OU NON

%type <expr> expression
%type <stmt> instruction assignment print_stmt if_stmt while_stmt
%type <stmts> programme stmt_list

%start programme

%left OU
%left ET
%nonassoc EGAL DIFF INF SUP INFEG SUPEG
%left PLUS MOINS
%left FOIS DIVISE
%right NON
%right UMINUS

%%

programme
    : stmt_list                 { $$ = $1; g_program = $1; exec_stmt_list(g_program); }
    ;

stmt_list
    : /* empty */               { $$ = NULL; }
    | stmt_list instruction     { $$ = append_stmt_list($1, $2); }
    ;

instruction
    : assignment FIN_INSTRUCTION { $$ = $1; }
    | print_stmt FIN_INSTRUCTION { $$ = $1; }
    | if_stmt                    { $$ = $1; }
    | while_stmt                 { $$ = $1; }
    ;

assignment
    : VARIABLE AFFECTATION expression
        { $$ = make_assign_stmt($1, $3); }
    | VARIABLE OUVRE_CROCHET expression FERME_CROCHET AFFECTATION expression
        { $$ = make_array_assign_stmt($1, $3, $6); }
    ;

print_stmt
    : AFFICHER OUVRE_PARENTHESE expression FERME_PARENTHESE
        { $$ = make_print_stmt($3); }
    ;

if_stmt
    : SI expression ALORS stmt_list FIN
        { $$ = make_if_stmt($2, $4, NULL); }
    | SI expression ALORS stmt_list SINON stmt_list FIN
        { $$ = make_if_stmt($2, $4, $6); }
    ;

while_stmt
    : TANTQUE OUVRE_PARENTHESE expression FERME_PARENTHESE ALORS stmt_list FIN
        { $$ = make_while_stmt($3, $6); }
    ;

expression
    : NOMBRE                       { $$ = make_int_expr($1); }
    | VARIABLE                     { $$ = make_var_expr($1); }
    | VARIABLE OUVRE_CROCHET expression FERME_CROCHET
        { $$ = make_array_expr($1, $3); }
    | expression PLUS expression   { $$ = make_binary_expr(OP_ADD, $1, $3); }
    | expression MOINS expression  { $$ = make_binary_expr(OP_SUB, $1, $3); }
    | expression FOIS expression   { $$ = make_binary_expr(OP_MUL, $1, $3); }
    | expression DIVISE expression { $$ = make_binary_expr(OP_DIV, $1, $3); }
    | expression EGAL expression   { $$ = make_binary_expr(OP_EQ, $1, $3); }
    | expression DIFF expression   { $$ = make_binary_expr(OP_NE, $1, $3); }
    | expression INF expression    { $$ = make_binary_expr(OP_LT, $1, $3); }
    | expression SUP expression    { $$ = make_binary_expr(OP_GT, $1, $3); }
    | expression INFEG expression  { $$ = make_binary_expr(OP_LE, $1, $3); }
    | expression SUPEG expression  { $$ = make_binary_expr(OP_GE, $1, $3); }
    | expression ET expression     { $$ = make_binary_expr(OP_AND, $1, $3); }
    | expression OU expression     { $$ = make_binary_expr(OP_OR, $1, $3); }
    | NON expression %prec NON     { $$ = make_unary_expr(OP_NOT, $2); }
    | MOINS expression %prec UMINUS { $$ = make_unary_expr(OP_NEG, $2); }
    | OUVRE_PARENTHESE expression FERME_PARENTHESE { $$ = $2; }
    ;

%%

static int eval_expr(Expr *expr) {
    if (!expr) return 0;
    switch (expr->kind) {
        case EXPR_INT:   return expr->value;
        case EXPR_VAR:   return get_scalar_value(expr->name);
        case EXPR_ARRAY: return get_array_value(expr->name, eval_expr(expr->index));
        case EXPR_UNARY: {
            int v = eval_expr(expr->left);
            return (expr->op == OP_NOT) ? !v : -v;
        }
        case EXPR_BINARY: {
            int left = eval_expr(expr->left);
            switch (expr->op) {
                case OP_ADD: return left + eval_expr(expr->right);
                case OP_SUB: return left - eval_expr(expr->right);
                case OP_MUL: return left * eval_expr(expr->right);
                case OP_DIV: {
                    int right = eval_expr(expr->right);
                    if (right == 0) { yyerror("Division par zero"); return 0; }
                    return left / right;
                }
                case OP_EQ:  return left == eval_expr(expr->right);
                case OP_NE:  return left != eval_expr(expr->right);
                case OP_LT:  return left <  eval_expr(expr->right);
                case OP_GT:  return left >  eval_expr(expr->right);
                case OP_LE:  return left <= eval_expr(expr->right);
                case OP_GE:  return left >= eval_expr(expr->right);
                case OP_AND: return (left != 0) && (eval_expr(expr->right) != 0);
                case OP_OR:  return (left != 0) || (eval_expr(expr->right) != 0);
                default:     return 0;
            }
        }
    }
    return 0;
}

static void exec_stmt_list(StmtList *list) {
    for (StmtList *cur = list; cur != NULL; cur = cur->next) exec_stmt(cur->stmt);
}

static void exec_stmt(Stmt *stmt) {
    if (!stmt) return;
    switch (stmt->kind) {
        case ST_ASSIGN: {
            int value = eval_expr(stmt->expr);
            set_scalar_value(stmt->name, value);
            printf("> %s = %d\n", stmt->name, value);
            break;
        }
        case ST_ASSIGN_ARRAY: {
            int index = eval_expr(stmt->index);
            int value = eval_expr(stmt->value);
            set_array_value(stmt->name, index, value);
            printf("> %s[%d] = %d\n", stmt->name, index, value);
            break;
        }
        case ST_PRINT:
            printf("%d\n", eval_expr(stmt->expr));
            break;
        case ST_IF:
            if (eval_expr(stmt->expr) != 0) exec_stmt_list(stmt->then_branch);
            else exec_stmt_list(stmt->else_branch);
            break;
        case ST_WHILE:
            while (eval_expr(stmt->expr) != 0) exec_stmt_list(stmt->then_branch);
            break;
    }
}

static void free_expr(Expr *expr) {
    if (!expr) return;
    free_expr(expr->left);
    free_expr(expr->right);
    free_expr(expr->index);
    free(expr->name);
    free(expr);
}

static void free_stmt(Stmt *stmt) {
    if (!stmt) return;
    free(stmt->name);
    free_expr(stmt->expr);
    free_expr(stmt->index);
    free_expr(stmt->value);
    free_stmt_list(stmt->then_branch);
    free_stmt_list(stmt->else_branch);
    free(stmt);
}

static void free_stmt_list(StmtList *list) {
    while (list) {
        StmtList *next = list->next;
        free_stmt(list->stmt);
        free(list);
        list = next;
    }
}
