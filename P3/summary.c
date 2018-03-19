/*
 * File: summary.c
 *
 * Description:
 *   This is where you implement your project 3 support.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* LLVM Header Files */
#include "llvm-c/Core.h"
#include "dominance.h"
#include "valmap.h"

/* Header file global to this project */
#include "summary.h"

typedef struct Stats_def {
  int functions;
  int globals;
  int bbs;

  int insns;
  int insns_nearby_dep;
  
  int allocas;

  int loads;
  int loads_alloca;
  int loads_globals;

  int stores;
  int stores_alloca;
  int stores_globals;
  
  int conditional_branches;
  int calls;

  int gep;
  int gep_load;
  int gep_alloca;
  int gep_globals;
  int gep_gep;

  int loops; //approximated by backedges
  int floats;
} Stats;

void pretty_print_stats(FILE *f, Stats s, int spaces)
{
  char spc[128];
  int i;

  // insert spaces before each line
  for(i=0; i<spaces; i++)
    spc[i] = ' ';
  spc[i] = '\0';
    
  fprintf(f,"%sFunctions.......................%d\n",spc,s.functions);
  fprintf(f,"%sGlobal Vars.....................%d\n",spc,s.globals);
  fprintf(f,"%sBasic Blocks....................%d\n",spc,s.bbs);
  fprintf(f,"%sInstructions....................%d\n",spc,s.insns);
  fprintf(f,"%sInstructions - Nearby Dep.......%d\n",spc,s.insns_nearby_dep);

  fprintf(f,"%sInstructions - Cond. Branches...%d\n",spc,s.conditional_branches);
  fprintf(f,"%sInstructions - Calls............%d\n",spc,s.calls);

  fprintf(f,"%sInstructions - Allocas..........%d\n",spc,s.allocas);
  fprintf(f,"%sInstructions - Loads............%d\n",spc,s.loads);
  fprintf(f,"%sInstructions - Loads (alloca)...%d\n",spc,s.loads_alloca);
  fprintf(f,"%sInstructions - Loads (globals)..%d\n",spc,s.loads_globals);


  fprintf(f,"%sInstructions - Stores...........%d\n",spc,s.stores);
  fprintf(f,"%sInstructions - Stores (alloca)..%d\n",spc,s.stores_alloca);
  fprintf(f,"%sInstructions - Stores (globals).%d\n",spc,s.stores_globals);


  fprintf(f,"%sInstructions - gep..............%d\n",spc,s.gep);
  fprintf(f,"%sInstructions - gep (load).......%d\n",spc,s.gep_load);
  fprintf(f,"%sInstructions - gep (alloca).....%d\n",spc,s.gep_alloca);
  fprintf(f,"%sInstructions - gep (globals)....%d\n",spc,s.gep_globals);
  fprintf(f,"%sInstructions - gep (gep)........%d\n",spc,s.gep_gep);

  fprintf(f,"%sInstructions - Other............%d\n",spc,
	  s.insns-s.conditional_branches-s.loads-s.stores-s.gep-s.calls);
  fprintf(f,"%sLoops...........................%d\n",spc,s.loops);
  fprintf(f,"%sFloats..........................%d\n",spc,s.floats);
}

void print_csv_file(const char *filename, Stats s, const char *id)
{
  FILE *f = fopen(filename,"w");
  fprintf(f,"id,%s\n",id);
  fprintf(f,"functions,%d\n",s.functions);
  fprintf(f,"globals,%d\n",s.globals);
  fprintf(f,"bbs,%d\n",s.bbs);
  fprintf(f,"insns,%d\n",s.insns);
  fprintf(f,"insns_nearby_dep,%d\n",s.insns_nearby_dep);
  fprintf(f,"allocas,%d\n",s.allocas);
  fprintf(f,"branches,%d\n",s.conditional_branches);
  fprintf(f,"calls,%d\n",s.calls);
  fprintf(f,"loads,%d\n",s.loads);
  fprintf(f,"loads_alloca,%d\n",s.loads_alloca);
  fprintf(f,"loads_globals,%d\n",s.loads_globals);
  fprintf(f,"stores,%d\n",s.stores);
  fprintf(f,"stores_alloca,%d\n",s.stores_alloca);
  fprintf(f,"stores_global,%d\n",s.stores_globals);
  fprintf(f,"gep,%d\n",s.gep);
  fprintf(f,"gep_alloca,%d\n",s.gep_load);
  fprintf(f,"gep_alloca,%d\n",s.gep_alloca);
  fprintf(f,"gep_globals,%d\n",s.gep_globals);
  fprintf(f,"gep_gep,%d\n",s.gep_gep);
  fprintf(f,"loops,%d\n",s.loops);
  fprintf(f,"floats,%d\n",s.floats);
  fclose(f);
}

Stats MyStats;

void Summarize(LLVMModuleRef Module, const char *id, const char* filename)
{
  	LLVMValueRef  fn_iter; // iterator 
	for (fn_iter = LLVMGetFirstFunction(Module); fn_iter!=NULL; fn_iter = LLVMGetNextFunction(fn_iter))
	{
		// fn_iter points to a function
    	LLVMBasicBlockRef bb_iter; /* points to each basic block one at a time */
		int blocks_per_function=0;
		valmap_t uniqueheader_map = valmap_create();
     	for (bb_iter = LLVMGetFirstBasicBlock(fn_iter);bb_iter != NULL; bb_iter = LLVMGetNextBasicBlock(bb_iter))
     	{
        	LLVMValueRef inst_iter; /* points to each instruction */
        	for(inst_iter = LLVMGetFirstInstruction(bb_iter);inst_iter != NULL; inst_iter = LLVMGetNextInstruction(inst_iter)) 
       		{
             		// get the basic block of this instruction
             	LLVMBasicBlockRef ref = LLVMGetInstructionParent(inst_iter);
				
				//Print total number of instructions
				MyStats.insns++;
				
				if(LLVMGetInstructionOpcode(inst_iter)== LLVMAlloca) // returns LLVMOpcode
				{
					//print total number of allocas
					MyStats.allocas++;
					
					
				}
				
				
				if(LLVMGetInstructionOpcode(inst_iter)== LLVMLoad)
				{
					//print total number of loads
					MyStats.loads++;
					
					LLVMValueRef address_operand = LLVMGetOperand(inst_iter, 0);
					if(LLVMGetInstructionOpcode(address_operand)== LLVMAlloca)
						MyStats.loads_alloca++;
					if(LLVMIsAGlobalVariable(address_operand))
						MyStats.loads_globals++;
					
					
				}
				if(LLVMGetInstructionOpcode(inst_iter)== LLVMStore)
				{
					//print total number of stores
					MyStats.stores++;
					
					LLVMValueRef address_operand = LLVMGetOperand(inst_iter, 1);
					if(LLVMGetInstructionOpcode(address_operand)== LLVMAlloca)
						MyStats.stores_alloca++;
					if(LLVMIsAGlobalVariable(address_operand))
						MyStats.stores_globals++;
					
				}
				
				if(LLVMGetInstructionOpcode(inst_iter)== LLVMBr)
				{
					//Conditional branches will have 3 operands . Direct branches have only one operand. 
					//Conditional branches will have condition at index 0. Direct branches have destination block reference at index 0
					if(LLVMGetNumOperands(inst_iter)!=1)
						MyStats.conditional_branches++;
				}
				if(LLVMGetInstructionOpcode(inst_iter)== LLVMCall)
				{
					MyStats.calls++;
				}
				
				if(LLVMGetInstructionOpcode(inst_iter)== LLVMGetElementPtr)
				{
					MyStats.gep++;
					
					LLVMValueRef address_operand = LLVMGetOperand(inst_iter, 0);
					if(LLVMGetInstructionOpcode(address_operand)== LLVMAlloca)
						MyStats.gep_alloca++;
					if(LLVMIsAGlobalVariable(address_operand)) // returns LLVMBool which is a "typedef int"
						MyStats.gep_globals++;
					if(LLVMGetInstructionOpcode(address_operand)== LLVMLoad)
						MyStats.gep_load++;
					if(LLVMGetInstructionOpcode(address_operand)== LLVMGetElementPtr)
						MyStats.gep_gep++;
					
				}
				
				//Instructions  produces Floating point. 
				// LLVMFPToUI = 33, LLVMFPToSI = 34, LLVMUIToFP = 35, LLVMSIToFP = 36, LLVMFPTrunc = 37,LLVMFPExt = 38
				/*if(LLVMGetInstructionOpcode(inst_iter) ==  LLVMSIToFP || LLVMGetInstructionOpcode(inst_iter) ==  LLVMUIToFP)
				{
					MyStats.floats++;
				}*/
				
				
				//LLVMTypeKind is a enum 
				//LLVmTypeRef is a typedef structure
				
				//Instructions  uses Floating point. 
				int oper_iter ;
				for(oper_iter=0; oper_iter< LLVMGetNumOperands(inst_iter); oper_iter++ )
				{
					LLVMValueRef op= LLVMGetOperand(inst_iter, oper_iter);
					LLVMTypeKind type_kind = LLVMGetTypeKind(LLVMTypeOf(op));
					if( type_kind == LLVMFloatTypeKind || type_kind == LLVMDoubleTypeKind || type_kind == LLVMHalfTypeKind || type_kind == LLVMX86_FP80TypeKind || type_kind == LLVMPPC_FP128TypeKind  )
					{
						MyStats.floats++;
						break; //If one of the operand is float, then it is a float instruction
					}
				}
				
				//Since the destination block of a branch is just an operand to the branch instruction, you can 
				//find back edges by getting the operand of a branch and testing if the destination dominates the 
				//ssbranch’s block.
				
				
				if(LLVMGetInstructionOpcode(inst_iter)== LLVMBr)
				{
					if(LLVMGetNumOperands(inst_iter)!=1)
					{
						LLVMValueRef branch1 = LLVMGetOperand(inst_iter, 1);
						LLVMBasicBlockRef branch1_ref = LLVMValueAsBasicBlock(branch1);
						if(LLVMDominates(fn_iter, branch1_ref,ref )) // branch1_ref dominates ref
						{
							if(valmap_check(uniqueheader_map, branch1)) // if branch 1 present 
							{
								//The basic block is present in the map
							}
							else // not present
							{
								valmap_insert(uniqueheader_map, branch1, 1);
								MyStats.loops++;
							}
							
						}
						LLVMValueRef branch2 = LLVMGetOperand(inst_iter, 2);
						LLVMBasicBlockRef branch2_ref = LLVMValueAsBasicBlock(branch2);
						if(LLVMDominates(fn_iter, branch2_ref,ref ))
						{
							if(valmap_check(uniqueheader_map, branch2)) // if branch 1 present 
							{
								//The basic block is present in the map
							}
							else // not present
							{
								valmap_insert(uniqueheader_map, branch2, 1);
								MyStats.loops++;
							}
						}
					}
					if(LLVMGetNumOperands(inst_iter)==1)
					{
						LLVMValueRef directbranch = LLVMGetOperand(inst_iter, 0);
						LLVMBasicBlockRef directbranch_ref = LLVMValueAsBasicBlock(directbranch);
						if(LLVMDominates(fn_iter, directbranch_ref,ref ))
						{
							if(valmap_check(uniqueheader_map, directbranch)) // if branch 1 present 
							{
								//The basic block is present in the map
							}
							else // not present
							{
								valmap_insert(uniqueheader_map, directbranch, 1);
								MyStats.loops++;
							}
						}
					}
				}
				
			
				int oper_iter1 ;
				for(oper_iter1=0; oper_iter1< LLVMGetNumOperands(inst_iter); oper_iter1++ )
				{
					LLVMValueRef op= LLVMGetOperand(inst_iter, oper_iter1);
					LLVMBasicBlockRef inst_block = LLVMGetInstructionParent(inst_iter);
					LLVMBasicBlockRef op_block = LLVMGetInstructionParent(op);
					if( inst_block == op_block)
					{
						MyStats.insns_nearby_dep++;
						break;
					}
				}
		
					
				
			}
				
			blocks_per_function ++;
			
     	}
		valmap_destroy(uniqueheader_map); // one headermap for one function. 
		MyStats.bbs = MyStats.bbs + blocks_per_function;	
		if(blocks_per_function!=0) // Not a function prototype. Function prototype is function without any block
			MyStats.functions++;	
			
			
	}
	//Global Variables are defined per module//
	LLVMValueRef global_iter;
	for (global_iter = LLVMGetFirstGlobal(Module); global_iter != NULL; global_iter = LLVMGetNextGlobal(global_iter) )
	{
		//if((LLVMIsAGlobalVariable(global_iter))) //IsaGlobal returns LLVMBOOL
		if(LLVMGetInitializer(global_iter)!= NULL) // to check whether global value is initialised or not. 
			MyStats.globals++;
	}
	
	pretty_print_stats(stdout,MyStats,0);
  	print_csv_file(filename,MyStats,id);

}

