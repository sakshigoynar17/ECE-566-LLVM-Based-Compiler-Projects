/*
 * File: CSE_Cpp.cpp
 *
 * Description:
 *   This is where you implement the C++ version of project 4 support.
 */

/* LLVM Header Files */
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/GlobalVariable.h"
#include "llvm/IR/Type.h"
#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/IR/Dominators.h"
#include "llvm/ADT/GraphTraits.h"
#include "llvm/ADT/SCCIterator.h"
#include "llvm/IR/ValueMap.h"
#include "llvm/Support/GraphWriter.h"
#include "llvm/IR/InstIterator.h"

#include <map>

using namespace llvm;

// ^^^^
// must be after using namespace llvm; sorry for the ugly code
#include "CSE.h"


static
int commonSubexpression(Instruction *I, Instruction* J) {

  // return 1 if I and J are common subexpressions

  // check these things:
  //   - they have the same opcode
  //   - they have the same type
  //   - they have the same number of operands
  //   - all operands are the same (pointer equivalence) LLVMValueRef
  // if any are false, return 0

  // return 0 is always conservative, so by default return 0
  return 0;
}

static
int canHandle(Instruction* I) 
{
  // Cannot handle these:
  // Load, Store, Terminator, CallInst, PHI, Alloca, VAArg
  return 0;
}


// Perform CSE on I for BB and all dominator-tree children
static
void processInst(BasicBlock* BB, Instruction* I) 
{
  // do nothing if trivially dead

  // bale out if not an optimizable instruction
  if(!canHandle(I)) return;

  // CSE w.r.t. to I on BB

  // for each dom-tree child of BB:
  //    processInst(child)
}


static
void FunctionCSE(Function* F) 
{
  // for each bb:
  //   for each isntruction
  //       processInst
  //
  //   process memory instructions
}


void LLVMCommonSubexpressionElimination_Cpp(Module *M)
{
  // for each function, f:
  //   FunctionCSE(f);
 
  // print out summary of results
}

