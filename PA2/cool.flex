%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

int num_comment = 0;
%}

/*
 * Keywords
 */
CLASS		[Cc][Ll][Aa][Ss][Ss]
ELSE		[Ee][Ll][Ss][Ee]
FI			[Ff][Ii]
IF			[Ii][Ff]
IN			[Ii][Nn]
INHERITS	[Ii][Nn][Hh][Ee][Rr][Ii][Tt][Ss]
ISVOID		[Ii][Ss][Vv][Oo][Ii][Dd]
LET			[Ll][Ee][Tt]
LOOP		[Ll][Oo][Oo][Pp]
POOL		[Pp][Oo][Oo][Ll]
THEN		[Tt][Hh][Ee][Nn]
WHILE		[Ww][Hh][Ii][Ll][Ee]
CASE		[Cc][Aa][Ss][Ee]
ESAC		[Ee][Ss][Aa][Cc]
NEW			[Nn][Ee][Ww]
OF			[Oo][Ff]
NOT			[Nn][Oo][Tt]

DARROW		=>
LE			<=
ASSIGN		<-

TRUE		t[Rr][Uu][Ee]
FALSE		f[Aa][Ll][[Ss][Ee]

/* TypeID and objectId. Object ID must begain with lower case letters. */

TYPEID		[A-Z][A-Za-z0-9_]*
OBJECTID	[a-z][A-Za-z0-9_]*

/* Integer constants */

DIGIT           [0-9]+


WHITESPACE	[ \v\t\r\f]*

ONECHAR		[\+\/\-\*\=\<\.\~\;\:\(\)\@\{\}]
 					
%x LINE_COMMENT	CMT	STR	FAILSTR
%%

{DARROW}	{ return (DARROW); }
{LE}		{ return (LE); }
{ASSIGN}	{ return (ASSIGN); }

{ONECHAR}	{ return (yytext[0]); }

{TRUE}		{
			cool_yylval.boolean = 1;
			return (BOOL_CONST);
			}

{FALSE}		{
			cool_yylval.boolean = 0;
			return (BOOL_CONST);
			}

{CLASS}		{ return (CLASS); }
{ELSE} 		{ return (ELSE); }
{FI}  		{ return (FI); }
{IF} 		{ return (IF); }
{IN} 		{ return (IN); }
{INHERITS}	{ return (INHERITS); }
{ISVOID}	{ return (ISVOID); }
{LET}		{ return (LET); }
{LOOP}		{ return (LOOP); }
{POOL}		{ return (POOL); }
{THEN}		{ return (THEN); }
{WHILE}		{ return (WHILE); }
{CASE}    	{ return (CASE); }
{ESAC}		{ return (ESAC); }
{NEW}		{ return (NEW); }
{OF}		{ return (OF); }
{NOT}		{ return (NOT); }
\n		curr_lineno++;

{WHITESPACE}	{ /* Eats up the space */}


{DIGIT}		{	
			cool_yylval.symbol = inttable.add_string(yytext);
			return INT_CONST;
			}	

{TYPEID}	{ 
			cool_yylval.symbol = idtable.add_string(yytext);
			return (TYPEID);
			}

{OBJECTID}	{
			cool_yylval.symbol = idtable.add_string(yytext);
			return (OBJECTID);
			}


--			{ BEGIN(LINE_COMMENT); }

<LINE_COMMENT>\n	{
			curr_lineno++;
			BEGIN(INITIAL);
}

<LINE_COMMENT>[^\n]	{
			// Eats up the comment
}

"(*"		{
			BEGIN(CMT);
			num_comment++;
			}

"*)"		{
 			cool_yylval.error_msg = "Unmatched *)";
 			return (ERROR);
 			}

<CMT>"(*"	{
			num_comment++;
			}
<CMT>"*)"	{
			num_comment--;

			if (num_comment == 0)
				BEGIN(INITIAL);
			}

<CMT>[^\n]	{
			/* Eats the comment */
			}

<CMT>"\n"	{
			curr_lineno++;
			}

<CMT><<EOF>>	{
			cool_yylval.error_msg = "End of file before comments closes";
			BEGIN(INITIAL);
			return (ERROR);
}



\"		{
		string_buf_ptr = string_buf;
		BEGIN(STR);
		}

<STR>\"	{
			if(string_buf_ptr-string_buf>=MAX_STR_CONST)
			{
				cool_yylval.error_msg="String constant too long";
				BEGIN(INITIAL);
				return (ERROR);
			}

		BEGIN(INITIAL);
		*string_buf_ptr++ = '\0';
		cool_yylval.symbol = stringtable.add_string(string_buf);
		return STR_CONST;
		}

<STR><<EOF>>	{
		cool_yylval.error_msg = "End of File before string closes";
		return ERROR;

		}

<STR>\0	{
		cool_yylval.error_msg = "String contains a Null character";
		return ERROR;
		BEGIN(FAILSTR);
		}

<STR>\n 	{
		curr_lineno++;
		cool_yylval.error_msg = "Unterminated String constant";
		BEGIN(INITIAL);
		return ERROR;
		}

<STR>\\n 	{ *string_buf_ptr++ = '\n'; }
<STR>\\b 	{ *string_buf_ptr++ = '\b'; }
<STR>\\t 	{ *string_buf_ptr++ = '\t'; }
<STR>\\f 	{ *string_buf_ptr++ = '\f'; }

<STR>\\\n 	{
				/* Escaped newline */
				curr_lineno++;
				*string_buf_ptr++ = '\n';
}

<STR>\\\0 	{
				/* Escaped end-of-line */
				BEGIN(FAILSTR); /* Ignore the rest of string */
				cool_yylval.error_msg = "String contains a Null character";
				return ERROR;
}

<STR>\\.	{
			*string_buf_ptr++ = yytext[1];
}

<STR>.	{ /* any character other than \n, as \n is handled above. */
		*string_buf_ptr++ = yytext[0];
}

<FAILSTR>\" {BEGIN(INITIAL);}
<FAILSTR>. { }
<FAILSTR>\n {curr_lineno++;}
<FAILSTR>\\\n {curr_lineno++;}
%%