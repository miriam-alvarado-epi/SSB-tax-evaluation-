** Author: Miriam Alvarado
** Date: April 24, 2024
** Edited: August 14, 2014
** Version: 01
** Purpose: Conduct controlled price analysis 
** STATA version 17.0 SE

** *************************************************************************************************
** Price change analysis - regression with controlled ITS 
** *************************************************************************************************	
{
** regression analysis of sales-weighted price data, now with vinegar as controlled ITS for all other categories. 
** apply weights
	use "$outputfolder\appended_data.dta", clear

	merge m:1 upc cat using "$outputfolder\weights.dta"
	drop if _m!=3
	drop _m 

** use asgen to estimate mean cost per liter by product type and week 
	asgen weighted_mean= costperl, weights(weight) by(cat weekind)

** simplify dataset 
	bysort cat weekind: keep if _n == 1
	keep cat catind date trend tax weekind weighted_mean d_eff month rpi tourism inflation_restaurant_hotel holiday xmas hoursopen covid
	
** gen log-transformed cost per litre	
	gen ln_weighted_mean=ln(weighted_mean)

** generate control indicator 
	gen control=(cat=="vinegar_white")
	
** generate control x tax interactions 
	gen controltax = control*tax
	gen controltrend =control*trend 
	
** set panel data	
	tsset catind weekind
	
** set locals
	levelsof cat, local(list)
	local n=1
	
** run a loop for control ITS regressions
	foreach x of local list {
		cap log using "$outputfolder\price_salesweighted_log controlled ITS_`x'.smcl", replace
		di in red "`x'"
		*regress ln_weighted_mean  control control#tax control#c.trend rpi tourism holiday xmas covid i.month if cat=="`x'" | cat=="vinegar_white"
		regress ln_weighted_mean  control tax controltax trend controltrend rpi tourism holiday xmas covid i.month if cat=="`x'" | cat=="vinegar_white"
		
		local r2= e(r2)	
		*newey ln_weighted_mean i.month control control#tax control#c.trend rpi tourism holiday xmas covid i.month  if cat=="`x'" | cat=="vinegar_white", lag(1) force
		newey ln_weighted_mean  control tax controltax trend controltrend rpi tourism holiday xmas covid i.month  if cat=="`x'" | cat=="vinegar_white", lag(1) force
		
		eststo modelcontrol`x'
		estadd local label ="`x'"
		matrix results = r(table)
		estadd scalar upperCI = results[rownumb(results,"ul"),colnumb(results,"tax")]
		estadd scalar lowerCI = results[rownumb(results,"ll"),colnumb(results,"tax")]
	
		estadd scalar r2=`r2'
		local n =`n'+1
		cap log close
		}	
	
**Export results to an Excel file
	esttab modelcontrol* using "$outputfolder\\regression_results controlled ITS.csv", ///
	b stats(upperCI lowerCI  r2 label) wide nostar ///
    replace

}

