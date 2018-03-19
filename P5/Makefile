# Swap these lines if on Mac

.SUFFIXES: %.c

OBJS =  main.o \
	dominance.o \
	worklist.o \
	valmap.o \
	summary.o \
	Summary_Cpp.o \
	CSE_C.o \
	CSE_Cpp.o \
	LICM_C.o \
	LICM_Cpp.o \
	Simplify.o \
	cfg.o \
	loop.o

.PHONY: all

# Comment out next line for C++
USE_C = -DUSE_C
#For C++: USE_C = 

USE_CPP = 
MYFLAGS = $(USE_C) $(USE_CPP)


all: p5

p5: $(OBJS)
	g++ -g -Wno-implicit-function-declaration -o $@ $(OBJS) `llvm-config --cxxflags --ldflags --libs --system-libs`

clean:
	rm -Rf p5 $(OBJS)

%.o:%.c
	gcc -g -c $(MYFLAGS) -o $@ $^ `llvm-config --cflags` 

%.o:%.cpp
	g++ -g -c $(MYFLAGS) -o $@ $^ `llvm-config --cxxflags` 


