/* $Header: /data/zender/nco_20150216/nco/src/nco/nco_grp_utl.h,v 1.44 2012-09-06 18:38:37 pvicente Exp $ */

/* Purpose: Group utilities */

/* Copyright (C) 2011--2012 Charlie Zender
   License: GNU General Public License (GPL) Version 3
   See http://www.gnu.org/copyleft/gpl.html for full license text */

/* Usage:
   #include "nco_var_utl.h" *//* Group utilities */

#ifndef NCO_GRP_UTL_H
#define NCO_GRP_UTL_H

#define NCO_SANITY_CHECK
#define GRP_DEV
/* Symbol that encapsulates NCO 4.2.2 group development code 
1) Undocumented ncks -z command line option, that prints all groups/variables and exits
   usage:  ncks -z -D 1 in_grp.nc
2) Undocumented ncks -G command line option, that iterates the file and prints extended group information 
   usage:  ncks -G -D 1 in_grp.nc
3) Function nco_grp_itr() used by 1) and 2)
4) Function nco_has_subgrps()
*/


#ifdef HAVE_CONFIG_H
# include <config.h> /* Autotools tokens */
#endif /* !HAVE_CONFIG_H */

/* Standard header files */
#include <assert.h> /* assert() */
#include <stdio.h> /* stderr, FILE, NULL, printf */
#include <stdlib.h> /* strtod, strtol, malloc, getopt, exit */
#include <string.h> /* strcmp() */

/* 3rd party vendors */
#include <netcdf.h> /* netCDF definitions and C library */
#include "nco_netcdf.h" /* NCO wrappers for netCDF C library */

/* Personal headers */
#include "nco.h" /* netCDF Operator (NCO) definitions */
#include "nco_ctl.h" /* Program flow control functions */
#include "nco_grp_trv.h" /* Group traversal storage */
#include "nco_mmr.h" /* Memory management */

/* Dynamic array implementation of group stack */
typedef struct {
  int grp_nbr; /* [nbr] Number of items in stack = number of elements in grp_id array */
  int *grp_id; /* [ID] Group ID */
} grp_stk_sct; 

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

int /* [rcd] Return code */
nco_inq_grps_full /* [fnc] Discover and return IDs of apex and all sub-groups */
(const int grp_id, /* I [ID] Apex group */
 int * const grp_nbr, /* O [nbr] Number of groups */
 int * const grp_ids); /* O [ID] Group IDs of children */
  /* end nco_inq_grps_full() */

void
nco_grp_itr_free /* [fnc] Free group iterator */
(grp_stk_sct * const grp_stk); /* O [sct] Group stack pointer */

int /* [rcd] Return code */
nco_grp_stk_get /* [fnc] Initialize and obtain group iterator */
(const int grp_id, /* I [ID] Apex group */
 grp_stk_sct ** const grp_stk); /* O [sct] Group stack pointer */
  /* end nco_grp_stk_get() */

int /* [rcd] Return code */
nco_grp_stk_nxt /* [fnc] Find and return next group ID */
(grp_stk_sct * const grp_stk, /* O [sct] Group stack pointer */
 int * const grp_id); /* O [ID] Group ID */
  /* end nco_grp_stk_nxt() */

grp_stk_sct * /* O [sct] Group stack pointer */
nco_grp_stk_ntl /* [fnc] Initialize group stack */
(void); 
  /* end nco_grp_stk_ntl() */

void
nco_grp_stk_psh /* [fnc] Push group ID onto stack */
(grp_stk_sct * const grp_stk, /* I/O [sct] Group stack pointer */
 const int grp_id); /* I [ID] Group ID to push */
  /* end nco_grp_stk_psh() */

int /* O [ID] Group ID that was popped */
nco_grp_stk_pop /* [fnc] Remove and return group ID from stack */
(grp_stk_sct * const grp_stk); /* I/O [sct] Group stack pointer */
  /* end nco_grp_stk_pop() */

void
nco_grp_stk_free /* [fnc] Free group stack */
(grp_stk_sct * const grp_stk); /* O [sct] Group stack pointer */
/* end nco_grp_stk_free() */

int /* [rcd] Return code */
nco4_inq /* [fnc] Find and return global totals of dimensions, variables, attributes */
(const int nc_id, /* I [ID] Apex group */
 int * const att_nbr_glb, /* O [nbr] Number of global attributes in file */
 int * const dmn_nbr_all, /* O [nbr] Number of dimensions in file */
 int * const var_nbr_all, /* O [nbr] Number of variables in file */
 int * const rec_dmn_nbr, /* O [nbr] Number of record dimensions in file */
 int * const rec_dmn_ids); /* O [ID] Record dimension IDs in file */
/* end nco4_inq() */

nm_id_sct * /* O [sct] Variable extraction list */
nco4_var_lst_mk /* [fnc] Create variable extraction list using regular expressions */
(const int nc_id,  /* I [ID] netCDF group ID (root ID of input file) */
 int * const nbr_var_fl, /* O [nbr] Number of variables in input file */
 char * const * const var_lst_in, /* I [sng] User-specified list of variable names and rx's */
 const nco_bool EXCLUDE_INPUT_LIST, /* I [flg] Exclude rather than extract */
 const nco_bool EXTRACT_ALL_COORDINATES, /* I [flg] Process all coordinates */
 int * const var_xtr_nbr, /* I/O [nbr] Number of variables in current extraction list */
 int * const grp_xtr_nbr,  /* I/O [nbr] Number of groups in current extraction list (specified with -g ) */
 char * const * const grp_lst_in, /* I [sng] User-specified list of groups names to extract (specified with -g ) */
 grp_tbl_sct *trv_tbl); /* I   [sct] Group traversal table  */
  /* nco4_var_lst_mk() */

nm_id_sct * /* O [sct] Group extraction list */
nco_grp_lst_mk /* [fnc] Create group extraction list using regular expressions */
(const int nc_id, /* I [ID] netCDF file ID */
 char * const * const grp_lst_in, /* I [sng] User-specified list of group names and rx's */
 const nco_bool EXCLUDE_INPUT_LIST, /* I [flg] Exclude rather than extract */
 int * const grp_nbr); /* I/O [nbr] Number of groups in current extraction list */

int /* [rcd] Return code */
nco_grp_dfn /* [fnc] Define groups in output file */
(const int out_id, /* I [ID] netCDF output-file ID */
 nm_id_sct *grp_xtr_lst, /* [grp] Number of groups to be defined */
 const int grp_nbr); /* I [nbr] Number of groups to be defined */

int /* [rcd] Return code */
nco_def_grp_rcr
(const int in_id, /* I [ID] netCDF input-file ID */
 const int out_id, /* I [ID] netCDF output-file ID */
 const char * const prn_nm, /* I [sng] Parent group name */
 const int rcr_lvl); /* I [nbr] Recursion level */

int                                      /* O [rcd] Return code */
nco_grp_itr
(const int grp_id,                       /* I [id] Group ID */
 char * grp_pth,                         /* I [sng] Absolute group path */
 const int mode,                         /* I [enm] mode (-z or -G ) */
 grp_tbl_sct *tbl);                      /* I/O [sct] Group traversal table  */
/* end nco_grp_itr() */

int                                      /* O [rcd] Return code */
nco_has_subgrps
(const int nc_id);                       /* I [ID] NetCDF file ID */  
/* end nco_has_subgrps() */


nm_id_sct *             /* O [sct] Extraction list */
nco4_var_lst_xcl        /* [fnc] Convert exclusion list to extraction list */
(const int nc_id,       /* I [ID] netCDF file ID */
 const int nbr_var,     /* I [nbr] Number of variables in input file */
 nm_id_sct *xtr_lst,    /* I/O [sct] Current exclusion list (destroyed) */
 int * const xtr_nbr,   /* I/O [nbr] Number of variables in exclusion/extraction list */
 grp_tbl_sct *trv_tbl); /* I [sct] Group traversal table  */


nm_id_sct *                      /* O [sct] Extraction list */
nco4_var_lst_crd_add             /* [fnc] Add all coordinates to extraction list */
(const int nc_id,                /* I [ID] netCDF file ID */
 const int nbr_dim,              /* I [nbr] Number of dimensions in input file */
 const int nbr_var,              /* I [nbr] Number of variables in input file */
 nm_id_sct *xtr_lst,             /* I/O [sct] Current extraction list (destroyed) */
 int * const xtr_nbr,            /* I/O [nbr] Number of variables in current extraction list */
 const nco_bool CNV_CCM_CCSM_CF, /* I [flg] file obeys CCM/CCSM/CF conventions */
 int * const grp_xtr_nbr,        /* I [nbr] Number of groups in current extraction list (specified with -g ) */
 char * const * const grp_lst_in,/* I [sng] User-specified list of groups names to extract (specified with -g ) */
 grp_tbl_sct *trv_tbl);          /* I [sct] Group traversal table  */


void
nco4_xtr_grp_nm_fll     /* [fnc] Auxiliary function; extract full group name from a grp_trv_sct to a nm_id_sct */
(const int nc_id,       /* I [ID] netCDF file ID */
 nm_id_sct *xtr_lst,    /* I/O [sct] Current exclusion list */
 int * const xtr_nbr,   /* I [nbr] Current index in exclusion/extraction list */
 grp_trv_sct trv);      /* I [sct] Group traversal table entry */


#ifdef __cplusplus
} /* end extern "C" */
#endif /* __cplusplus */

#endif /* NCO_GRP_UTL_H */


