** Author: Miriam Alvarado
** Date: April 24, 2024
** Edited: August 14, 2024
** Version: 02
** Purpose: Conduct sales-weighted price analysis 
** STATA version 17.0 SE


** *************************************************************************************************
** Price change analysis - regression of unweighted sales data - sensitivity analysis 
** *************************************************************************************************	
{
** repeating regression analysis of unweighted sales data as a sensitivity analysis - this includes all products (even those introuced post-tax) 
	use "$outputfolder\appended_data.dta", clear 
	
** generate mean cost per liter by product and week 	
	asgen mean= costperl, by(cat weekind)

** reduce data set to 1 obs per week and keep variables for regression analysis 
	bysort cat weekind: keep if _n == 1
	keep cat catind weekind date trend tax mean d_eff month rpi tourism inflation_foodbevs inflation_restaurant_hotel inflation_all xmas holidays hurricane hoursopen covid

** generate ln-transformed cost 
	gen ln_mean=ln(mean)


** graphing unweighted cost per litre over time 
	levelsof cat, local(list) 
	foreach x of local list {
		di "`x'"
		twoway scatter mean d_eff if cat=="`x'", xline(22737) scheme(plotplain) xtitle("") ytitle("Mean Cost (BBD$)/L") title("`x'") subtitle("unweighted") xlabel(#7)
		*graph export "`outputfolder'\price_unweighted mean `x'.png", replace 
		graph save price`x', replace 
		}
	graph combine pricessb.gph pricenonssb.gph pricevinegar_white.gph pricepowder.gph, scheme(plotplain) cols(1)  iscale(.75) ysize(8) xsize(5) imargin(tiny)
	graph export "$outputfolder\Supp fig 5 -  cost per liter over time unweighted.png", replace 
	
	
	
** set panel structure 
	tsset catind weekind
	
** regression analysis for each category 
	levelsof cat, local(list) 
	foreach x of local list {
		cap log using "$outputfolder\price_unweighted_log_`x'.smcl", replace
		di in red "`x'"
		regress ln_mean  trend tax rpi tourism  holiday xmas   covid i.month if cat=="`x'"
		estat dwatson
	** Durbin-Watson Statistic: Values close to 2 indicate no autocorrelation. Values less than 2 suggest positive autocorrelation, and values greater than 2 suggest negative autocorrelation.
	** ran and all Durbin_Watson statistics were under 2, suggesting positive autocorrelation. 

		local r2= e(r2)	
		newey ln_mean trend tax rpi tourism  holiday xmas   covid i.month   if cat=="`x'", lag(1)
		eststo model`x'
		estadd local label ="`x'"
		matrix results = r(table)
		estadd scalar upperCI = results[rownumb(results,"ul"),colnumb(results,"tax")]
		estadd scalar lowerCI = results[rownumb(results,"ll"),colnumb(results,"tax")]
		estadd scalar r2=`r2'
		cap log close
		}	

**Export results to an Excel file
	esttab model* using "$outputfolder\\unweighted_price_regression_results.csv", ///
	b stats(upperCI lowerCI r2 label) wide nostar ///
    replace
} 


