%{
#include <stdio.h>
#include "llvm-c/Core.h"
#include "llvm-c/BitReader.h"
#include "llvm-c/BitWriter.h"
#include <string.h>
#include "uthash.h"

#include <errno.h>
  //#include <search.h>

extern FILE *yyin;
int yylex(void);
int yyerror(const char *);

extern char *fileNameOut;

extern LLVMModuleRef Module;
extern LLVMContextRef Context;

LLVMValueRef Function;
LLVMBasicBlockRef BasicBlock;
LLVMBuilderRef Builder;

int params_cnt=0;/*paramcount to calculate the number of input arguments*/

struct TmpMap{
  char *key;                  /* key */
  int val;                /* data */
  UT_hash_handle hh;         /* makes this structure hashable */
};
  
struct TmpMap *map = NULL;    /* important! initialize to NULL */
struct TmpMap *resultmap = NULL;

/*get_val and add_val to read and write to the hasmap of the varlist(input arguments)*/
void add_val(char *tmp, int val) { 
  struct TmpMap *s; 
  s = malloc(sizeof(struct TmpMap)); 
  s->key = strdup(tmp); 
  s->val = val; 
  HASH_ADD_KEYPTR( hh, map, s->key, strlen(s->key), s ); 
}

int get_val(char *tmp) {
  struct TmpMap *s;
  HASH_FIND_STR( map, tmp, s );  /* s: output pointer */
  if (s) 
    return s->val;
  else 
    return -1; // returns NULL if not found
}
/*get_val_1 and add_val_1 to read and write to the hasmap of the temporary variables created*/
void add_val_1(char *tmp, int val) { 
  struct TmpMap *s; 
  s = malloc(sizeof(struct TmpMap));
  s->key = strdup(tmp); 
  s->val = val; 
  HASH_ADD_KEYPTR( hh, resultmap, s->key, strlen(s->key), s ); 
}

int get_val_1(char *tmp) {
  struct TmpMap *s;
  HASH_FIND_STR( resultmap, tmp, s );  /* s: output pointer */
  if (s) 
    return s->val;
  else 
    return -1; // returns NULL if not found
}


struct tmparray_t {
  int size;
  LLVMValueRef val[32];
} ;

struct tmparray_t mytmparray[1000];
int tmpcount =0; // global vairable that refers to the current position to be inserted into. 
%}

%union {
  char *tmp;
  int num;
  char *id;
  int  val;
}

%token ASSIGN SEMI COMMA MINUS PLUS VARS MIN MAX LBRACE RBRACE SUM TMP NUM ID MULTIPLY DIVIDE 
%type <tmp> TMP 
%type <num> NUM 
%type <id> ID
%type <val>  primitive expr expr_or_list stmtlist program stmt list list_ops

//%nonassoc QUESTION COLON
%left PLUS MINUS
%left MULTIPLY DIVIDE

%start program

%%

program: 	decl stmtlist 
		{ 
		// 	LLVMBuildRet(Builder,LLVMConstInt(LLVMInt64Type(),$2,0));
		//	printf("\nValue of TMP returned in the program rule:%d", $2);
		//	printf("Value returned is : %s", LLVMPrintValueToString(mytmparray[$2].val[0]));
			LLVMBuildRet(Builder,mytmparray[$2].val[0]);
		}
;

decl: 		VARS varlist SEMI 
		{  
  			/* NO NEED TO CHANGE ANYTHING IN THIS RULE */

 			 /* Now we know how many parameters we need.  Create a function type
     			and add it to the Module */

  			LLVMTypeRef Integer = LLVMInt64TypeInContext(Context);

 			LLVMTypeRef *IntRefArray = malloc(sizeof(LLVMTypeRef)*params_cnt);
			int i;
  
  			/* Build type for function */
  			for(i=0; i<params_cnt; i++)
    				IntRefArray[i] = Integer;

  			LLVMBool var_arg = 0; /* false */
  			LLVMTypeRef FunType = LLVMFunctionType(Integer,IntRefArray,params_cnt,var_arg);

  			/* Found in LLVM-C -> Core -> Modules */
  			char *tmp, *out = fileNameOut;

  			if ((tmp=strchr(out,'.'))!='\0')
    			{
     				 *tmp = 0;
    			}

 			 /* Found in LLVM-C -> Core -> Modules */
  			Function = LLVMAddFunction(Module,out,FunType);

  			/* Add a new entry basic block to the function */
  			BasicBlock = LLVMAppendBasicBlock(Function,"entry");

  			/* Create an instruction builder class */
  			Builder = LLVMCreateBuilder();

  			/* Insert new instruction at the end of entry block */
  			LLVMPositionBuilderAtEnd(Builder,BasicBlock);
		}
;

varlist:	 varlist COMMA ID 
		{
  			if(get_val($3)== -1)
			{
  				add_val($3,params_cnt );
 				params_cnt++;
			}
			else
			{
				printf("\nSG_ERROR:Redeclaration of arguments not allowed!");
				YYABORT;
			}

		}

		| ID
		{			
  			/* IMPLEMENT: remember ID and its position for later reference*/
			add_val($1,params_cnt);
			params_cnt++;
 
		}
;

stmtlist: 	 stmtlist stmt 
		{
			$$= $2;
		//	printf("\nValue of TMP returned in the stmtlist rule: %d", $$);

		}
		| stmt         
		{
			$$= $1;
		//	printf("\nValue of TMP returned in the stmtlist rule: %d", $$);

		}          
;         

stmt: 		TMP ASSIGN expr_or_list SEMI
		{
		//	printf("value of tmpcount before assigning in resultmap:%d ", tmpcount);
			add_val_1($1, tmpcount);
		//	printf("\nThe value from resultmap at key %s: %d", $1, get_val_1($1));
			mytmparray[tmpcount].size = mytmparray[$3].size;
			int i;
			for(i=0; i< mytmparray[tmpcount].size; i++)
			{
				mytmparray[tmpcount].val[i]= mytmparray[$3].val[i];
		//		printf("Vue cpoped: %s", LLVMPrintValueToString(mytmparray[tmpcount].val[i]));	
			}
		//	printf("\nValue of TMP returned in the stmt rule: %d",tmpcount);
			$$ = tmpcount;
			tmpcount++;

		}
		| TMP ASSIGN MIN expr_or_list SEMI
		{
		//	printf("\nMIN : value of tmpcount before assigning in resultmap:%d %s", tmpcount, $1);
			add_val_1($1, tmpcount);
		//	printf("i am here");
		//	printf("\nThe value from resultmap at key %s: %d", $1, get_val_1($1));
			mytmparray[tmpcount].size =1 ;
			int i;	
			mytmparray[tmpcount].val[0]= mytmparray[$4].val[0];
			for(i=1; i< mytmparray[$4].size;i++)
			{
				LLVMValueRef True_False;
				True_False= LLVMBuildICmp(Builder,LLVMIntSLT,mytmparray[$4].val[i],mytmparray[tmpcount].val[0],"greater than");
				mytmparray[tmpcount].val[0]= LLVMBuildSelect(Builder,True_False,mytmparray[$4].val[i],mytmparray[tmpcount].val[0] ,"assign");
				
			}
		//	printf("Min caculated is: %s", LLVMPrintValueToString(mytmparray[tmpcount].val[0]));
			$$= tmpcount;
			tmpcount++;


		}
		| TMP ASSIGN MAX expr_or_list SEMI
		{
		//	printf("\nMAX : value of tmpcount before assigning in resultmap:%d %s", tmpcount, $1);
			add_val_1($1, tmpcount);
		//	printf("i am here");
		//	printf("\nThe value from resultmap at key %s: %d", $1, get_val_1($1));
			mytmparray[tmpcount].size =1 ;
			int i;	
			mytmparray[tmpcount].val[0]= mytmparray[$4].val[0];
			for(i=1; i< mytmparray[$4].size;i++)
			{
				LLVMValueRef True_False;
				True_False= LLVMBuildICmp(Builder,LLVMIntSGT,mytmparray[$4].val[i],mytmparray[tmpcount].val[0],"greater than");
		//		printf("\nValue of True_false: %s", LLVMPrintValueToString(True_False));
				mytmparray[tmpcount].val[0]= LLVMBuildSelect(Builder,True_False,mytmparray[$4].val[i],mytmparray[tmpcount].val[0] ,"assign");
				
			}
		//	printf("Max caculated is: %s", LLVMPrintValueToString(mytmparray[tmpcount].val[0]));
			$$= tmpcount;
			tmpcount++;
		
	
		}
		| TMP ASSIGN SUM expr_or_list SEMI
		{
		//	printf("\nSUM : value of tmpcount before assigning in resultmap:%d %s", tmpcount, $1);
			add_val_1($1, tmpcount);
		//	printf("\nThe value from resultmap at key %s: %d", $1, get_val_1($1));
			mytmparray[tmpcount].size =1 ;
			int i;
			mytmparray[tmpcount].val[0]= mytmparray[$4].val[0]; //Important to initialise
			for(i=1; i< mytmparray[$4].size; i++)
			{
				mytmparray[tmpcount].val[0]= LLVMBuildAdd(Builder,mytmparray[tmpcount].val[0], mytmparray[$4].val[i], "add_list_o");
			}
		//	printf("Sum caculated is: %s", LLVMPrintValueToString(mytmparray[tmpcount].val[0]));
			$$= tmpcount;
			tmpcount++;
		}
;

expr_or_list:   expr
		{
			//printf("\nValue of tmpcount in the expr_or_list:%d",$1 );
			$$= $1;
		}
              | list
		{
			$$= $1;
		}
;

list : 		LBRACE list_ops RBRACE
		{
			$$ = $2;
		}
;

list_ops :	 primitive 
		{
		//	printf("\nList mmaking start at %d", tmpcount);
			//mytmparray[tmpcount].size= mytmparray[$1].size;
			int local_size= mytmparray[$1].size;
			int i;
			for(i=0; ((i< local_size)&& (i< 32)); i++)
			{
				mytmparray[tmpcount].val[i]= mytmparray[$1].val[i];
		//		printf("\nVue cpoped in list : %s", LLVMPrintValueToString(mytmparray[tmpcount].val[i]));	

			}
			mytmparray[tmpcount].size = i;
			$$= tmpcount;
			tmpcount++;	// Whn it goes to Primitive rule:it shoudl add the Num in enw tmpcount 
			
		}
		| list_ops COMMA primitive
		{
			int local_size= mytmparray[$1].size;
			int count_copy= mytmparray[$3].size;
			int i;
		//	printf("\nLocal size:%d", local_size);
			for(i=0; ( (i< count_copy) && ((i+local_size)<32) ); i++)
			{
				mytmparray[$1].val[local_size+i] = mytmparray[$3].val[i];
		//		printf("\nVue cpoped in list : %s", LLVMPrintValueToString(mytmparray[$1].val[i+local_size]));	

			}
			//mytmparray[$1].size= mytmparray[$1].size + mytmparray[$3].size;
			mytmparray[$1].size = i + local_size;
			$$= $1;	
		}
	
;


expr:		 expr MINUS expr
		 {
			int i;
			if(mytmparray[$1].size != mytmparray[$3].size)
			{
				yyerror("\nSG_ERROR: Operation on lists of unequal sizes cannot be performed!");
				YYABORT;
			}
			else
			{
				for( i=0; i<mytmparray[$1].size; i++)
				{
					mytmparray[tmpcount].val[i]=LLVMBuildSub(Builder, mytmparray[$1].val[i], mytmparray[$3].val[i], "sub_op");
					mytmparray[tmpcount].size= mytmparray[$1].size;
				}
				$$= tmpcount;
				tmpcount++;
			}
		 }
		| expr PLUS expr
		{
			int i;
			if(mytmparray[$1].size != mytmparray[$3].size)
			{
				yyerror("\nSG_ERROR: Operation on lists of unequal sizes cannot be performed!");
				YYABORT;
			}
			else
			{
				for( i=0; i<mytmparray[$1].size; i++)
				{
					mytmparray[tmpcount].val[i]= LLVMBuildAdd(Builder, mytmparray[$1].val[i], mytmparray[$3].val[i], "add_op");
					mytmparray[tmpcount].size = mytmparray[$1].size;
				}
				$$= tmpcount;
				tmpcount++;
			}

		}
		 | MINUS expr
		{
			int i;
			for(i=0;i< mytmparray[$2].size; i++)
			{
				mytmparray[tmpcount].val[i]= LLVMBuildNeg(Builder, mytmparray[$2].val[i], "neg_op");
				mytmparray[tmpcount].size = mytmparray[$2].size;
			}
			$$= tmpcount;
			tmpcount++;
		} 
		 | expr MULTIPLY expr
		{
			int i;
			if(mytmparray[$1].size != mytmparray[$3].size)
			{
				yyerror("\nSG_ERROR: Operation on lists of unequal sizes cannot be performed!");
				YYABORT;
			}
			else
			{
				for(i=0; i< mytmparray[$1].size; i++)
				{
					mytmparray[tmpcount].val[i]= LLVMBuildMul(Builder, mytmparray[$1].val[i], mytmparray[$3].val[i], "mul_op");
					mytmparray[tmpcount].size = mytmparray[$1].size;
				}
				$$= tmpcount;
				tmpcount++;
			}
		}
		 | expr DIVIDE expr
		{
			int i;
			if(mytmparray[$1].size != mytmparray[$3].size)
			{
				yyerror("\nSG_ERROR: Operation on lists of unequal sizes cannot be performed!");
				YYABORT;
			}
			else
			{
				for(i=0; i< mytmparray[$1].size; i++)
				{
					mytmparray[tmpcount].val[i]= LLVMBuildSDiv(Builder, mytmparray[$1].val[i], mytmparray[$3].val[i], "div_op");
					mytmparray[tmpcount].size = mytmparray[$1].size;
				}
				$$= tmpcount;
				tmpcount++;
			}

		}
     	    | primitive
	      {
		$$= $1;
	      }
;

primitive :   ID
	      {
		//printf("\ntmpcount in primitive: ID: %d", tmpcount);
		mytmparray[tmpcount].size=1;
		if(get_val($1)!= -1) // To check in the hashmap of variable list
		{
			mytmparray[tmpcount].val[0]=  LLVMGetParam(Function, get_val($1));
			$$= tmpcount;
		//printf("\nThe value of input parameter %s (with Key: %d) is %s",$1,get_val($1), LLVMPrintValueToString(mytmparray[tmpcount].val[0]));
			tmpcount++;
		}
		else
		{
			yyerror("\nSG_ERROR: Undefined variable in the varlist used!");
			YYABORT;
		}
	      }
	    | TMP
	      {
		//printf("\nTMP  val from resultmap at key %s, %d", $1, get_val_1($1));
		if( get_val_1($1)!= -1) // To check in the hashmap of all tmp variables
			$$= get_val_1($1);
		else
			{
				yyerror("\nSG_ERROR: Undefined variable of the tmp type used!");
				YYABORT;
			}
	
	      }
	    | NUM
	      {
		//printf("\nThe Immediate value from the lexer: %d %d", $1, tmpcount);
		mytmparray[tmpcount].size =1;
		mytmparray[tmpcount].val[0]=LLVMConstInt(LLVMInt64Type(),$1,0);
		$$= tmpcount;
		tmpcount++;
	      }
;

%%

void initialize()
{
  /* IMPLEMENT: add something here if needed */
}

int line;

int yyerror(const char *msg)
{
  printf("%s at line %d.\n",msg,line);
  return 0;
}
