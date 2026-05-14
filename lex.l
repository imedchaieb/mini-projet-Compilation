%{
 /* Inclusion du fichier généré par Bison */
#include "interpreteur.tab.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/* Fonction pour dupliquer une chaîne de caractères */
static char *lex_strdup(const char *s) {
    size_t len = strlen(s) + 1;
    /* Allocation mémoire */
    char *copy = (char *)malloc(len);
    /* Vérification d'erreur mémoire */
    if (!copy) {
        fprintf(stderr, "Erreur mémoire\n");
        exit(EXIT_FAILURE);
    }
    /* Copie de la chaîne */
    memcpy(copy, s, len);
    return copy;
}
%}

 /* Désactive yywrap */
 /* Active le numéro de ligne avec yylineno */
%option noyywrap
%option yylineno

%%

 /* Ignorer les espaces, tabulations et retours à la ligne */
[ \t\r\n]+          { }

 /* ========================= */
 /* Opérateurs de comparaison */
 /* ========================= */

"=="                { return EGAL; }
"!="                { return DIFF; }
"<="                { return INFEG; }
">="                { return SUPEG; }
"<"                 { return INF; }
">"                 { return SUP; }

 /* ===================== */
 /* Opérateurs logiques   */
 /* ===================== */

"&&"                { return ET; }
"||"                { return OU; }
"!"                 { return NON; }

 /* ===================== */
 /* Mots-clés du langage  */
 /* ===================== */

"tantque"           { return TANTQUE; }

"si"                { return SI; }
"alors"             { return ALORS; }
"sinon"             { return SINON; }
"fin"               { return FIN; }

"print"             { return AFFICHER; }

 /* ===================== */
 /* Symboles et séparateurs */
 /* ===================== */

";"                 { return FIN_INSTRUCTION; }

"="                 { return AFFECTATION; }

"("                 { return OUVRE_PARENTHESE; }
")"                 { return FERME_PARENTHESE; }

"["                 { return OUVRE_CROCHET; }
"]"                 { return FERME_CROCHET; }

 /* ===================== */
 /* Opérateurs arithmétiques */
 /* ===================== */

"+"                 { return PLUS; }
"-"                 { return MOINS; }
"*"                 { return FOIS; }
"/"                 { return DIVISE; }

 /* ===================== */
 /* Reconnaissance des nombres */
 /* ===================== */

[0-9]+ {
    /* Conversion texte -> entier */
    yylval.entier = atoi(yytext);

    return NOMBRE;
}

 /* ===================== */
 /* Reconnaissance des variables */
 /* ===================== */

[a-zA-Z_][a-zA-Z0-9_]* {
    /* Sauvegarde du nom de variable */
    yylval.chaine = lex_strdup(yytext);

    /* Vérification mémoire */
    if (!yylval.chaine) {
        fprintf(stderr, "Erreur mémoire\n");
        exit(EXIT_FAILURE);
    }

    return VARIABLE;
}

 /* ===================== */
 /* Gestion des erreurs lexicales */
 /* ===================== */
. {
    fprintf(stderr, "Caractere non reconnu a la ligne %d : %s\n", yylineno, yytext);
}

%%