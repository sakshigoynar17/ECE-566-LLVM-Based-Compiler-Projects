/*
 * File: LICM_Cpp.cpp
 *
 * Description:
 *   Stub for LICM in Cpp. Extend to provide LICM implementation.
 */

#include <stdio.h>
#include <stdlib.h>

/* LLVM Header Files */
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/GlobalVariable.h"
#include "llvm/IR/Dominators.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/IR/Type.h"

using namespace llvm;

extern unsigned int LICM_Basic;
extern unsigned int LICM_NoPreheader;
extern unsigned int LICM_AfterLoop;
extern unsigned int LICM_LoadHoist;
extern unsigned int LICM_LoadSink;
extern unsigned int LICM_StoreSink;
extern unsigned int LICM_BadCall;
extern unsigned int LICM_BadStore;

void LoopInvariantCodeMotion_Cpp(Module* M)
{

  fprintf(stderr,"LICM_Basic      =%d\n",LICM_Basic);
  fprintf(stderr,"LICM_NoPreheader=%d\n",LICM_NoPreheader);
  fprintf(stderr,"LICM_LoadHoist  =%d\n",LICM_LoadHoist);
  fprintf(stderr,"LICM_LoadSink   =%d\n",LICM_LoadSink);
  fprintf(stderr,"LICM_StoreSink  =%d\n",LICM_StoreSink);
  fprintf(stderr,"LICM_BadCall    =%d\n",LICM_BadCall);
  fprintf(stderr,"LICM_BadStore   =%d\n",LICM_BadStore);
}
