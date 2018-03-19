# Swap these lines if on Mac
MacOS = -lcurses
#MacOS = 

.SUFFIXES: %.c

OBJS =  main.o \
	dominance.o \
	worklist.o \
	valmap.o \
	summary.o

.PHONY: all

all: p3

p3: $(OBJS)
	g++ -g -Wno-implicit-function-declaration -o $@ $(OBJS) `llvm-config --cflags --ldflags --libs` -lpthread -ldl $(MacOS)

clean:
	rm -Rf p3 $(OBJS)

%.o:%.c
	gcc -g -c -o $@ $^ `llvm-config --cflags` 

%.o:%.cpp
	g++ -g -c -o $@ $^ `llvm-config --cxxflags` 


