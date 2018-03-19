# Swap these lines if on Mac
#MacOS = -lcurses
#MacOS = 

.PHONY: tests test all

all: p1

p1:
	flex -o scanner.c scanner.lex
	bison -d -o parser.c parser.y
	gcc -g -c -o scanner.o scanner.c `llvm-config --cflags `
	gcc -g -c -o parser.o parser.c `llvm-config --cflags `
	gcc -g -c -o main.o main.c `llvm-config --cflags `
	g++ -g -Wno-implicit-function-declaration -o p1 main.o parser.o scanner.o `llvm-config --cflags --ldflags --libs --system-libs` -ly -ll -lpthread -ldl 

clean:
	rm -Rf scanner.c parser.c parser.h *.o p1 *~ 


test: tests

tests: p1
	make -C ./tests test
