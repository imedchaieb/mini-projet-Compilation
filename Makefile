CC=gcc
CFLAGS=-Wall -Wextra -g
FLEX=flex
BISON=bison
TARGET=interpreteur.exe
PARSER=interpreteur.tab.c
PARSER_H=interpreteur.tab.h
LEXER=lex.yy.c

all: $(TARGET)

$(PARSER) $(PARSER_H): interpreteur.y
	$(BISON) -d -o $(PARSER) interpreteur.y

$(LEXER): lex.l $(PARSER_H)
	$(FLEX) -o $(LEXER) lex.l

$(TARGET): main.c $(PARSER) $(LEXER)
	$(CC) $(CFLAGS) -o $@ main.c $(PARSER) $(LEXER)

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET) $(PARSER) $(PARSER_H) $(LEXER) *.o

.PHONY: all run clean
