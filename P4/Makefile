.SUFFIXES: %.c %.cpp

OBJS =  main.o \
	dominance.o \
	worklist.o \
	valmap.o \
	Simplify.o \
	cfg.o \
	loop.o 

OBJS += CSE_C.o summary.o
OBJS += CSE_Cpp.o Summary_Cpp.o

# Comment out next line for C++
USE_C = -DUSE_C
#For C++: USE_C = 

USE_CPP = 
MYFLAGS = $(USE_C) $(USE_CPP)

.PHONY: all

all: p4

p4: $(OBJS)
	g++ -g -Wno-implicit-function-declaration -o $@ $(OBJS) `llvm-config --cxxflags --ldflags --libs --system-libs`

clean:
	rm -Rf p3 $(OBJS)

%.o:%.c
	gcc -g -c $(MYFLAGS) -o $@ $^ `llvm-config --cflags` 

%.o:%.cpp
	g++ -g -c $(MYFLAGS) -o $@ $^ `llvm-config --cxxflags` 


