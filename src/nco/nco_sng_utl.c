/* $Header: /data/zender/nco_20150216/nco/src/nco/nco_sng_utl.c,v 1.5 2002-05-12 00:24:16 zender Exp $ */

/* Purpose: String utilities */

/* Copyright (C) 1995--2002 Charlie Zender
   This software is distributed under the terms of the GNU General Public License
   See http://www.gnu.ai.mit.edu/copyleft/gpl.html for full license text */

#include "nco_sng_utl.h" /* String utilities */

char * /* O [sng] Parsed command line */
cmd_ln_sng /* [fnc] Re-construct command line from arguments */
(const int argc, /* I [nbr] Argument count */
 const char * const * const argv) /* I [sng] Command line argument values */
 /* char **argv) *//* I [sng] Command line argument values */
{
  /* Purpose: Re-construct command line from argument list and number */
  char *cmd_ln; /* [sng] Parsed command line */
  
  int cmd_ln_sz=0;
  int idx;

  for(idx=0;idx<argc;idx++){
    cmd_ln_sz+=(int)strlen(argv[idx])+1;
  } /* end loop over args */
  cmd_ln=(char *)nco_malloc(cmd_ln_sz*sizeof(char));
  if(argc <= 0){
    cmd_ln=(char *)nco_malloc(sizeof(char));
    cmd_ln[0]='\0';
  }else{
    (void)strcpy(cmd_ln,argv[0]);
    for(idx=1;idx<argc;idx++){
      (void)strcat(cmd_ln," ");
      (void)strcat(cmd_ln,argv[idx]);
    } /* end loop over args */
  } /* end else */

  return cmd_ln; /* [sng] Parsed command line */
} /* end cmd_ln_sng() */

int /* O [nbr] Number of escape sequences translated */
sng_ascii_trn /* [fnc] Replace C language '\X' escape codes in string with ASCII bytes */
(char * const sng) /* I/O [sng] String to process */
{
  /* Purpose: Replace C language '\X' escape codes in string with ASCII bytes 
     Return number of escape sequences found and actually translated
     This should be same as number of bytes by which string length has shrunk
     For example, consecutive characters "\n" are translated into ASCII '\n' = 10 which diminishes string length by 1
     Function works for arbitrary number of escape codes in input string
     The escape sequence for NUL itself, \0, causes a warning and is not translated
     Input string must be NUL-terminated or NULL
     Translation is done in place, so if original string is required, it should be copied prior to calling sng_ascii_trn()
     This procedure can only diminish, not lengthen, size of input string
     Therefore it may be performed in place safely without the need to operate on a copy of the string
     Address pointed to by sng does not change, but memory at that address is altered
     when characters are "moved to the left" if C language escape sequences are embedded.
     Thus string length may shrink */

  bool trn_flg; /* Translate this escape sequence */

  char *backslash_ptr; /* [ptr] Pointer to backslash character */
  char backslash_chr='\\'; /* [chr] Backslash character */

  int esc_sqn_nbr=0; /* Number of escape sequences found */
  int trn_nbr=0; /* Number of escape sequences translated */
  
  /* ncatted allows character attributes of 0 length
     Such "strings" do not even have a NUL-terminator and so may not safely be tested by strchr() */
  if(sng == NULL) return trn_nbr;
  
  /* C language '\X' escape codes are always preceded by a backslash */
  /* Check if control codes are embedded once before entering loop */
  backslash_ptr=strchr(sng,backslash_chr);

  while(backslash_ptr != NULL){
    /* Default is to translate this escape sequence */
    trn_flg=True;
    /* Replace backslash character by corresponding control code */
    switch(*(backslash_ptr+1)){ /* man ascii:Oct   Dec   Hex   Char \X  */
    case 'a': *backslash_ptr='\a'; break; /* 007   7     07    BEL '\a' Bell */
    case 'b': *backslash_ptr='\b'; break; /* 010   8     08    BS  '\b' Backspace */
    case 'f': *backslash_ptr='\f'; break; /* 014   12    0C    FF  '\f' Formfeed */
    case 'n': *backslash_ptr='\n'; break; /* 012   10    0A    LF  '\n' Linefeed */
    case 'r': *backslash_ptr='\r'; break; /* 015   13    0D    CR  '\r' Carriage return */
    case 't': *backslash_ptr='\t'; break; /* 011   9     09    HT  '\t' Horizontal tab */
    case 'v': *backslash_ptr='\v'; break; /* 013   11    0B    VT  '\v' Vertical tab */
    case '\\': *backslash_ptr='\\'; break; /* 134   92    5C    \   '\\' */
    case '\?': *backslash_ptr='\?'; break; /* I'm not sure why or if this one works! */
    case '\'': *backslash_ptr='\''; break; /* I'm not sure why or if this one works! */
    case '\"': *backslash_ptr='\"'; break; /* I'm not sure why or if this one works! */
      /* Do not translate \0 to NUL since this would "erase" the rest of the string */
    case '0':	
      /* Do not translate \0 to NUL since this would make the rest of the string invisible to all string functions */
      /* *backslash_ptr='\0'; *//* 000   0     00    NUL '\0' */
      (void)fprintf(stderr,"%s: WARNING C language escape code %.2s found in string, not translating to NUL since this would make the rest of the string invisible to all string functions\n",prg_nm_get(),backslash_ptr);
      trn_flg=False;
      break;
    default: 
      (void)fprintf(stderr,"%s: WARNING No ASCII equivalent to possible C language escape code %.2s so no action taken\n",prg_nm_get(),backslash_ptr);
      trn_flg=False;
      break;
    } /* end switch */
    if(trn_flg){
      /* Get rid of character after backslash character */
      (void)memmove(backslash_ptr+1,backslash_ptr+2,(strlen(backslash_ptr+2)+1)*sizeof(char));
      /* Count translations performed */
      trn_nbr++;
    } /* end if */
    /* Look for next backslash starting at character following current escape sequence (but remember that not all escape sequences are translated) */
    if (trn_flg) backslash_ptr=strchr(backslash_ptr+1,backslash_chr); else backslash_ptr=strchr(backslash_ptr+2,backslash_chr);
    /* Count escape sequences */
    esc_sqn_nbr++;
  } /* end if */

  /* Usually there are no escape codes and sng still equals input value */
  if(dbg_lvl_get() > 3) (void)fprintf(stderr,"%s: DEBUG sng_ascii_trn() Found %d C-language escape sequences, translated %d of them\n",prg_nm_get(),esc_sqn_nbr,trn_nbr);

  return trn_nbr;
} /* end sng_ascii_trn() */

