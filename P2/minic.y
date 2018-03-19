%{
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "llvm-c/Core.h"
#include "llvm-c/BitReader.h"
#include "llvm-c/BitWriter.h"

#include "list.h"
#include "symbol.h"

int num_errors;

extern int yylex();   /* lexical analyzer generated from lex.l */

int yyerror();
int parser_error(const char*);

void minic_abort();
char *get_filename();
int get_lineno();

int loops_found=0;

extern LLVMModuleRef Module;
extern LLVMContextRef Context;

/*My global variables*/
char *global_name; // To get tthe name of the LLVMValueRef in the Ampersand Rule
LLVMValueRef LogicalAND_incomingVals[2];
LLVMBasicBlockRef LogicalAND_incomingBBs[2];
LLVMBuilderRef Builder;

LLVMValueRef switch_expression ;
LLVMBasicBlockRef nextcase_g;
LLVMBasicBlockRef default_block_g;
LLVMBasicBlockRef switch_exit_g;
int switch_flag =0;
int default_flag =0;

//dee  LLvmtypref  f;


LLVMValueRef Function=NULL;
LLVMValueRef BuildFunction(LLVMTypeRef RetType, const char *name, paramlist_t *params);

%}

/* Data structure for tree nodes*/

%union {
  int inum;
  float fnum;
  char * id;
  LLVMTypeRef  type;
  LLVMValueRef value;
  LLVMBasicBlockRef bb;
  paramlist_t *params;
}

/* these tokens are simply their corresponding int values, more terminals*/

%token SEMICOLON COMMA COLON
%token LBRACE RBRACE LPAREN RPAREN LBRACKET RBRACKET
%token ASSIGN PLUS MINUS STAR DIV MOD 
%token LT GT LTE GTE EQ NEQ NOT
%token LOGICAL_AND LOGICAL_OR
%token BITWISE_OR BITWISE_XOR LSHIFT RSHIFT BITWISE_INVERT

%token DOT ARROW AMPERSAND QUESTION_MARK

%token FOR WHILE IF ELSE DO STRUCT SIZEOF RETURN SWITCH
%token BREAK CONTINUE CASE DEFAULT
%token INT VOID FLOAT

/* no meaning, just placeholders */
%token STATIC AUTO EXTERN TYPEDEF CONST VOLATILE ENUM UNION REGISTER
/* NUMBER and ID have values associated with them returned from lex*/

%token <inum> CONSTANT_INTEGER /*data type of NUMBER is num union*/
%token <fnum> CONSTANT_FLOAT /*data type of NUMBER is num union*/
%token <id>  ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

/* values created by parser*/

%type <id> declarator
%type <params> param_list param_list_opt
%type <value> expression 
%type <value> assignment_expression
%type <value> conditional_expression
%type <value> constant_expression
%type <value> logical_OR_expression
%type <value> logical_AND_expression
%type <value> inclusive_OR_expression
%type <value> exclusive_OR_expression
%type <value> AND_expression
%type <value> equality_expression
%type <value> relational_expression
%type <value> shift_expression
%type <value> additive_expression
%type <value> multiplicative_expression
%type <value> cast_expression
%type <value> unary_expression
%type <value> lhs_expression
%type <value> postfix_expression
%type <value> primary_expression
%type <value> constant
%type <type> type_specifier
%type <value> opt_initializer
%type <value> expr_opt
/* 
   The grammar used here is largely borrowed from Kernighan and Ritchie's "The C
   Programming Language," 2nd Edition, Prentice Hall, 1988. 

   But, some modifications have been made specifically for MiniC!
 */

%%

/* 
   Beginning of grammar: Rules
*/

translation_unit: 			external_declaration
			| translation_unit external_declaration
;

external_declaration:	  	function_definition
{
  /* finish compiling function */
	if(num_errors>100)
	{
	  minic_abort();
	}
	else if(num_errors==0)
	{
	  
	}
}
							| declaration 
{ 
  /* nothing to be done here */
}
;

function_definition:	 	type_specifier ID LPAREN param_list_opt RPAREN 
{
	symbol_push_scope();
	/* This is a mid-rule action */
	BuildFunction($1,$2,$4);  //LLVMValueRef BuildFunction(LLVMTypeRef RetType, const char *name, paramlist_t *params)
} 
							compound_stmt 
{ 
  /* This is the rule completion */
  //LLVMDumpValue(Function); // To dump the IR into the command line 
  LLVMBasicBlockRef BB = LLVMGetInsertBlock(Builder);
  if(!LLVMGetBasicBlockTerminator(BB))
    {
      if($1==LLVMInt32Type())	
	{
	  LLVMBuildRet(Builder,LLVMConstInt(LLVMInt32TypeInContext(Context),
					    0,(LLVMBool)1));
	}
      else if($1==LLVMFloatType()) 
	{
	  LLVMBuildRet(Builder,LLVMConstReal(LLVMFloatType(),0.0));
					    
	}
      else
	{
	  LLVMBuildRetVoid(Builder);
	  
	}
    }

  symbol_pop_scope();
  /* make sure basic block has a terminator (a return statement) */
}
							| type_specifier STAR ID LPAREN param_list_opt RPAREN 
{
	symbol_push_scope();
	BuildFunction(LLVMPointerType($1,0),$3,$5);
} 
							compound_stmt 
{ 
	/* This is the rule completion */


	/* make sure basic block has a terminator (a return statement) */

	LLVMBasicBlockRef BB = LLVMGetInsertBlock(Builder);
	if(!LLVMGetBasicBlockTerminator(BB))
	{
	  LLVMBuildRet(Builder,LLVMConstPointerNull(LLVMPointerType($1,0)));
	}

	symbol_pop_scope();
}
;

declaration:    			type_specifier STAR ID opt_initializer SEMICOLON
{
  if (is_global_scope()) 
    {
      LLVMValueRef g = LLVMAddGlobal(Module,LLVMPointerType($1,0),$3);

      //Do some sanity checks .. if okay, then do this:
      LLVMSetInitializer(g,$4);
    } 
  else
    {
		LLVMValueRef val = LLVMBuildAlloca(Builder,LLVMPointerType($1,0),$3); // allocates a memory for the  pointer type to type $1 and returns the address of the allocated meory to val. and the name of the val = $3 
		symbol_insert($3,val , 0); /* map name to alloca */ /* build alloca */ /* not an arg */
      
      // Store initial value!
		if($4!= NULL)  // Store initial value if there is one
		{
			LLVMBuildStore(Builder, $4,val);
		}
      
    }

} 
							| type_specifier ID opt_initializer SEMICOLON
{
  if (is_global_scope())
    {
      LLVMValueRef g = LLVMAddGlobal(Module,$1,$2);

      // Do some checks... if it's okay:
      LLVMSetInitializer(g,$3);
    }
  else
    {
		LLVMValueRef var;
		//printf("\nVariable declaration of %s ", $2 );
		var= LLVMBuildAlloca(Builder,$1,$2);// pointer pointing to the alloca of type $1 and it will be of name $2
		symbol_insert($2, var, 0);  /* map name to alloca */ /* build alloca */ /* not an arg */
		if($3!= NULL)  // Store initial value if there is one
		{
			LLVMBuildStore(Builder, $3,var);
		}

    }
} 
;

declaration_list:	   		declaration
{

}
							| declaration_list declaration  
{

}
;


type_specifier:		  		INT 
{
  $$ = LLVMInt32Type();
}
|                         	FLOAT
{
  $$ = LLVMFloatType();
}
|                         	VOID
{
  $$ = LLVMVoidType();
}
;

declarator: 				ID
{
  $$ = $1;
}
;

opt_initializer: 			ASSIGN constant_expression	      
{
  $$ = $2;
}
| // nothing
{
  // indicate there is none
  $$ = NULL;
}
;

param_list_opt:           
{ 
  $$ = NULL;
}
							| param_list
{ 
  $$ = $1;
}
;

param_list:					param_list COMMA type_specifier declarator
{
  $$ = push_param($1,$4,$3);
}
							| param_list COMMA type_specifier STAR declarator
{
  $$ = push_param($1,$5,LLVMPointerType($3,0));
}
							| param_list COMMA type_specifier
{
  $$ = push_param($1,NULL,$3);
}
							|  type_specifier declarator
{
  /* create a parameter list with this as the first entry */
  $$ = push_param(NULL, $2, $1);
}
							| type_specifier STAR declarator
{
  /* create a parameter list with this as the first entry */
  $$ = push_param(NULL, $3, LLVMPointerType($1,0));
}
							| type_specifier
{
  /* create a parameter list with this as the first entry */
  $$ = push_param(NULL, NULL, $1);
}
;


statement:		  			expr_stmt            
							| compound_stmt        
							| selection_stmt       
							| iteration_stmt       
							| jump_stmt  
							| default_stmt
							| break_stmt
							| continue_stmt
							| case_stmt
						
;
		

expr_stmt:	           		SEMICOLON            
{ 

}
							|  expression SEMICOLON       
{ 

}
;

compound_stmt:		  		LBRACE declaration_list_opt statement_list_opt RBRACE 
{

}
;

declaration_list_opt:	
{

}
							| declaration_list
{

}
;

statement_list_opt:	
{

}
							| statement_list
{

}
;

statement_list:				statement
{

}
							| statement_list statement
{

}
;

break_stmt:              	 BREAK SEMICOLON
{
		{
			loop_info_t current_loop = get_loop();
			LLVMBasicBlockRef rejected_block = LLVMAppendBasicBlock(Function, "rejectedafterbreak.block");
			LLVMBuildBr(Builder, current_loop.exit);
			LLVMPositionBuilderAtEnd(Builder, rejected_block);
		}
		
};



continue_stmt:            CONTINUE SEMICOLON
{
	loop_info_t current_loop = get_loop();
	LLVMBasicBlockRef rejected_block = LLVMAppendBasicBlock(Function, "rejectedafterbreak.block");
	LLVMBuildBr(Builder, current_loop.reinit);
	LLVMPositionBuilderAtEnd(Builder, rejected_block);
};

selection_stmt:		  	  IF LPAREN expression RPAREN  
	{ 
		//printf("\n Condition of if executed");
		/*LLVMBasicBlockRef then= LLVMAppendBasicBlock(Function, "then.block");
		LLVMBasicBlockRef elseb = LLVMAppendBasicBlock(Function, "elseb.block");
		
		LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($3), 0, 1);
		LLVMValueRef cond = LLVMBuildICmp(Builder, LLVMIntNE, $3, zero, "cond");
		LLVMValueRef br = LLVMBuildCondBr(Builder,cond, then, elseb);
		LLVMPositionBuilderAtEnd(Builder, then);
		$<bb>$ = elseb;*/
		
		LLVMBasicBlockRef then= LLVMAppendBasicBlock(Function, "then.block");
		LLVMBasicBlockRef elseb = LLVMAppendBasicBlock(Function, "elseb.block");
		LLVMBasicBlockRef join = LLVMAppendBasicBlock(Function, "join.block");
		LLVMBasicBlockRef expr = LLVMGetInsertBlock(Builder);
		LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($3), 0, 1);
		LLVMValueRef cond = LLVMBuildICmp(Builder, LLVMIntNE, $3, zero, "cond");
		push_loop(expr, then, elseb, join);
		LLVMValueRef br = LLVMBuildCondBr(Builder,cond, then, elseb);
		LLVMPositionBuilderAtEnd(Builder, then);
		
		
		
	}

						  statement
	{
		/*LLVMBasicBlockRef join = LLVMAppendBasicBlock(Function, "join.block");
		$<bb>$ = join;		
		LLVMBuildBr(Builder, join);
		LLVMPositionBuilderAtEnd(Builder, $<bb>5);*/
		
		LLVMBuildBr(Builder, get_loop().exit);
		LLVMPositionBuilderAtEnd(Builder, get_loop().reinit);
		
	}
	
						  ELSE statement
	{
		/*LLVMBasicBlockRef join = $<bb>7;
		LLVMBuildBr(Builder, join);
		LLVMPositionBuilderAtEnd(Builder, join);*/
		
		LLVMBuildBr(Builder, get_loop().exit);
		LLVMPositionBuilderAtEnd(Builder, get_loop().exit);
		pop_loop();
		
	}
	
						  | SWITCH LPAREN expression RPAREN  
{
  // +10 BONUS POINTS for a fully correct implementation
	//printf("\n Switch");
	
		
}


							statement
{
	
}
;

iteration_stmt:		  		WHILE LPAREN 
{ 
  /* set up header basic block
     make it the new insertion point */
	LLVMBasicBlockRef cond = LLVMAppendBasicBlock(Function, "while.cond");
	LLVMBasicBlockRef body = LLVMAppendBasicBlock(Function, "while.body");
	LLVMBasicBlockRef join = LLVMAppendBasicBlock(Function, "while.join");
	LLVMBuildBr(Builder, cond);
	LLVMPositionBuilderAtEnd(Builder, cond);
	push_loop(cond,body,cond,join); //expr, body, reinit, exit
	//$<bb>$ = cond;

} 							expression RPAREN 
{ 
  /* set up loop body */
	
	LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($4), 0,1);
	LLVMValueRef comp = LLVMBuildICmp(Builder, LLVMIntNE, $4, zero, "comp");
	LLVMValueRef br = LLVMBuildCondBr(Builder, comp, get_loop().body, get_loop().exit);
	LLVMPositionBuilderAtEnd(Builder, get_loop().body);
	
	//$<bb>$ = join;

  /* create new body and exit blocks */

  /* to support nesting: */
	
} 
							statement
{
  /* finish loop */
  /*loop_info_t info = get_loop();*/
	//LLVMBuildBr(Builder, $<bb>3);
	LLVMBuildBr(Builder, get_loop().expr);
	LLVMPositionBuilderAtEnd(Builder, get_loop().exit );
	pop_loop();
}

							| FOR LPAREN expr_opt 
{
	LLVMBasicBlockRef cond = LLVMAppendBasicBlock(Function, "for.cond");
	LLVMBasicBlockRef body = LLVMAppendBasicBlock(Function, "for.body");
	LLVMBasicBlockRef join = LLVMAppendBasicBlock(Function, "for.join");
	LLVMBasicBlockRef inc = LLVMAppendBasicBlock(Function, "for.inc");
	LLVMBuildBr(Builder, cond);
	LLVMPositionBuilderAtEnd(Builder, cond);
	push_loop(cond, body,inc,join);
	//$<bb>$ = get_loop();
} 
							SEMICOLON expr_opt 
{
	
	//condition block
	LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($6), 0,1);
	LLVMValueRef icmp = LLVMBuildICmp(Builder,LLVMIntNE, $6, zero, "icmp" );
	LLVMValueRef br = LLVMBuildCondBr(Builder,icmp, get_loop().body, get_loop().exit);
	LLVMPositionBuilderAtEnd(Builder,get_loop().reinit );
	
	
} 
							SEMICOLON expr_opt 
{
	//reinit block
	LLVMValueRef br= LLVMBuildBr(Builder, get_loop().expr);
	LLVMPositionBuilderAtEnd(Builder, get_loop().body);
	

}
							RPAREN statement
{
	
	LLVMValueRef br= LLVMBuildBr(Builder, get_loop().reinit);
	LLVMPositionBuilderAtEnd(Builder, get_loop().exit);
	pop_loop();
	
}
;

expr_opt:					expression
{ 
	$$= $1;
}
							| 
{ 
	//nothing
}
;

jump_stmt:		  			RETURN SEMICOLON
{ 
  LLVMBuildRetVoid(Builder);
}
							| RETURN expression SEMICOLON
{
	//printf ("\n Yes ! I have reached till return statement ");
	printf("\nReturn ");
	LLVMBuildRet(Builder,$2);
}
;

expression:               	assignment_expression
{ 
	//printf("\n assignment to expression : %s", LLVMPrintValueToString($1));
	if(switch_flag==1)
	{
		
	}
	else
		$$=$1;
}
;

assignment_expression:      conditional_expression
{
	$$=$1;
}
							| lhs_expression ASSIGN assignment_expression
{
	//printf("\n SakdsskldI am here : %s", LLVMPrintValueToString($$));
	//if (LLVMTypeOf($1)== LLVMPointerType(LLVMInt32Type(),0) && LLVMTypeOf($3)== LLVMPointerType(LLVMInt32Type(),0)  )
	if(LLVMGetElementType(LLVMTypeOf($1))== (LLVMTypeOf($3)))
	{
		
		LLVMBuildStore(Builder, $3, $1); //Store the value represented 
		$$ = $1;
	}
	else if (LLVMGetElementType(LLVMTypeOf($1))== LLVMFloatType() && (LLVMTypeOf($3))== LLVMInt32Type())
	{
		LLVMValueRef typecasted_rhs = LLVMBuildSIToFP(Builder, $3, LLVMFloatType(), "IntToFp");
		LLVMBuildStore(Builder,typecasted_rhs , $1); //Store the value represented 
		$$ = $1;
	}
	else if(LLVMGetElementType(LLVMTypeOf($1))== LLVMInt32Type() && (LLVMTypeOf($3))== LLVMFloatType())
	{
		LLVMValueRef typecasted_rhs = LLVMBuildFPToSI(Builder, $3, LLVMInt32Type(), "FpToInt");
		LLVMBuildStore(Builder, typecasted_rhs, $1); //Store the value represented 
		$$ = $1;
	}

	else 
	{
		//Obtain a constant that is a constant pointer pointing to NULL for a specified type.
		LLVMValueRef const_null = LLVMConstPointerNull(LLVMPointerType(LLVMInt32Type(),0));// convert 0 to null
		LLVMBuildStore(Builder, const_null, $1); //Store the value represented 
		$$ = $1;
	}
}
;

conditional_expression: 	logical_OR_expression
{
	$$=$1;
}
							| logical_OR_expression QUESTION_MARK expression COLON conditional_expression
{
	LLVMValueRef cond = LLVMBuildSelect(Builder, $1, $3, $5, "ternary_op"); /*NOT CHECKED*/
}
;

constant_expression:       	conditional_expression
{ 
	$$ = $1; 
}
;

logical_OR_expression:    	logical_AND_expression
{
	$$ = $1;

}
							| logical_OR_expression LOGICAL_OR
{
	//midrule action
	//printf("\nLogical Or Operation");
	if(LLVMTypeOf($1)!= LLVMInt32Type() && LLVMTypeOf($1)!= LLVMFloatType()) // pointer
	{
		LLVMValueRef ptrtoint = LLVMBuildPtrToInt(Builder, $1, LLVMInt32Type(),"ptrtoint"  );
		LLVMValueRef zero = LLVMConstInt(LLVMTypeOf(ptrtoint),0,1);
		
		LLVMBasicBlockRef sec_op_block = LLVMAppendBasicBlock(Function, "secondop_block");
		LLVMBasicBlockRef final_val_block = LLVMAppendBasicBlock(Function, "final_val");
		LLVMValueRef cond1 = LLVMBuildICmp(Builder, LLVMIntEQ, ptrtoint, zero, "icmp"); // if $1 ==0 then we have to check the second block
		LLVMValueRef cond3 = LLVMBuildICmp(Builder, LLVMIntNE, ptrtoint, zero, "icmp");
		
		$<bb>$ = final_val_block;
		LogicalAND_incomingBBs[0] = LLVMGetInsertBlock(Builder); // get the current block
		LogicalAND_incomingVals[0] = LLVMBuildZExt(Builder, cond3, LLVMInt32Type(),"zext");
		LLVMValueRef br = LLVMBuildCondBr(Builder,cond1, sec_op_block, final_val_block);
		LLVMPositionBuilderAtEnd(Builder, sec_op_block);
		
	}
	
	else 
	{
		LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($1),0,1);
		LLVMBasicBlockRef sec_op_block = LLVMAppendBasicBlock(Function, "secondop_block");
		LLVMBasicBlockRef final_val_block = LLVMAppendBasicBlock(Function, "final_val");
		LLVMValueRef cond1 = LLVMBuildICmp(Builder, LLVMIntEQ, $1, zero, "icmp"); // if $1 ==0 then we have to check the second block
		LLVMValueRef cond3 = LLVMBuildICmp(Builder, LLVMIntNE, $1, zero, "icmp");

		$<bb>$ = final_val_block;
		LogicalAND_incomingBBs[0] = LLVMGetInsertBlock(Builder); // get the current block
		LogicalAND_incomingVals[0] = LLVMBuildZExt(Builder, cond3, LLVMInt32Type(),"zext");
		LLVMValueRef br = LLVMBuildCondBr(Builder,cond1, sec_op_block, final_val_block);
		LLVMPositionBuilderAtEnd(Builder, sec_op_block);
	}
							
}
							logical_AND_expression
{
	if(LLVMTypeOf($1)!= LLVMInt32Type() && LLVMTypeOf($1)!= LLVMFloatType()) // pointer
	{
		LLVMValueRef ptrtoint = LLVMBuildPtrToInt(Builder, $4, LLVMInt32Type(),"ptrtoint"  );
		LLVMValueRef zero = LLVMConstInt(LLVMTypeOf(ptrtoint),0,1);
		LLVMValueRef cond2 = LLVMBuildICmp(Builder, LLVMIntNE, ptrtoint, zero, "icmp");
		//LLVMValueRef cond1_2 = LLVMBuildAnd(Builder, cond2, global_cond1 , "logic_and");// NOTt Needed. Becasue if we have reached here that measn cond1 is true
		LogicalAND_incomingBBs[1] = LLVMGetInsertBlock(Builder);
		LogicalAND_incomingVals[1] = LLVMBuildZExt(Builder, cond2, LLVMInt32Type(),"zext");
		LLVMValueRef br = LLVMBuildBr(Builder, $<bb>3);
		LLVMPositionBuilderAtEnd(Builder, $<bb>3);
		
		
		LLVMValueRef phi_i = LLVMBuildPhi(Builder,LLVMInt32Type(), "i" );
		LLVMAddIncoming(phi_i, LogicalAND_incomingVals, LogicalAND_incomingBBs, 2);
		$$ = phi_i;
	}
	else
	{
		
		LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($4),0,1);
		LLVMValueRef cond2 = LLVMBuildICmp(Builder, LLVMIntNE, $4, zero, "icmp");
		//LLVMValueRef cond1_2 = LLVMBuildAnd(Builder, cond2, global_cond1 , "logic_and");// NOTt Needed. Becasue if we have reached here that measn cond1 is true
		LogicalAND_incomingBBs[1] = LLVMGetInsertBlock(Builder);
		LogicalAND_incomingVals[1] = LLVMBuildZExt(Builder, cond2, LLVMInt32Type(),"zext");
		LLVMValueRef br = LLVMBuildBr(Builder, $<bb>3);
		LLVMPositionBuilderAtEnd(Builder, $<bb>3);
		
		
		LLVMValueRef phi_i = LLVMBuildPhi(Builder,LLVMInt32Type(), "i" );
		LLVMAddIncoming(phi_i, LogicalAND_incomingVals, LogicalAND_incomingBBs, 2);
		$$ = phi_i;
	}
	
};

logical_AND_expression:   	inclusive_OR_expression
{
	$$ = $1;
}
							| logical_AND_expression LOGICAL_AND 
{	
	//midrule action
	printf("\nLogical And Operation");
	if(LLVMTypeOf($1)!= LLVMInt32Type() && LLVMTypeOf($1)!= LLVMFloatType()) // pointer 
	{
		LLVMValueRef ptrtoint = LLVMBuildPtrToInt(Builder, $1, LLVMInt32Type(),"ptrtoint"  );
		
		LLVMValueRef zero = LLVMConstInt(LLVMTypeOf(ptrtoint),0,1);
		LLVMBasicBlockRef sec_op_block = LLVMAppendBasicBlock(Function, "secondop_block");
		LLVMBasicBlockRef final_val_block = LLVMAppendBasicBlock(Function, "final_val");
		LLVMValueRef cond1 = LLVMBuildICmp(Builder, LLVMIntNE, ptrtoint, zero, "icmp");

		$<bb>$ = final_val_block;
		LogicalAND_incomingBBs[0] = LLVMGetInsertBlock(Builder); // entry block
		LogicalAND_incomingVals[0] = LLVMBuildZExt(Builder, cond1, LLVMInt32Type(),"zext");
		LLVMValueRef br = LLVMBuildCondBr(Builder,cond1, sec_op_block, final_val_block);
		LLVMPositionBuilderAtEnd(Builder, sec_op_block);
	}
	
	else //  Normal int expressions 
	{
		LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($1),0,1);
		LLVMBasicBlockRef sec_op_block = LLVMAppendBasicBlock(Function, "secondop_block");
		LLVMBasicBlockRef final_val_block = LLVMAppendBasicBlock(Function, "final_val");
		LLVMValueRef cond1 = LLVMBuildICmp(Builder, LLVMIntNE, $1, zero, "icmp");

		$<bb>$ = final_val_block;
		LogicalAND_incomingBBs[0] = LLVMGetInsertBlock(Builder); // entry block
		LogicalAND_incomingVals[0] = LLVMBuildZExt(Builder, cond1, LLVMInt32Type(),"zext");
		LLVMValueRef br = LLVMBuildCondBr(Builder,cond1, sec_op_block, final_val_block);
		LLVMPositionBuilderAtEnd(Builder, sec_op_block);
	}
	
		
}
							inclusive_OR_expression
{
	if(LLVMTypeOf($4)!= LLVMInt32Type() && LLVMTypeOf($4)!= LLVMFloatType())
	{
		LLVMValueRef ptrtoint = LLVMBuildPtrToInt(Builder, $4, LLVMInt32Type(),"ptrtoint"  );
		
		LLVMValueRef zero = LLVMConstInt(LLVMTypeOf(ptrtoint),0,1);
		
		LLVMValueRef cond2 = LLVMBuildICmp(Builder, LLVMIntNE, ptrtoint, zero, "icmp");
		//LLVMValueRef cond1_2 = LLVMBuildAnd(Builder, cond2, global_cond1 , "logic_and");// NOTt Needed. Becasue if we have reached here that measn cond1 is true
		LogicalAND_incomingBBs[1] = LLVMGetInsertBlock(Builder);
		LogicalAND_incomingVals[1] = LLVMBuildZExt(Builder, cond2, LLVMInt32Type(),"zext");
		LLVMValueRef br = LLVMBuildBr(Builder, $<bb>3);
		LLVMPositionBuilderAtEnd(Builder, $<bb>3);
		
		
		LLVMValueRef phi_i = LLVMBuildPhi(Builder,LLVMInt32Type(), "i" );
		LLVMAddIncoming(phi_i, LogicalAND_incomingVals, LogicalAND_incomingBBs, 2);
		$$ = phi_i;
	}
	else 
	{
		LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($4),0,1);
		LLVMValueRef cond2 = LLVMBuildICmp(Builder, LLVMIntNE, $4, zero, "icmp");
		//LLVMValueRef cond1_2 = LLVMBuildAnd(Builder, cond2, global_cond1 , "logic_and");// NOTt Needed. Becasue if we have reached here that measn cond1 is true
		LogicalAND_incomingBBs[1] = LLVMGetInsertBlock(Builder);
		LogicalAND_incomingVals[1] = LLVMBuildZExt(Builder, cond2, LLVMInt32Type(),"zext");
		LLVMValueRef br = LLVMBuildBr(Builder, $<bb>3);
		LLVMPositionBuilderAtEnd(Builder, $<bb>3);
		
		
		LLVMValueRef phi_i = LLVMBuildPhi(Builder,LLVMInt32Type(), "i" );
		LLVMAddIncoming(phi_i, LogicalAND_incomingVals, LogicalAND_incomingBBs, 2);
		$$ = phi_i;
	}
	
}

;

inclusive_OR_expression:  	exclusive_OR_expression
{
    $$=$1;
}
							| inclusive_OR_expression BITWISE_OR exclusive_OR_expression
{
	$$= LLVMBuildOr(Builder, $1, $3, "or_b");
}
;

exclusive_OR_expression:  	AND_expression
{
  $$ = $1;
}
							| exclusive_OR_expression BITWISE_XOR AND_expression
{
	$$= LLVMBuildXor(Builder, $1, $3, "or");
}
;

AND_expression:           	equality_expression
{
	$$ = $1;
}
							| AND_expression AMPERSAND equality_expression
{
	$$= LLVMBuildAnd(Builder, $1, $3, "and_s"); /*& = Bitwise AND */
}
;

equality_expression:      	relational_expression
{
	$$ = $1;
}
							| equality_expression EQ relational_expression
{
	$$ = LLVMBuildICmp(Builder, LLVMIntEQ , $1, $3, "EQ");
}
							| equality_expression NEQ relational_expression
{
  
	$$ = LLVMBuildICmp(Builder, LLVMIntNE , $1, $3, "EQ");
}
;

relational_expression:    	shift_expression
{
    //$$=$1;
}
							| relational_expression LT shift_expression
{
	//printf("\nRelational Expression : Lesser Than");
	LLVMValueRef icmp  = LLVMBuildICmp(Builder, LLVMIntSLT , $1, $3, "LT");
	$$ = LLVMBuildZExt(Builder, icmp, LLVMInt32Type(),"TypeCastBooltoInt32");
	
	
}
							| relational_expression GT shift_expression
{
  
	//printf("\nRelational Expression : Greater Than");
	//LLVMDumpValue(Function);
	LLVMValueRef icmp = LLVMBuildICmp(Builder, LLVMIntSGT , $1, $3, "GT");
	$$ = LLVMBuildZExt(Builder, icmp, LLVMInt32Type(),"TypeCastBooltoInt32");
	
}
							| relational_expression LTE shift_expression
{
	//printf("\nRelational Expression : Less Equal than");
	LLVMValueRef icmp = LLVMBuildICmp(Builder, LLVMIntSLE , $1, $3, "LE");
	$$ = LLVMBuildZExt(Builder, icmp, LLVMInt32Type(),"TypeCastBooltoInt32");
}
							| relational_expression GTE shift_expression
{
 
	LLVMValueRef icmp = LLVMBuildICmp(Builder, LLVMIntSGE , $1, $3, "GE");
	$$ = LLVMBuildZExt(Builder, icmp, LLVMInt32Type(),"TypeCastBooltoInt32");
}
;

shift_expression:         	additive_expression
{
	//printf("\n additive to shift: %s", LLVMPrintValueToString($1));
    $$=$1;
}
							| shift_expression LSHIFT additive_expression
{
	$$ = LLVMBuildShl(Builder, $1, $3, "lshift");
}
							| shift_expression RSHIFT additive_expression
{
	$$ = LLVMBuildLShr(Builder, $1, $3, "rshift");
}
;

additive_expression:     	 multiplicative_expression
{
	//printf("\nRule: multiplicative to addtive");
	$$ = $1;
}
							| additive_expression PLUS multiplicative_expression
{
	//printf("\n Rule :  additive_expression: %s ADD  multiplicative_expression: %s", LLVMPrintValueToString($1), LLVMPrintValueToString($3));
	if(LLVMTypeOf($1)== LLVMTypeOf($3))
	{
		
		$$ = LLVMBuildAdd(Builder, $1, $3, "add");
	}
	else if(LLVMTypeOf($1)== LLVMFloatType() && LLVMTypeOf($3) == LLVMInt32Type() )
	{
		//printf("\n Type Mismatch while addition");
		//LLVMValueRef typecasted_firstoperand = LLVMBuildSIToFP(Builder, $3, LLVMFloatType(), "IntToFp");
		LLVMValueRef typecasted_secondoperand = LLVMBuildSIToFP(Builder, $3, LLVMFloatType(), "IntToFp");
		$$ = LLVMBuildAdd(Builder, $1, typecasted_secondoperand, "fadd");	
	}
	else if( LLVMTypeOf($1)== LLVMInt32Type() && LLVMTypeOf($3) == LLVMFloatType())
	{
		LLVMValueRef typecasted_secondoperand = LLVMBuildFPToSI(Builder, $3, LLVMInt32Type(), "IntToFp");
		$$ = LLVMBuildAdd(Builder, $1, typecasted_secondoperand, "fadd");	
	}

}	
							| additive_expression MINUS multiplicative_expression
{
	//printf("\n Rule :  additive_expression: %s MINUS  multiplicative_expression: %s", LLVMPrintValueToString($1), LLVMPrintValueToString($3));
	
	if(LLVMTypeOf($1)== LLVMTypeOf($3))
	{
		
		$$ = LLVMBuildSub(Builder, $1, $3, "sub");
	}
	else if(LLVMTypeOf($1)== LLVMFloatType() && LLVMTypeOf($3) == LLVMInt32Type() )
	{
		//printf("\n Type Mismatch while addition");
		//LLVMValueRef typecasted_firstoperand = LLVMBuildSIToFP(Builder, $3, LLVMFloatType(), "IntToFp");
		LLVMValueRef typecasted_secondoperand = LLVMBuildSIToFP(Builder, $3, LLVMFloatType(), "IntToFp");
		$$ = LLVMBuildSub(Builder, $1, typecasted_secondoperand, "fsub");	
	}
	else if( LLVMTypeOf($1)== LLVMInt32Type() && LLVMTypeOf($3) == LLVMFloatType())
	{
		LLVMValueRef typecasted_secondoperand = LLVMBuildFPToSI(Builder, $3, LLVMInt32Type(), "IntToFp");
		$$ = LLVMBuildSub(Builder, $1, typecasted_secondoperand, "fsub");	
	}
}
;

multiplicative_expression:  cast_expression
{
	//printf("\n rule: cast to multiplicative");
	$$ = $1;
}
							| multiplicative_expression STAR cast_expression
{
	//printf("\n Rule : Multiplicative expression: %s STAR cast_expression: %s ",LLVMPrintValueToString($1), LLVMPrintValueToString($3) );

	if(LLVMTypeOf($1)== LLVMTypeOf($3))
	{
		
		$$ = LLVMBuildMul(Builder, $1, $3, "mul");
	}
	else if(LLVMTypeOf($1)== LLVMFloatType() && LLVMTypeOf($3) == LLVMInt32Type() )
	{
		//printf("\n Type Mismatch while addition");
		//LLVMValueRef typecasted_firstoperand = LLVMBuildSIToFP(Builder, $3, LLVMFloatType(), "IntToFp");
		LLVMValueRef typecasted_secondoperand = LLVMBuildSIToFP(Builder, $3, LLVMFloatType(), "IntToFp");
		$$ = LLVMBuildMul(Builder, $1, typecasted_secondoperand, "fmul");	
	}
	else if( LLVMTypeOf($1)== LLVMInt32Type() && LLVMTypeOf($3) == LLVMFloatType())
	{
		LLVMValueRef typecasted_secondoperand = LLVMBuildFPToSI(Builder, $3, LLVMInt32Type(), "IntToFp");
		$$ = LLVMBuildMul(Builder, $1, typecasted_secondoperand, "fmul");	
	}
}
							| multiplicative_expression DIV cast_expression
{
 
	//printf("\n Rule : Multiplicative expression: %s DIV cast_expression: %s ",LLVMPrintValueToString($1), LLVMPrintValueToString($3) );

	if(LLVMTypeOf($1)== LLVMTypeOf($3))
	{
		
		$$ = LLVMBuildSDiv(Builder, $1, $3, "div");
	}
	else if(LLVMTypeOf($1)== LLVMFloatType() && LLVMTypeOf($3) == LLVMInt32Type() )
	{
		//printf("\n Type Mismatch while addition");
		//LLVMValueRef typecasted_firstoperand = LLVMBuildSIToFP(Builder, $3, LLVMFloatType(), "IntToFp");
		LLVMValueRef typecasted_secondoperand = LLVMBuildSIToFP(Builder, $3, LLVMFloatType(), "IntToFp");
		$$ = LLVMBuildSDiv(Builder, $1, typecasted_secondoperand, "fdiv");	
	}
	else if( LLVMTypeOf($1)== LLVMInt32Type() && LLVMTypeOf($3) == LLVMFloatType())
	{
		LLVMValueRef typecasted_secondoperand = LLVMBuildFPToSI(Builder, $3, LLVMInt32Type(), "IntToFp");
		$$ = LLVMBuildSDiv(Builder, $1, typecasted_secondoperand, "fdiv");	
	}
}
							| multiplicative_expression MOD cast_expression
{
	if(LLVMTypeOf($1)== LLVMInt32Type())
	{
		$$ = LLVMBuildSRem(Builder, $1, $3, "mod");
	}
	else
	{
		parser_error("\nSG_Error : Modolus can be performed only on Int ");
	}
	
	
}
;

cast_expression:         	 unary_expression
{ $$ = $1; }
;

lhs_expression:           	 ID 
{
	//printf("\n ID to LHS expression: %s", $1);
	int isArg=0;
	LLVMValueRef val = symbol_find($1,&isArg);
	$$ = val;
	//printf("\n Value of LLVmVALREF after assigning to LHS : %s", LLVMPrintValueToString($$));
}
							 | STAR ID
{
  LLVMValueRef val = symbol_find($2,NULL);
  $$ = LLVMBuildLoad(Builder,val,"");
}
;

unary_expression:         	 postfix_expression
{
	//printf("\n Postfix to unary : %s", LLVMPrintValueToString($1));
	$$ = $1;
}
							 | AMPERSAND primary_expression
{
  /* Implement */
	
    //$$ = LLVMGetOperand($2); // LLVMValueref return that has the value of 	
	//LLVMValueRef var = LLVMBuildLoad(Builder, var, $2 ); //Buildload uses var as the address operand to load the value from memory. 
	char *name = global_name;
	//symbol_find will use the name passed to it and find the symbol_info pointer from the hashmap and return the LLVMValueRef 
	//$2 is a valueref. And we need to pass a name to the symbol find.
	if(symbol_find(name, 0)!= NULL)/*Not an arg*/
		$$ = symbol_find(name, 0) ;
	else
	{
		parser_error("\nNot a correct expression whose address can be computed");
		YYABORT;
	}

}
							  | STAR primary_expression
{
  /* FIXME */
    char *name = global_name;
	 //Buildload uses var as the address operand to load the value from memory.
	LLVMValueRef val = symbol_find(name, 0);
	$$ = LLVMBuildLoad(Builder, LLVMBuildLoad(Builder, val, ""), "");
	
}
							  | MINUS unary_expression
{
	if(LLVMTypeOf($2)== LLVMInt32Type())
		$$ = LLVMBuildNeg(Builder, $2, "neg");
	else if(LLVMTypeOf($2)== LLVMFloatType())
		$$ = LLVMBuildFNeg(Builder, $2, "Fneg");
	else
	{
		parser_error("\nSG_ERROR: Negation done on wrong operand type!!");
	}
}
							  | PLUS unary_expression
{
	$$ = $2;
}
							  | BITWISE_INVERT unary_expression
{
	if(LLVMTypeOf($2)== LLVMInt32Type())
		$$ = LLVMBuildNot(Builder, $2,"not");
	else 
	{
		parser_error("\nSG_ERROR: Bitwise Invert can happen only on int32 types!!");
		YYABORT; //or return 1
	}
}
							  | NOT unary_expression
{
	
	if(LLVMTypeOf($2)== LLVMInt32Type())
	{
		LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($2),0,1);
		LLVMValueRef icmp = LLVMBuildICmp(Builder, LLVMIntEQ, $2, zero, "Not");
		$$ = LLVMBuildZExt(Builder, icmp, LLVMTypeOf($2),"Not");
	}
	
	else if(LLVMTypeOf($2)== LLVMFloatType())
	{
		LLVMValueRef zero = LLVMConstReal(LLVMTypeOf($2),0.0);
		LLVMValueRef fcmp = LLVMBuildFCmp(Builder, LLVMIntEQ, $2, zero, "Not");
		$$ = LLVMBuildZExt(Builder, fcmp, LLVMTypeOf($2),"Not");
	}
	
	
	
}
;


postfix_expression:      	   primary_expression
{
  $$ = $1;
}
;

primary_expression:       	   ID 
{ 
  LLVMValueRef val = symbol_find($1,NULL);
  //printf("\n LLVmValue corresposnding to the ID : %s", LLVMPrintValueToString(val));
  global_name = $1;
  $$ = LLVMBuildLoad(Builder,val,"");
}
							   | constant
{
	//printf("\n Constant -> primary_expression");
	$$ = $1;
}
							   | LPAREN expression RPAREN
{
	//printf("\n Expression to primary expression (%s) ", LLVMPrintValueToString($2));
	$$ = $2;
}
;

constant:	          			CONSTANT_INTEGER  
{ 
	
	$$ = LLVMConstInt(LLVMInt32Type(),$1,0);
} 
|                         		CONSTANT_FLOAT
{
	$$ = LLVMConstReal(LLVMFloatType(),$1);
}
;

%%

LLVMValueRef BuildFunction(LLVMTypeRef RetType, const char *name, paramlist_t *params)
{
  int i;
  int size = paramlist_size(params);
  LLVMTypeRef *ParamArray = malloc(sizeof(LLVMTypeRef)*size);
  LLVMTypeRef FunType;
  LLVMBasicBlockRef BasicBlock;

  paramlist_t *tmp = params;
  /* Build type for function */
  for(i=size-1; i>=0; i--) 
    {
      ParamArray[i] = tmp->type;
      tmp = next_param(tmp);
    }
  
  FunType = LLVMFunctionType(RetType,ParamArray,size,0);

  Function = LLVMAddFunction(Module,name,FunType);
  
  /* Add a new entry basic block to the function */
  BasicBlock = LLVMAppendBasicBlock(Function,"entry");

  /* Create an instruction builder class */
  Builder = LLVMCreateBuilder();

  /* Insert new instruction at the end of entry block */
  LLVMPositionBuilderAtEnd(Builder,BasicBlock);

  tmp = params;
  for(i=size-1; i>=0; i--)
    {
      LLVMValueRef alloca = LLVMBuildAlloca(Builder,tmp->type,tmp->name);
      LLVMBuildStore(Builder,LLVMGetParam(Function,i),alloca);
      symbol_insert(tmp->name,alloca,0);
      tmp=next_param(tmp);
    }

  return Function;
}

extern int line_num;
extern char *infile[];
static int   infile_cnt=0;
extern FILE * yyin;

int parser_error(const char *msg)
{
  printf("%s (%d): Error -- %s\n",infile[infile_cnt-1],line_num,msg);
  return 1;
}

int internal_error(const char *msg)
{
  printf("%s (%d): Internal Error -- %s\n",infile[infile_cnt-1],line_num,msg);
  return 1;
}

int yywrap() {
  static FILE * currentFile = NULL;

  if ( (currentFile != 0) ) {
    fclose(yyin);
  }
  
  if(infile[infile_cnt]==NULL)
    return 1;

  currentFile = fopen(infile[infile_cnt],"r");
  if(currentFile!=NULL)
    yyin = currentFile;
  else
    printf("Could not open file: %s",infile[infile_cnt]);

  infile_cnt++;
  
  return (currentFile)?0:1;
}

int yyerror()
{
  parser_error("Un-resolved syntax error.");
  return 1;
}

char * get_filename()
{
  return infile[infile_cnt-1];
}

int get_lineno()
{
  return line_num;
}


void minic_abort()
{
  parser_error("Too many errors to continue.");
  exit(1);
}
