** Author: Miriam Alvarado
** Date: April 24, 2024
** Edited: August 14, 2024
** Edited Sep 5, 2024
** Version: 02
** Purpose: Conduct sales-weighted price analysis 
** STATA version 17.0 SE

** *************************************************************************************************
** Price change analysis - sales-weighted analysis
** *************************************************************************************************
{
** price change analysis of weighted prices
** note that weighting happens in price var - doesn't need to happen in regression. 

	use "$outputfolder\appended_data.dta", clear

	merge m:1 upc cat using "$outputfolder/weights.dta"
	
	// _m==24,610 - these are products that were only sold in the post-tax period and are therefor not included in the sales-weighting. 
	// note this as a limitation of using the sales-weighting approach - check the number of products only included in post-tax period by category and total: 
		/* 	preserve 
			keep if _m==1
			duplicates drop description cat, force 
			tab cat
			duplicates drop description , force
			count 
			//415 total new products added in post-tax period. 
			restore 
			 */
			 
	** now counting number of products by sub-group
	preserve 
	duplicates drop upc cat, force 
	drop if cat=="vinegar" 
	gen n=1
	collapse (sum) n, by(cat _m)
	rename _merge missing
	reshape wide n, i(cat) j(missing)
	gen total= n1+n3
	gen percentnew=n1/n3
	rename n1 new
	rename n3 original
	
	rename cat subcat1 
	merge m:1 subcat1  using "$outputfolder\order.dta" 
	keep if _m==3
	drop _m 
	sort order2
	order subcat1 original new total percentnew 
	
	outsheet using "$outputfolder\Supp Table 5 weighted vs unweighted sample size.csv", comma replace
	restore 
			 
** noting this limitation, drop products w/ no weights for sales-weighted price analysis
	
	drop if _m!=3
	drop _m 

** make sure to have installed asgen - use this to generate weighted mean cost per liter by category and week  
	asgen weighted_mean= costperl, weights(weight) by(cat weekind)
	
** reduce dataset to one cost per liter measure per product type per week - 
	bysort cat weekind: keep if _n == 1
	
** simplify data to variables used in regression 
	keep cat catind weekind tax trend weighted_mean d_eff date month rpi tourism inflation_restaurant_hotel holiday xmas hoursopen covid
	
** we planned to use ln-transformed cost per litre for the price analysis so that we could measure impact in relative terms directly by transforming the coefficient on tax. 
	gen ln_weighted_mean=ln(weighted_mean)
	
** set as panel data 
	tsset catind weekind
	
	tempfile realdata
	save `realdata', replace 
	levelsof cat, local(list)
	
** regressions for main price analysis - loop through and repeat analysis for each category
	foreach x of local list {
		use `realdata', clear 
		cap log using "$outputfolder\price_weighted_log_`x'.smcl", replace
		di in red "`x'"
	** conduct OLS regression first to test for autocorrelation and save R-squared statistic (which is not reported following newey regression)
		regress ln_weighted_mean  trend tax rpi tourism holiday xmas  covid i.month if cat=="`x'"
	
	** Durbin-Watson Statistic: Values close to 2 indicate no autocorrelation. Values less than 2 suggest positive autocorrelation, and values greater than 2 suggest negative autocorrelation.
	** ran and all Durbin_Watson statistics were under 2, suggesting positive autocorrelation. 
		estat dwatson
	
	** save r-squared
		local r2= e(r2)	
	
	** after reviewing, there was evidence of autocorrelation so we used newey model with 1 lag - this is the key model 
		newey ln_weighted_mean  trend tax rpi tourism holiday xmas  covid i.month if cat=="`x'", lag(1)
		
	** save model coefficients and extra detail to help w/ table 
		eststo model`x'
		estadd local label ="`x'"
		matrix results = r(table)
		estadd scalar upperCI = results[rownumb(results,"ul"),colnumb(results,"tax")]
		estadd scalar lowerCI = results[rownumb(results,"ll"),colnumb(results,"tax")]
		estadd scalar r2=`r2'
		
		
	** graphing model vs data - generate predicted cost per litre based on model 
		predict pred`x'
		
	** generating counterfactual to graph 
		replace tax=0
		predict ntp`x'
	
	** graph model predictions vs data, excluding Christmas as major outliers. 
		gen pred`x'_t = exp(pred`x')
		gen ntp`x'_t = exp(ntp`x')
		gen year=year(d_eff)
		drop if year<2021
		* local x "soda" 
		twoway scatter weighted_mean d_eff if cat=="`x'" & xmas!=1, mcolor(gs8) || line pred`x'_t d_eff if cat=="`x'" & xmas!=1 & covid==0, ///
		scheme(plotplain) xline(22737) lcolor(black)  lpattern(solid) || line pred`x'_t d_eff if cat=="`x'" & xmas!=1 & covid==1, ///
		lcolor(black)  lpattern(solid) title("`x'") subtitle("sales weighted") xtitle("") xlabel(#7, angle(45)) ///
		legend(label(1 "Mean cost per litre") label(2 "Fitted values") label(4 "Counterfactual") order(1 2 4) pos(6)) || ///
		line ntp`x'_t d_eff if cat=="`x'" & xmas!=1, lcolor(gs8)  lpattern(dash)
		
		graph save pricereg`x', replace 
		graph export "$outputfolder\price_model_data_`x'_transformed.png", replace 
		
		save "$outputfolder\price_data_`x'.dta", replace 
		
	** graph residgual vs predicted plot for each category 
		rvpplot2 weekind, force title("`x'") xline(169) scheme(plotplain)  subtitle("sales weighted") xtitle("") xlabel(#7)
		graph export "$outputfolder\M`x'_rvp.png", replace 
		graph save rvp`x', replace 
		
		cap log close
		}	
		

** make graphs for supplementary figures using graph combine feature 
	graph combine priceregssb.gph priceregnonssb.gph priceregvinegar_white.gph priceregpowder.gph, scheme(plotplain) cols(1)  iscale(.75) ysize(8) xsize(5) imargin(tiny) l1title("Mean cost per litre")
	graph export "$outputfolder\cost per liter over time sales weighted data vs model transformed.png", replace 
	
	graph combine priceregsoda.gph priceregjuicedrink.gph priceregsyrup.gph priceregssbdairy.gph priceregotherssb.gph, scheme(plotplain) cols(1)  iscale(.75) ysize(8) xsize(5) imargin(tiny) l1title("Mean cost per litre")
	graph export "$outputfolder\SSBs cost per liter over time sales weighted data vs model transformed.png", replace 
	
	graph combine priceregwater.gph priceregnonssbjuice.gph  priceregnonssbdairy.gph priceregothernonssb.gph, scheme(plotplain) cols(1)  iscale(.75) ysize(8) xsize(5) imargin(tiny) l1title("Mean cost per litre")
	graph export "$outputfolder\nonSSBs cost per liter over time sales weighted data vs model transformed.png", replace 
	

	graph combine rvpssb.gph rvpnonssb.gph rvpvinegar_white.gph rvppowder.gph, cols(2) scheme(plotplain)  
	graph export "$outputfolder\Supp fig 7 -  rvp sales weighted.png", replace 
	

**Export regression results to an Excel file
	esttab model* using "$outputfolder\\weighted_price_regression_results.csv", ///
	b stats(upperCI lowerCI r2 label) wide nostar ///
    replace
} 


