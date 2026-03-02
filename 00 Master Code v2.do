** Author: Miriam Alvarado
** Date: April 24, 2024
** Edited: August 14, 2024
** Edited: March 2, 2026
** Version: 02
** Purpose: Master code for SSB Tax Analysis 
** STATA version 17.0 SE

************************************************
** SET LOCAL FOLDERS 
***********************************************
	global run_name Test
	global inputfolder "C:\Users\miria\Documents\01 Data\" 
	global outputfolder "G:\My Drive\02 Wellcome Fellowship\02 Project Files\05 Case Studies\02 Barbados\03 Sales Analysis\03 Graphs\\$run_name\" 
	global codefolder "G:\My Drive\02 Wellcome Fellowship\02 Project Files\05 Case Studies\02 Barbados\03 Sales Analysis\02 Code\Code to share"
	cap mkdir "$outputfolder"
	cd "$codefolder"

** setting up programs that are used later	
	*ssc install estout
	*ssc install asgen
	*cap ssc install metan
	*ssc install moss
	*ssc install regsave
	**ssc install grstyle
	* search for  scheme_plotplain & install gr0070 to get scheme(plotplain) functionality 

************************************************
** 01 Data Prep code
***********************************************
	do "Step 1 - data prep v2.do"
	
************************************************
** 02 Price Analysis Sales-Weighted
***********************************************
	do "$codefolder\Step 2 - price analysis sales-weighted v3.do"
	

************************************************
** 03 Price Analysis Unweighted
***********************************************
	do "$codefolder\Step 3 - price analysis unweighted v2.do"

		
************************************************
** 04 Price Analysis Sales-Weighted & Controlled
***********************************************
	do "$codefolder\Step 4 - price analysis controlled v2.do"

		
************************************************
** 05 Sales Analysis
***********************************************
	do "$codefolder\Step 5 - sales analysis v2.do"
		
		
************************************************
** 06 Sales Analysis Controlled
***********************************************
	do "$codefolder\Step 6 - sales analysis controlled v2.do"
				
