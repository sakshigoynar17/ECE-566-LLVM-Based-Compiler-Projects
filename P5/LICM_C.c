/*
 * File: LICM_C.c
 *
 * Description:
 *   Stub for LICM in C. This is where you implement your LICM pass.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

/* LLVM Header Files */
#include "llvm-c/Core.h"
#include "dominance.h"

/* Header file global to this project */
#include "cfg.h"
#include "loop.h"
#include "worklist.h"
#include "valmap.h"

static worklist_t list;

static LLVMBuilderRef Builder=NULL;

unsigned int LICM_Basic=0;
unsigned int LICM_NoPreheader=0;
unsigned int LICM_AfterLoop=0;
unsigned int LICM_LoadHoist=0;
unsigned int LICM_LoadSink=0;
unsigned int LICM_StoreSink=0;
unsigned int LICM_BadCall=0;
unsigned int LICM_BadStore=0;

/*Inbuiult function of LLVM : makeloopinvariant: If the given instruction is inside of the loop and it can be hoisted, do so to make it trivially
loop-invariant.Return true if the instruction after any hoisting is loop invariant. This function can be used as a slightly more aggressive \
replacement for isLoopInvariant.*/

bool canMoveOutOfLoop(LLVMLoopRef loop, LLVMValueRef insn, LLVMValueRef addr)
{
	LLVMBasicBlockRef BlockHavingInsn;
	BlockHavingInsn = LLVMGetInstructionParent(insn);
	/*
	worklist_t exitblocks = worklist_create();
		exitblocks = LLVMGetExitBlocks(loop);
		while(!worklist_empty(exitblocks))
		{
			LLVMBasicBlockRef exit = LLVMValueAsBasicBlock(worklist_pop(exitblocks));
			if(!LLVMDominates(LLVMGetBasicBlockParent(BlockHavingInsn),BlockHavingInsn, exit))
				return false;
			
		}
	*/	
	
	LLVMValueRef insn_iter;
	worklist_t BlocksInsideLoop = worklist_create(); // No effect of using worklist_create :/
	BlocksInsideLoop = LLVMGetBlocksInLoop(loop);
	while(!worklist_empty(BlocksInsideLoop)) 
	{
		LLVMBasicBlockRef block_iter;
		block_iter = LLVMValueAsBasicBlock(worklist_pop(BlocksInsideLoop));
		insn_iter = LLVMGetFirstInstruction(block_iter);
		//next_insn= LLVMGetNextInstruction(insn);
		while(insn_iter != NULL)
		{
			
			if(LLVMIsACallInst(insn_iter))
			{
				LICM_BadCall++;
				worklist_destroy(BlocksInsideLoop); // To avoid memory leak 
				return false; // Badcall is incremented only once per load.
			}
			insn_iter= LLVMGetNextInstruction(insn_iter) ;
		}
	
	}

     //if (addr is a constant and there are no stores to addr in L):
	if(LLVMIsAConstant(addr) || LLVMIsAGlobalValue(addr) || LLVMIsAGlobalVariable(addr))//Address needs to be constant which is a guarantee of no calculation of address inside loop.
	{
		if (LLVMIsAInstruction(addr) && LLVMLoopContainsInst(loop, addr)) 
			return false;
		
		
		worklist_t BlocksInsideLoop = worklist_create(); 
		BlocksInsideLoop = LLVMGetBlocksInLoop(loop);
		
		while(!worklist_empty(BlocksInsideLoop)) 
			{
				LLVMValueRef insn_iter;
				LLVMBasicBlockRef block_iter;
				block_iter = LLVMValueAsBasicBlock(worklist_pop(BlocksInsideLoop));
				insn_iter = LLVMGetFirstInstruction(block_iter);
				//next_insn= LLVMGetNextInstruction(next_insn);
				while(insn_iter != NULL)
				{
					if(		LLVMIsAStoreInst(insn_iter) && (addr == LLVMGetOperand(insn_iter, 1))) // No store to the same address
					{
						LICM_BadStore++;
						worklist_destroy(BlocksInsideLoop); // to avoid mempry leak
						return false;
					}
					
					insn_iter = LLVMGetNextInstruction(insn_iter);
				}
				
				
			}
			
		worklist_t exitblocks = worklist_create();
		exitblocks = LLVMGetExitBlocks(loop);
		while(!worklist_empty(exitblocks))
		{
			LLVMBasicBlockRef exit = LLVMValueAsBasicBlock(worklist_pop(exitblocks));
			if(!LLVMDominates(LLVMGetBasicBlockParent(BlockHavingInsn),BlockHavingInsn, exit))
				return false;
			
		} 
		// I doiminates L 's exit 	
		return true;
		
	}
	
	 //if (addr is an AllocaInst and AllocaInst is not inside the loop  
	if(LLVMIsAAllocaInst(addr) && (!LLVMLoopContainsInst(loop, addr)))
	{
		
		//LLVMValueRef next_insn;
		
		worklist_t BlocksInsideLoop = worklist_create(); 
		BlocksInsideLoop = LLVMGetBlocksInLoop(loop);
		
		while(!worklist_empty(BlocksInsideLoop)) 
			{
				LLVMValueRef insn_iter;
				LLVMBasicBlockRef block_iter;
				block_iter = LLVMValueAsBasicBlock(worklist_pop(BlocksInsideLoop));
				insn_iter = LLVMGetFirstInstruction(block_iter);
				
				while(insn_iter != NULL)
				{
					if(LLVMIsAStoreInst(insn_iter) && (addr == LLVMGetOperand(insn_iter, 1))) //no stores to addr in L and
					{
						LICM_BadStore++;
						worklist_destroy(BlocksInsideLoop);
						return false;
					}
					
					insn_iter= LLVMGetNextInstruction(insn_iter) ;
				}
		
				
			}
		
		worklist_t exitblocks = worklist_create();
		exitblocks = LLVMGetExitBlocks(loop);
		while(!worklist_empty(exitblocks))
		{
			LLVMBasicBlockRef exit = LLVMValueAsBasicBlock(worklist_pop(exitblocks));
			if(!LLVMDominates(LLVMGetBasicBlockParent(BlockHavingInsn),BlockHavingInsn, exit))
				return false;
			
		}
		//I dominates L’s exit
		return true;
	}

	
	if(!LLVMLoopContainsInst(loop, addr)) // address is not defined inside the loop
	{
			
		worklist_t BlocksInsideLoop = worklist_create(); // No effect of using worklist_create :/
		BlocksInsideLoop = LLVMGetBlocksInLoop(loop);
		
		while(!worklist_empty(BlocksInsideLoop)) 
		{
			LLVMValueRef insn_iter;
			LLVMBasicBlockRef block_iter;
			block_iter = LLVMValueAsBasicBlock(worklist_pop(BlocksInsideLoop));
			insn_iter = LLVMGetFirstInstruction(block_iter);
			
			while(insn_iter != NULL)
			{
				if(LLVMIsAStoreInst(insn_iter))
				{
					LICM_BadStore++;
					worklist_destroy(BlocksInsideLoop);
					return false;
				}
				
				insn_iter= LLVMGetNextInstruction(insn_iter) ;
			}
		
			
		}
		
		
		worklist_t exitblocks = worklist_create();
		exitblocks = LLVMGetExitBlocks(loop);
		while(!worklist_empty(exitblocks))
		{
			LLVMBasicBlockRef exit = LLVMValueAsBasicBlock(worklist_pop(exitblocks));
			if(!LLVMDominates(LLVMGetBasicBlockParent(BlockHavingInsn),BlockHavingInsn, exit))
				return false;
			
		}
		// I dominates L's exits
		return true;//sdsdfs
		
		
	}

	return false;
}

bool StoreCanSink(LLVMLoopRef loop, LLVMValueRef insn, LLVMValueRef addr)
{
	LLVMBasicBlockRef BlockHavingInsn;
	LLVMValueRef insn_iter;
	BlockHavingInsn = LLVMGetInstructionParent(insn);
		
	
			
	worklist_t exitblocks = worklist_create();
	exitblocks = LLVMGetExitBlocks(loop);
	while(!worklist_empty(exitblocks))
	{
		LLVMBasicBlockRef exit = LLVMValueAsBasicBlock(worklist_pop(exitblocks));
		if(!LLVMDominates(LLVMGetBasicBlockParent(BlockHavingInsn),BlockHavingInsn, exit))
			return false;
	
	}
	
	if (LLVMLoopContainsInst(loop, addr)) 
			return false;
		
	worklist_t BlocksInsideLoop = worklist_create(); // No effect of using worklist_create :/
	BlocksInsideLoop = LLVMGetBlocksInLoop(loop);
	while(!worklist_empty(BlocksInsideLoop)) 
	{
		LLVMBasicBlockRef block_iter;
		block_iter = LLVMValueAsBasicBlock(worklist_pop(BlocksInsideLoop));
		insn_iter = LLVMGetFirstInstruction(block_iter);
		//next_insn= LLVMGetNextInstruction(insn);
		while(insn_iter != NULL)
		{
			
			if(LLVMIsACallInst(insn_iter))
			{
				LICM_BadCall++;
				worklist_destroy(BlocksInsideLoop); // To avoid memory leak 
				return false; // Badcall is incremented only once per load.
			}
			insn_iter= LLVMGetNextInstruction(insn_iter) ;
		}
	
	}
	
	
	
	
     //if (addr is a constant and there are no stores to addr in L):
	if(LLVMIsAConstant(addr) || LLVMIsAGlobalValue(addr) || LLVMIsAGlobalVariable(addr))//Address needs to be constant which is a guarantee of no calculation of address inside loop.
	{
		 
		LLVMValueRef insn_iter;
		worklist_t BlocksInsideLoop = worklist_create(); 
		BlocksInsideLoop = LLVMGetBlocksInLoop(loop);
		
		while(!worklist_empty(BlocksInsideLoop)) 
			{
				LLVMBasicBlockRef block_iter;
				block_iter = LLVMValueAsBasicBlock(worklist_pop(BlocksInsideLoop));
				insn_iter = LLVMGetFirstInstruction(block_iter);
				while(insn_iter != NULL)
				{
					if(	LLVMIsALoadInst(insn_iter) && (addr == LLVMGetOperand(insn_iter, 0))) // No store to the same address
					{
						//LICM_BadStore++;
						worklist_destroy(BlocksInsideLoop); // to avoid mempry leak
						return false;
					}
					
					insn_iter = LLVMGetNextInstruction(insn_iter);
				}
				
				
			}
			
		return true;
		
	}
	
	 //if (addr is an AllocaInst and AllocaInst is not inside the loop  
	if(LLVMIsAAllocaInst(addr) && (!LLVMLoopContainsInst(loop, addr)))
	{
		
		//LLVMValueRef next_insn;
		LLVMValueRef insn_iter;
		worklist_t BlocksInsideLoop = worklist_create(); 
		BlocksInsideLoop = LLVMGetBlocksInLoop(loop);
		
		while(!worklist_empty(BlocksInsideLoop)) 
		{
			LLVMBasicBlockRef block_iter;
			block_iter = LLVMValueAsBasicBlock(worklist_pop(BlocksInsideLoop));
			insn_iter = LLVMGetFirstInstruction(block_iter);
			
			while(insn_iter != NULL)
			{
				if(LLVMIsALoadInst(insn_iter) && (addr == LLVMGetOperand(insn_iter, 0))) //no stores to addr in L and
				{
					worklist_destroy(BlocksInsideLoop);
					return false;
				}
				
				insn_iter= LLVMGetNextInstruction(insn_iter) ; //
			}
		
			
		}
		
		return true;
	}

	
	if(!LLVMLoopContainsInst(loop, addr)) // address is not defined inside the loop
	{
		
		LLVMValueRef insn_iter;
		worklist_t BlocksInsideLoop = worklist_create(); // No effect of using worklist_create :/
		BlocksInsideLoop = LLVMGetBlocksInLoop(loop);
		
		while(!worklist_empty(BlocksInsideLoop)) 
		{
			LLVMBasicBlockRef block_iter;
			block_iter = LLVMValueAsBasicBlock(worklist_pop(BlocksInsideLoop));
			insn_iter = LLVMGetFirstInstruction(block_iter);
			//next_insn= LLVMGetNextInstruction(insn);
			while(insn_iter != NULL)
			{
				if(LLVMIsALoadInst(insn_iter))
				{
					worklist_destroy(BlocksInsideLoop);
					return false;
				}
				
				insn_iter= LLVMGetNextInstruction(insn_iter) ;
			}
		
			
		}
		
		return true;//sdsdfs		
	}

	return false;
}
void AppendBlock(LLVMLoopRef Loop , LLVMBasicBlockRef exit, LLVMValueRef F , LLVMValueRef insn)
{

	LLVMBasicBlockRef pred, new_block;
	LLVMValueRef clone2 = LLVMCloneInstruction(insn);
	for(pred  = LLVMGetFirstPredecessor(exit) ; pred != NULL ; pred = LLVMGetNextPredecessor(exit, pred))
	{
		//printf("\n1a. Inside the for loop");
		if(LLVMLoopContainsBasicBlock(Loop, pred))
		{
			LLVMValueRef br = LLVMGetBasicBlockTerminator(pred);
			if(br != NULL)
			{
				//printf("\n1b. branch ! = NULL");
				LLVMValueRef v1, v2;
				new_block = LLVMAppendBasicBlock(F, "newblock");		
				if(LLVMGetNumOperands(br)>1) // conditional branch
				{
					LLVMValueRef cond = LLVMGetOperand(br,0);
					LLVMBasicBlockRef t = LLVMValueAsBasicBlock(LLVMGetOperand(br,1));
					LLVMBasicBlockRef f = LLVMValueAsBasicBlock(LLVMGetOperand(br,2));
				
					LLVMPositionBuilderBefore(Builder, br);
					if(t== exit)
					{
						v1 = LLVMBuildCondBr(Builder, cond, new_block, f);	
					}
					if(f== exit)
					{
						v2 = LLVMBuildCondBr(Builder, cond,t, new_block);	
					}
					LLVMInstructionEraseFromParent(br);
					LLVMPositionBuilderAtEnd(Builder, new_block);
					//LLVMInsertIntoBuilder(Builder, clone);
					LLVMReplaceAllUsesWith(insn,clone2);
					LLVMInsertIntoBuilder(Builder, clone2);
					LLVMValueRef branch1 = LLVMBuildBr(Builder,exit);
					
					//LLVMReplaceAllUsesWith(insn,clone);
					
					//printf("\n1c. New predecssor: After appneding and replacing insn with clone$");//sds
					////printf("\n%s", )LLVMDumpValue(insn);
					//printf("\n2. Done with one predecessor : %s", LLVMPrintValueToString(clone2));
				}
				
				else if(LLVMGetNumOperands(br) ==1) //direct branch
				{
					LLVMBasicBlockRef double_check = LLVMValueAsBasicBlock(LLVMGetOperand(br,0));
					LLVMValueRef v1;
					if(double_check == exit)
					{
						LLVMPositionBuilderBefore(Builder, br);
				
						v1 = LLVMBuildBr(Builder, new_block);		
						LLVMInstructionEraseFromParent(br);
						
						LLVMPositionBuilderAtEnd(Builder, new_block);
						LLVMInsertIntoBuilder(Builder, clone2);
						LLVMValueRef branch1 = LLVMBuildBr(Builder,exit);
						LLVMInstructionEraseFromParent(br);	
					}			
				}
			}
		}
	}		
}

static int LICMOnFunction(LLVMValueRef F) //IterateOverLoops
{
  LLVMLoopInfoRef LI = LLVMCreateLoopInfoRef(F);
  LLVMLoopRef Loop;

  for(Loop=LLVMGetFirstLoop(LI);Loop!=NULL; Loop=LLVMGetNextLoop(LI,Loop))
    {
      // Use Loop to get its basic blocks  
		LLVMBasicBlockRef PreHeader;
		PreHeader = LLVMGetPreheader(Loop);
		if(PreHeader == NULL)
		{
			LICM_NoPreheader++;
			continue;
		}
		else
		{
			
			LLVMValueRef insn; // points to each instruction 
			worklist_t BlocksInsideLoop = worklist_create();
			BlocksInsideLoop = LLVMGetBlocksInLoop(Loop);
			while(!worklist_empty(BlocksInsideLoop)) 
			{
				LLVMBasicBlockRef block_inside_loop;
				block_inside_loop = LLVMValueAsBasicBlock(worklist_pop(BlocksInsideLoop));
				insn = LLVMGetFirstInstruction(block_inside_loop); //// iterate over each instruction in bb
				while(insn != NULL)
				{
					LLVMValueRef clone;
					LLVMValueRef tmp = LLVMGetNextInstruction(insn);
					if(LLVMMakeLoopInvariant(Loop, insn)) //LLVMMakeLoopInvariant is my function that further calls the inbuilt function fo LLVM : makeloopinvariant. See up to readd about it.
					{
						LICM_Basic++;
						insn = tmp;
						continue;
						// Handles all cases other than loads or stores
						// Assume I gets blown away 			
					}
					
					else
					{
						if(LLVMIsALoadInst(insn) && (!LLVMGetVolatile(insn)))
						{
							LLVMValueRef AddrLoad = LLVMGetOperand(insn, 0);
							if(canMoveOutOfLoop(Loop, insn, AddrLoad ))
							{
								
								LLVMUseRef use;
								int use_of_insn_inside_loop =0;
								use = LLVMGetFirstUse(insn);
								while(use != NULL) // Being used somewhre inside the module
								{
									LLVMValueRef user = LLVMGetUser(use);
									if(user != NULL && LLVMLoopContainsInst(Loop, user )) // no user inside the loop
									{
										use_of_insn_inside_loop = 1;
										break;
									}
									use = LLVMGetNextUse(use);
								}
								
								if(!use_of_insn_inside_loop)
								{
									
										//printf("\n Load sink");
										LICM_LoadSink++;
										//LLVMValueRef clone;
										clone = LLVMCloneInstruction(insn);
										//place clone at end of PH before branch
										
										worklist_t exitblocks = worklist_create();
										exitblocks = LLVMGetExitBlocks(Loop);
										while(!worklist_empty(exitblocks))
										{
											LLVMBasicBlockRef exit = LLVMValueAsBasicBlock(worklist_pop(exitblocks));
											//LLVMValueRef last = LLVMGetLastInstruction(exit);
											//printf("\n3a. One exit: Go to its predecssors: %s", LLVMPrintValueToString(insn) );
											AppendBlock(Loop, exit, F, insn);
											//printf("\n3b. After appendinf in all predecessors of one exit");
											//LLVMReplaceAllUsesWith(insn,clone);
											//LLVMDumpValue(F);
																						
										}
										
										worklist_destroy(exitblocks);
										//printf("\n4. DOne will all exits of the loop");	
										//LLVMReplaceAllUsesWith(insn,clone);
										
										//erase
										LLVMValueRef rm =insn;
										insn = LLVMGetNextInstruction(insn);
										//printf("\n5. Got the next insn:%s", LLVMPrintValueToString(insn));
										
										LLVMInstructionEraseFromParent(rm);											
										continue;
																		
								}
																
								else // used inside loop
								{
									LICM_LoadHoist++;
									LLVMValueRef clone;
									clone = LLVMCloneInstruction(insn);
									//place clone at end of PH before branch
									LLVMValueRef last = LLVMGetLastInstruction(PreHeader); // gives the last
									LLVMPositionBuilderBefore (Builder, last);
									LLVMInsertIntoBuilder (Builder, clone);
									
									LLVMReplaceAllUsesWith(insn,clone);
									
									//erase
									LLVMValueRef rm =insn;
									insn = LLVMGetNextInstruction(insn);
									LLVMInstructionEraseFromParent(rm);
									continue;
								}
							}
						}
						
						else if(LLVMIsAStoreInst(insn) && (!LLVMGetVolatile(insn)))
						{
							LLVMValueRef AddrStore = LLVMGetOperand(insn, 1);
							if(StoreCanSink(Loop, insn, AddrStore))
							//if(canMoveOutOfLoop_store(Loop, insn, AddrStore))
							{
								LICM_StoreSink++;
								LLVMValueRef clone;
								clone = LLVMCloneInstruction(insn);
								//place clone at end of PH before branch
								
								worklist_t exitblocks = worklist_create();
								exitblocks = LLVMGetExitBlocks(Loop);
								while(!worklist_empty(exitblocks))
								{
									
									//LLVMBasicBlockRef exit = LLVMValueAsBasicBlock(worklist_pop(exitblocks));
									LLVMBasicBlockRef exit;
									LLVMValueRef q = worklist_pop(exitblocks);
									if(q!=NULL)
									{
										exit = LLVMValueAsBasicBlock(q);
									}
									////printf("\n3a. One exit: Go to its predecssors");
									//printf("\n3a. One exit: Go to its predecssors: %s", LLVMPrintValueToString(insn) );
									if(exit!=NULL)
									{
										AppendBlock(Loop, exit, F, insn);
										//printf("\n3b. After appendinf in all predecessors of one exit");
									}									
									
								}
								//printf("\n4. DOne will all exits of the loop");
								//LLVMReplaceAllUsesWith(insn,clone);
								//erase
								LLVMValueRef rm =insn;
								insn = LLVMGetNextInstruction(insn);
								//printf("\n5. Got the next insn:%s", LLVMPrintValueToString(insn));
								LLVMInstructionEraseFromParent(rm);
								continue;
							}
							
						}				
					}
					
					insn= LLVMGetNextInstruction(insn);
				}
			}	
		}
    }
  return 0;
}

void LoopInvariantCodeMotion_C(LLVMModuleRef Module)
{
  LLVMValueRef func;

  Builder = LLVMCreateBuilder();

  list = worklist_create();

  for(func=LLVMGetFirstFunction(Module);func!=NULL;func=LLVMGetNextFunction(func))
    { 
		if (LLVMCountBasicBlocks(func))
			
			{
				LICMOnFunction(func);
			}
    }

  LLVMDisposeBuilder(Builder);
  Builder = NULL;

  fprintf(stderr,"LICM_Basic      =%d\n",LICM_Basic);
  fprintf(stderr,"LICM_NoPreheader=%d\n",LICM_NoPreheader);
  fprintf(stderr,"LICM_LoadHoist  =%d\n",LICM_LoadHoist);
  fprintf(stderr,"LICM_LoadSink   =%d\n",LICM_LoadSink);
  fprintf(stderr,"LICM_StoreSink  =%d\n",LICM_StoreSink);
  fprintf(stderr,"LICM_BadCall    =%d\n",LICM_BadCall);
  fprintf(stderr,"LICM_BadStore   =%d\n",LICM_BadStore);
  /*printf("LICM_Basic      =%d\n",LICM_Basic);
  printf("LICM_NoPreheader=%d\n",LICM_NoPreheader);
  printf("LICM_LoadHoist  =%d\n",LICM_LoadHoist);
  printf("LICM_LoadSink   =%d\n",LICM_LoadSink);
  printf("LICM_StoreSink  =%d\n",LICM_StoreSink);
  printf("LICM_BadCall    =%d\n",LICM_BadCall);
  printf("LICM_BadStore   =%d\n",LICM_BadStore);*/
  
}
