/*
 * File: CSE_C.c
 *
 * Description:
 *   This is where you implement the C version of project 4 support.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* LLVM Header Files */
#include "llvm-c/Core.h"
#include "dominance.h"
#include "transform.h"
#include "worklist.h"

/* Header file global to this project */
#include "cfg.h"
#include "CSE.h"

int CSE_basic= 0;
int CSE_Dead = 0;
int CSE_Simplify =0;
int CSE_Rloads =0;
int CSE_Store2loads=0;
int CSE_RStore=0;
int move_to_next_store =0;
int total_deleted_instructions=0;
//Why functions are made static ?:  In C, a static function is not visible outside of its translation unit,
// which is the object file it is compiled into. In other words, making a function static limits its scope.
// You can think of a static function as being "private" to its *.c file

static
int commonSubexpression(LLVMValueRef I, LLVMValueRef J) {

  int flag =0;
  //printf("\n Entering CSE function");
  
  
  if(LLVMIsAICmpInst(I))
  {
	  if(LLVMGetICmpPredicate(I) != LLVMGetICmpPredicate(J))
	  {
		  flag =0;
	  }
  }
 
  if(LLVMIsAFCmpInst(I))
  {
	  if(LLVMGetFCmpPredicate(I) != LLVMGetFCmpPredicate(J))
	  {
		  flag =0;
	  }
  }
  if(LLVMGetInstructionOpcode(I) ==  LLVMGetInstructionOpcode(J)) // same opcode
  {
	  if(LLVMTypeOf(I) == LLVMTypeOf(J)) // same type of instruction
	  {
		  if(LLVMGetNumOperands(I)== LLVMGetNumOperands(J)) //same number of operands
		  {
				int oper_iter ;
				for(oper_iter=0; oper_iter< LLVMGetNumOperands(I); oper_iter++ )
				{
					LLVMValueRef op_I = LLVMGetOperand(I, oper_iter);
					LLVMValueRef op_J = LLVMGetOperand(J, oper_iter);
					if(op_I == op_J) // all operands are the same (pointer equivalence) LLVMValueRef (in )
						flag =1;
					else 
					{
						flag =0;
						break;
					}
				}
		  }		  
	  }
  }
  //printf("\nExiting CSE function");
  return flag;
  
}
static
int isDead(LLVMValueRef I)
{
  // Are there uses, if so not dead!
  if (LLVMGetFirstUse(I)!=NULL)
    return 0;

  LLVMOpcode opcode = LLVMGetInstructionOpcode(I);
  switch(opcode) 
  {
  // when in doubt, keep it! add opcode here to keep:
	  case LLVMRet:
	  case LLVMBr:
	  case LLVMSwitch:
	  case LLVMIndirectBr:
	  case LLVMInvoke: 	
	  case LLVMUnreachable:
	  case LLVMFence:
	  case LLVMStore:
	  case LLVMCall:
	  case LLVMAtomicCmpXchg:
	  case LLVMAtomicRMW:
	  case LLVMResume:	
	  case LLVMLandingPad: return 0;
	  case LLVMLoad: if(LLVMGetVolatile(I)) return 0;
	  // all others can be removed
	  default:break;
  }

  // All conditions passed
  return 1;
}

/*DCE is implemented for one function. The worklist created has all the instructions from all the basic blocks in a function. */
void Optimisation_zero(LLVMModuleRef Module)  // Dead code elimination
{
  // Loop over all the functions
  LLVMValueRef F=NULL;
  
  for(F=LLVMGetFirstFunction(Module);
      F!=NULL;
      F=LLVMGetNextFunction(F))
    {
      // Is this function defined?
      if (LLVMCountBasicBlocks(F)) 
	{
	  
	  worklist_t worklist = worklist_for_function(F);
	  while(!worklist_empty(worklist)) {
	    LLVMValueRef I = worklist_pop(worklist);
	     if (isDead(I))
	      {	 
		   int i;
		   //LLVMDumpValue(I);
			for(i=0; i<LLVMGetNumOperands(I); i++)
		  {
		    LLVMValueRef J = LLVMGetOperand(I,i);
		    if (LLVMIsAInstruction(J))
		      worklist_insert(worklist,J);
		  }
		  CSE_Dead++;
		  LLVMInstructionEraseFromParent(I);
		  total_deleted_instructions++;
	      }
	  }	  
        worklist_destroy(worklist);
	}
    }
}



//Do not consider Loads, Stores, Terminators, VAArg, Calls, Allocas, and FCmps for elimination.
static
int canHandle(LLVMValueRef I) 
{
  return ! 
    (	LLVMIsALoadInst(I) ||
		LLVMIsAStoreInst(I) ||
		LLVMIsATerminatorInst(I) ||
		LLVMIsACallInst(I) ||
		LLVMIsAPHINode(I) ||
		LLVMIsAAllocaInst(I) || 
		LLVMIsAFCmpInst(I) ||
		LLVMIsAVAArgInst(I) ||
		LLVMIsAExtractValueInst(I)	);
}


// Perform CSE on I for BB and all dominator-tree children
static
void processInst(LLVMBasicBlockRef BB, LLVMValueRef I, int flag) 
{

  if(!canHandle(I)) 
  {
	  //printf("\n I cant handle");
	  return ;
  }
  else // can handle
  {
	  if(flag ==0)
	  {
		  LLVMValueRef inst_iter = LLVMGetNextInstruction(I); // points to each instruction
		  while(inst_iter != NULL)
		  {
			  //printf("\nBefore CSE");
			  //printf("\ncommonSubexpression(I, inst_iter) : %d",x );
			  if (commonSubexpression(I, inst_iter)) 
			  {
				  //printf("\nCSE inside the same block ");
				  LLVMValueRef rm=inst_iter;
				  // update iterator first, before erasing
				  inst_iter = LLVMGetNextInstruction(inst_iter);
				  LLVMReplaceAllUsesWith(rm, I);
				  LLVMInstructionEraseFromParent(rm);
				  total_deleted_instructions++;
				  CSE_basic++;
				  continue;
			  }
			  //printf("\nsa");
			  inst_iter = LLVMGetNextInstruction(inst_iter);
			  //printf("\nks");
		  }
		  
		  //for each dom-tree child of BB:
		  //processInst(child)
		  LLVMBasicBlockRef child_BB;
		  for (child_BB = LLVMFirstDomChild(BB); child_BB != NULL ; child_BB= LLVMNextDomChild(BB,child_BB ))
		  {
			  processInst(child_BB, I, 1);
		  }
		  
	  }
	  
	  else if(flag ==1)
	  
	  {
		  LLVMValueRef insn_child = LLVMGetFirstInstruction(BB);
		  while(insn_child != NULL )
		  {
			  if(commonSubexpression(I, insn_child))
			  {
				  LLVMValueRef rm =insn_child;
				  // update iterator first, before erasing
				  insn_child = LLVMGetNextInstruction(insn_child);
				  LLVMReplaceAllUsesWith(rm, I);
				  LLVMInstructionEraseFromParent(rm);
				  total_deleted_instructions++;
				  CSE_basic++;
				  continue;
			  }
			  insn_child = LLVMGetNextInstruction(insn_child);
		  }
		  
		  LLVMBasicBlockRef child_BB;
		  for (child_BB = LLVMFirstDomChild(BB); child_BB != NULL ; child_BB= LLVMNextDomChild(BB,child_BB ))
		  {
			  processInst(child_BB, I, 1);
		  }
	  }
  }  
}


static
void Optimisation_CSE_basic(LLVMModuleRef Module) 
{
  
  LLVMValueRef Function;
  for (Function=LLVMGetFirstFunction(Module);Function!=NULL;Function=LLVMGetNextFunction(Function))
  {
	  LLVMBasicBlockRef BB; // points to each basic block one at a time
	  for (BB = LLVMGetFirstBasicBlock(Function);BB != NULL; BB = LLVMGetNextBasicBlock(BB))
	  {
		  
		  LLVMValueRef inst_iter; // points to each instruction 
		  for(inst_iter = LLVMGetFirstInstruction(BB);inst_iter != NULL; inst_iter = LLVMGetNextInstruction(inst_iter)) 
		  {
			processInst(BB, inst_iter, 0);
		  }    
	  }
  }
}

void Optimisation_one(LLVMModuleRef Module) // Simple Constant Folding
{
	LLVMValueRef Function;
	for (Function=LLVMGetFirstFunction(Module);Function!=NULL;Function=LLVMGetNextFunction(Function))
	{
		LLVMBasicBlockRef BB; // points to each basic block one at a time
		for (BB = LLVMGetFirstBasicBlock(Function);BB != NULL; BB = LLVMGetNextBasicBlock(BB))
		{
	  
			LLVMValueRef inst_iter; // points to each instruction 
			inst_iter = LLVMGetFirstInstruction(BB);
			while(inst_iter != NULL) 
			{
				
				if(InstructionSimplify(inst_iter)!= NULL)// which further calls LLVM built in function : SimplifyInstruction. Returns NULL if the instruction cannot be simplified.
				{
					CSE_Simplify++;
					LLVMValueRef rm =inst_iter;
					LLVMReplaceAllUsesWith(rm, InstructionSimplify(inst_iter));
					// update iterator first, before erasing
					inst_iter = LLVMGetNextInstruction(inst_iter);
					LLVMInstructionEraseFromParent(rm);
					total_deleted_instructions++;
					continue;
				}
				inst_iter = LLVMGetNextInstruction(inst_iter);
			}
		}
	}
	
}

void Optimisation_two(LLVMModuleRef Module) // Redundant Loads
{
	LLVMValueRef Function;
	for (Function=LLVMGetFirstFunction(Module);Function!=NULL;Function=LLVMGetNextFunction(Function))
	{
		LLVMBasicBlockRef BB; // points to each basic block one at a time
		for (BB = LLVMGetFirstBasicBlock(Function);BB != NULL; BB = LLVMGetNextBasicBlock(BB))
		{  
			LLVMValueRef inst_iter; // points to each instruction 
			for(inst_iter = LLVMGetFirstInstruction(BB);inst_iter != NULL; inst_iter = LLVMGetNextInstruction(inst_iter)) 
			{
				if(LLVMGetInstructionOpcode(inst_iter) == LLVMLoad)
				{
					LLVMValueRef inst_iter2; // points to each instruction 
					inst_iter2 = LLVMGetNextInstruction(inst_iter);
					while(inst_iter2 != NULL)
					{
						
						if(	(LLVMGetInstructionOpcode(inst_iter2) == LLVMLoad) && 
							(!(LLVMGetVolatile(inst_iter2))) && 
							(LLVMTypeOf(inst_iter)==LLVMTypeOf(inst_iter2)) &&
							(LLVMGetOperand(inst_iter, 0)== LLVMGetOperand(inst_iter2, 0)) ) // address same 
							{
								LLVMValueRef rm =inst_iter2;
								inst_iter2 = LLVMGetNextInstruction(inst_iter2);
								LLVMReplaceAllUsesWith(rm, inst_iter);
								LLVMInstructionEraseFromParent(rm);
								total_deleted_instructions++;
								CSE_Rloads++;
								continue;
							}
						if(LLVMGetInstructionOpcode(inst_iter2) == LLVMStore || LLVMGetInstructionOpcode(inst_iter2) == LLVMCall)
							break;
						
						inst_iter2 = LLVMGetNextInstruction(inst_iter2);
					}
				}
			}
		}
	}
}



void Optimisation_three(LLVMModuleRef Module) // Redundant Stores and Store to Loads 
{
	LLVMValueRef Function;
	for (Function=LLVMGetFirstFunction(Module);Function!=NULL;Function=LLVMGetNextFunction(Function))
	{
		//printf("\ninside functio");
		LLVMBasicBlockRef BB; // points to each basic block one at a time
		for (BB = LLVMGetFirstBasicBlock(Function);BB != NULL; BB = LLVMGetNextBasicBlock(BB))
		{  
			//printf("\ninside BB");
			LLVMValueRef inst_iter; // points to each instruction 
			inst_iter = LLVMGetFirstInstruction(BB);
			while(inst_iter != NULL) 
			{
				//LLVMDumpValue(inst_iter);
				if(LLVMGetInstructionOpcode(inst_iter) == LLVMStore) 
				{
					LLVMValueRef inst_iter2; // points to each instruction 
					inst_iter2 = LLVMGetNextInstruction(inst_iter);
					while( inst_iter2 != NULL) 
					{
						// store to load forwarding
						if(	(LLVMGetInstructionOpcode(inst_iter2) == LLVMLoad) && 
							(!(LLVMGetVolatile(inst_iter2))) &&
							(LLVMTypeOf(inst_iter2)==LLVMTypeOf(LLVMGetOperand(inst_iter, 0))) &&
							(LLVMGetOperand(inst_iter, 1)== LLVMGetOperand(inst_iter2, 0))	)  //same address 
							{
								LLVMValueRef rm =inst_iter2;
								inst_iter2 = LLVMGetNextInstruction(inst_iter2);
								LLVMReplaceAllUsesWith(rm, LLVMGetOperand(inst_iter, 0));
								LLVMInstructionEraseFromParent(rm);
								total_deleted_instructions++;
								CSE_Store2loads++;
								continue; // inst_iter2 has already been incremented. Continue checking next instruction 
							}
							
						else if(	(LLVMGetInstructionOpcode(inst_iter2) == LLVMStore) && 
									(!(LLVMGetVolatile(inst_iter))) && 
									(LLVMTypeOf(LLVMGetOperand(inst_iter2, 0))==LLVMTypeOf(LLVMGetOperand(inst_iter, 0))) && 
									(LLVMGetOperand(inst_iter, 1)== LLVMGetOperand(inst_iter2, 1))	)
							{
								LLVMValueRef rm =inst_iter; //Notice": We remove the first store
								inst_iter = LLVMGetNextInstruction(inst_iter);
								LLVMInstructionEraseFromParent(rm);
								total_deleted_instructions++;
								CSE_RStore++;
								//printf("\nincemrent inside elseif  redundant sotore ");
								move_to_next_store =1;
								break;
							}
						else if(	LLVMGetInstructionOpcode(inst_iter2) == LLVMStore || 
									LLVMGetInstructionOpcode(inst_iter2) == LLVMCall || 
									LLVMGetInstructionOpcode(inst_iter2) == LLVMLoad)
							{
								break;
							}
							
						inst_iter2 = LLVMGetNextInstruction(inst_iter2)	;	
					}
					
					
					if(move_to_next_store ==1)
					{
						//printf("move_to_next_store");
						move_to_next_store =0;
						continue;
					}
					
					
				}
				
				//printf("Hi");
				inst_iter= LLVMGetNextInstruction(inst_iter);
			}
		}
	}
}

// Module ---> Functions ---> Basic Blocks ---> Add instruction
void LLVMCommonSubexpressionElimination(LLVMModuleRef Module)
{
  Optimisation_one(Module); //simplify
  Optimisation_zero(Module); // deadcode
  Optimisation_CSE_basic(Module);
  Optimisation_two(Module);
  Optimisation_three(Module);  
  Optimisation_CSE_basic(Module); // mandatory
  Optimisation_one(Module); //simplify
  Optimisation_zero(Module); // deadcode 
  
 
  
  fprintf(stdout,"CSE_basic.......................%d\n",CSE_basic);
  fprintf(stdout,"CSE_Dead........................%d\n",CSE_Dead);
  fprintf(stdout,"CSE_Simplify....................%d\n",CSE_Simplify);
  fprintf(stdout,"CSE_Rloads......................%d\n",CSE_Rloads);
  fprintf(stdout,"CSE_Store2loads.................%d\n",CSE_Store2loads);
  fprintf(stdout,"CSE_RStore......................%d\n",CSE_RStore);
  fprintf(stdout,"Total_deleted_instructions......%d\n",total_deleted_instructions);
}

