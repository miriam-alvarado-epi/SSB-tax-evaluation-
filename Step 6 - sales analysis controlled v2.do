** Author: Miriam Alvarado
** Date: April 24, 2024
** Edited: August 14, 2024
** Version: 02
** Purpose: Conduct sales analysis 
** STATA version 17.0 SE

** *************************************************************************************************
** Sales change analysis with relative and absolute equations - controlled w/ vinegar - rescaled
** *************************************************************************************************
{
** To enable controlled ITS with vinegar, we have to re-scale volume using volume2=(volume-mean)/sdvolume - 
** but this means we also have to scale regression predictions back before estimating relative change
** set locals
	use "$outputfolder\dataforsales.dta", clear
	levelsof cat, local(list)

** note this is code copied from the 2019 analysis and updated. 
	clear all
	set obs 1 
	gen test=1
** generate dataset to add to later 
	tempfile relative 
	save `relative', replace 
	
** clear any saved estimates 
	estimates clear 
	local xx = 1

** Loop through categories and repeat analysis 	 
	foreach x of local list { 
	** bring in prepped data for sales analysis	
		use "$outputfolder\dataforsales.dta", clear
		keep if cat=="`x'" | cat=="vinegar_white" 
	
		cap log close 
		log using "$outputfolder\log_controlled_`x'.smcl" , replace 
		di in red "`x'" 
		
		tsset catind weekind 
		/// note: couldn't get newey to work w/ control, even after panel tsset - but regress worked. not sure.. maybe newey can only do TS and not panel
		cap drop month month12
		
		** generate interactions to make nlcom easier
		gen controltrend =control*trend
		gen controltax=control*tax
		gen	controltaxtrend=control*taxtrend
		
		regress volume2 control controltrend trend controltax tax controltaxtrend taxtrend  rpi tourism  xmas hurricane holiday covid  month*
		estimates store reg`x'
		capture log close 
		
	** save relative change for each post-tax week - this ends up being really strange for the re-scaled values (often trying to estimate relative change between a positive and negative small number)
	** need to re-think how to do this part 
		// forvalues y= 168/257  { 		
			// nlcom  (_b[tax] +_b[taxtrend]*taxtrend[`y']) / ///
			// (_b[tourism]*tourism[`y'] + _b[inflation_restaurant_hotel]*inflation_restaurant_hotel[`y'] + _b[xmas]*xmas[`y'] + _b[hurricane]*hurricane[`y'] ///
			// + _b[holidays]*holidays[`y'] +_b[covid]*covid[`y']  ///
			// + _b[month1]*month1[`y'] ///
			// + _b[month2]*month2[`y'] ///
			// + _b[month3]*month3[`y'] ///
			// + _b[month4]*month4[`y'] ///
			// + _b[month5]*month5[`y'] ///
			// + _b[month6]*month6[`y'] ///
			// + _b[month7]*month7[`y'] ///
			// + _b[month8]*month8[`y'] ///
			// + _b[month9]*month9[`y'] ///
			// + _b[month10]*month10[`y'] ///
			// + _b[month11]*month11[`y'] ///
			// +_b[trend]*trend[`y']+_b[_cons])
			
			// regsave using "`relative'" , coefmat(r(b)) varmat(r(V)) addlabel(cat, "`x'", week1,`y') ci append 
			// }  
		
	
	** saving absolute difference estimates 
		gen est=. 
		gen se=. 
		gen pvalue=. 
		gen df=. 
		gen ci_lb=. 
		gen ci_ub=. 
		
		forvalues y =1/90 { 
			di in red `y' 
			lincom _b[tax] +_b[taxtrend]*(`y')
			replace est=`r(estimate)' if taxtrend== `y' 
			replace se=`r(se)' if taxtrend== `y' 
			replace pvalue=2*ttail(`r(df)',abs(`r(estimate)'/`r(se)')) if taxtrend== `y'  
			replace df=`r(df)' if taxtrend== `y'  
			replace ci_lb = r(estimate) + invnorm(0.025)*r(se) if taxtrend== `y'   
			replace ci_ub= r(estimate) + invnorm(0.975)*r(se) if taxtrend== `y'  
			
			} 
		

	
	** generate  estimates
		predict pred
		predict sd,  stdp
		
		gen upper =pred+1.96*sd
		gen lower =pred -1.96*sd
		
	** generate counterfactual estimates
		replace tax=0 
		replace taxtrend=0 

		predict counterfac 
		predict sdcounter,  stdp
		
		gen counterupper =counterfac+1.96*sdcounter
		gen counterlower =counterfac -1.96*sdcounter 
		
	** keep tax effects
		keep est se pvalue  d_eff trend ci* counterfac taxtrend  counterupper counterlower pred upper lower control cat sdvolume mean
		
		
		if `xx'==1 {
			tempfile results 
			} 
		else{
			
			append using `results' 
			} 
		local xx =`xx'+1
		save `results', replace 
	
	}
	
** save regression estimates 
	esttab  reg* using "$outputfolder\\sales_regression_models_control.csv",   replace wide nostar nopar mtitles

 	
** trying meta analysis to get average annual effect by category	
	use `results', clear 
	keep if est!=. & cat!="vinegar_white"
	
	replace est =(est*sdvolume)
	replace ci_lb =(ci_lb*sdvolume) 
	replace ci_ub =(ci_ub*sdvolume) 

** note here we are re-scaling volume back to normal values. This step is important to enable to estimate of average relative effect to work below. 
	replace counterfac =  counterfac*sdvolume +mean
	replace counterlower =counterlower*sdvolume + mean
	replace counterupper =counterupper*sdvolume +mean
	
** use meta analysis to capture average post-tax differnce in effect and counterfactual estimate 	
	gen abs_est=. 
	gen abs_lower=. 
	gen abs_upper=.
	gen counterfac_meta=. 
	gen counterfac_meta_lower=. 
	gen counterfac_meta_upper=.
	levelsof cat, local(list) 
	
	foreach x of local list { 
	
		metan est ci_lb ci_ub if cat=="`x'",   summaryonly
		replace abs_est=`r(ES)' if cat=="`x'"
		replace abs_lower=`r(ci_low)' if cat=="`x'"
		replace abs_upper=`r(ci_upp)' if cat=="`x'"
		
		metan counterfac counterlower counterupper  if cat=="`x'",   summaryonly
		replace counterfac_meta=`r(ES)' if cat=="`x'"
		replace counterfac_meta_lower=`r(ci_low)' if cat=="`x'"
		replace counterfac_meta_upper=`r(ci_upp)' if cat=="`x'"

	} 
	
** simplify dataset 
	duplicates drop cat counterfac_meta* abs*, force 
	keep cat counterfac_meta* abs*
	
** estimate standard errors using normal distribution for difference and counterfactual estimate 
	gen abs_se = (abs_lower -abs_est)/invnorm(0.025)
	gen counterfac_meta_se = (counterfac_meta_lower -counterfac_meta)/invnorm(0.025)
	
	tempfile metafile 
	save `metafile', replace 

** generate 1000 estimates of the ratio, and order them to get the 2.5%, 50% and 97.5%	
	local y =1
	foreach x of local list { 
		use `metafile', clear 
		keep if cat=="`x'"
		set obs 1000
		local meta =abs_est
		local meta_se =abs_se
		local counterfac_meta= counterfac_meta
		local counterfac_meta_se =counterfac_meta_se
		
		gen numerator=rnormal(`meta', `meta_se')
		gen denominator =rnormal(`counterfac_meta', `counterfac_meta_se')
		gen rel_=numerator/denominator

		sort rel_
		keep if _n==25 | _n==500 | _n==975
		keep rel_
		gen cat ="`x'"
		gen type ="lower" in 1
		replace type="est" in 2
		replace type="upper" in 3 
		if `y'==1 { 
			tempfile metaresults 
			} 
		else { 
			append using `metaresults'
			} 
		save `metaresults', replace 
		local y =2
		}
	
	reshape wide rel_, i(cat) j(type) string
	merge 1:1 cat using `metafile' 
	tostring abs_est, replace force format(%9.1fc)
	tostring abs_lower, replace force format(%9.1fc)
	tostring abs_upper, replace force format(%9.1fc)
	gen abs_ci=abs_lower+" to "+abs_upper 
	
	replace rel_est=rel_est*100
	replace rel_lower=rel_lower*100
	replace rel_upper=rel_upper*100
	
	tostring rel_est, replace force format(%9.1fc)
	tostring rel_lower, replace force format(%9.1fc)
	tostring rel_upper, replace force format(%9.1fc)
	gen rel_ci=rel_lower+" to "+rel_upper 
	
	keep cat abs_est abs_ci rel_est rel_ci 

	gen numlabel=. 
	replace numlabel=1 if cat=="ssb" 
	replace numlabel=2 if cat=="soda" 
	replace numlabel=3 if cat=="juicedrink" 
	replace numlabel=4 if cat=="syrup" 
	replace numlabel=5 if cat=="ssbdairy" 
	replace numlabel=6 if cat=="otherssb"
	replace numlabel=7 if cat=="nonssb"
	replace numlabel=8 if cat=="water"
	replace numlabel=9 if cat=="nonssbjuice" 
	replace numlabel=10 if cat=="nonssbdairy" 
	replace numlabel=11 if cat=="othernonssb" 
	replace numlabel=12 if cat=="powder" 
	replace numlabel=13 if cat=="ssbpowder" 
	replace numlabel=14 if cat=="nonssbpowder"
	replace numlabel=15 if cat=="vinegar_white"

	
	gen label=""
	replace label="SSBs" if cat=="ssb" 
	replace label="Sodas" if cat=="soda" 
	replace label="Sweetened Juice Drinks" if cat=="juicedrink" 
	replace label="Syrups" if cat=="syrup" 
	replace label="Sweetened dairy" if cat=="ssbdairy" 
	replace label="Other SSBs" if cat=="otherssb"
	replace label="Non-SSBs" if cat=="nonssb"
	replace label="Water" if cat=="water"
	replace label="Unsweetened Juices" if cat=="nonssbjuice" 
	replace label="Unsweetened Dairy" if cat=="nonssbdairy" 
	replace label="Other non-SSBs" if cat=="othernonssb" 
	replace label="Powders" if cat=="powder" 
	replace label="Sweetened Powders" if cat=="ssbpowder" 
	replace label="Unsweetened Powders" if cat=="nonssbpowder"
	replace label="Vinegar" if cat=="vinegar_white"


	sort numlabel 
	order label abs_est abs_ci rel_est rel_ci  cat numlabel
	outsheet using "$outputfolder\\sales_mean_overall_control.csv", comma replace 
	tempfile mean_effects
	save `mean_effects', replace 
	
	
** prepping effect for specific weeks 	(absolute effects and graphs) 
	use `results', clear 
	
** graph all together 
	gen numlabel=. 
	replace numlabel=1 if cat=="ssb" 
	replace numlabel=2 if cat=="soda" 
	replace numlabel=3 if cat=="juicedrink" 
	replace numlabel=4 if cat=="syrup" 
	replace numlabel=5 if cat=="ssbdairy" 
	replace numlabel=6 if cat=="otherssb"
	replace numlabel=7 if cat=="nonssb"
	replace numlabel=8 if cat=="water"
	replace numlabel=9 if cat=="nonssbjuice" 
	replace numlabel=10 if cat=="nonssbdairy" 
	replace numlabel=11 if cat=="othernonssb" 
	replace numlabel=12 if cat=="powder" 
	replace numlabel=13 if cat=="ssbpowder" 
	replace numlabel=14 if cat=="nonssbpowder"
	replace numlabel=15 if cat=="vinegar_white"

	gen label=""
	replace label="SSBs" if cat=="ssb" 
	replace label="Sodas" if cat=="soda" 
	replace label="Sweetened Juice Drinks" if cat=="juicedrink" 
	replace label="Syrups" if cat=="syrup" 
	replace label="Sweetened dairy" if cat=="ssbdairy" 
	replace label="Other SSBs" if cat=="otherssb"
	replace label="Non-SSBs" if cat=="nonssb"
	replace label="Water" if cat=="water"
	replace label="Unsweetened Juices" if cat=="nonssbjuice" 
	replace label="Unsweetened Dairy" if cat=="nonssbdairy" 
	replace label="Other non-SSBs" if cat=="othernonssb" 
	replace label="Powders" if cat=="powder" 
	replace label="Sweetened Powders" if cat=="ssbpowder" 
	replace label="Unsweetened Powders" if cat=="nonssbpowder"
	replace label="Vinegar" if cat=="vinegar_white"


	labmask numlabel, values(label)
	
** generate significance labels 
	gen sig =(pvalue<.05 & est!=.  )  
	gen sigdifference=pred
	replace sigdifference=. if sig==0 
	
	
	
** merge on data to graph data with predictions
	duplicates drop cat d_eff, force
	merge 1:m d_eff cat using "$outputfolder\dataforsales.dta"
	keep if _m==3
	
	sort cat d_eff 	
	gen year=year(d_eff)


** graph product by product - improving graph format a bit and dropping outliers
	drop if holidays==1 | xmas==1 | hurricane==1 
	
** re-scale for graphs
	gen pred_rescale = pred*sdvolume + mean
	gen counterfac_rescale =  counterfac*sdvolume +mean
	gen sigdifference_rescale= sigdifference*sdvolume+mean
	
	

	levelsof label, local(list)
	foreach x of local list { 
		twoway scatter volume d_eff if label=="`x'" , msymbol(smcircle) mcolor(gs12) msize(vsmall) ///
		|| line pred_rescale d_eff if label=="`x'" & year>2020, ylabel(#3) ysize(6) lpattern(solid) lcolor(gs8) lwidth(thick) connect(ascending)  scheme(plotplain) ///
		|| line counterfac_rescale d_eff if label=="`x'" & year>2020 , connect(ascending) lpattern(dash) lwidth(thin) lcolor(black) xline(22737) ///
		|| line pred_rescale d_eff if label=="`x'" & year<2020, ylabel(#3) lpattern(solid) lcolor(gs8) lwidth(thick) connect(ascending) ///
		|| line counterfac_rescale d_eff if label=="`x'" & year<2020 , connect(ascending) lpattern(dash) lwidth(thin) lcolor(black) ///
		||  scatter sigdifference_rescale d_eff if label=="`x'",  lwidth(medthick) msymbol(Th) mcolor(black)   cmissing(no) connect(ascending) ///
		ytitle("Weekly Sales (Litres)") ylabel(,angle(0) format(%12.0gc))  xtitle("") title("`x'") xlabel(#5, angle(60)) legend( ///
		order( 1 3 2 6) label (1 "Data") label(3 "Pre-tax Model & Post-tax Counterfactual (no tax)") label(2 "Post-tax Estimates (with tax)") ///
		label(6 "Post-tax Estimates (with tax) sig. diff. at 5%") region(lstyle(none)) position(6)) aspectratio(.35) xlabel(#7) 


		*graph export "`folder'\05 Graphs\\`savefolder'\fig2_testing_brb.tif", replace width(2400)
		graph export "$outputfolder\\final_no_outliers_model_data_`x'_control.png", replace 
	}
	
	
	levelsof label, local(list)
	local y=1
	foreach x of local list { 
		twoway scatter volume d_eff if label=="`x'" , msymbol(smcircle) mcolor(gs12) msize(vsmall) ///
		|| line pred_rescale d_eff if label=="`x'" & year>2020, ylabel(#3) ysize(6) lpattern(solid) lcolor(gs8) lwidth(thick) connect(ascending)  scheme(plotplain) ///
		|| line counterfac_rescale d_eff if label=="`x'" & year>2020 , connect(ascending) lpattern(dash) lwidth(thin) lcolor(black) xline(22737) ///
		|| line pred_rescale d_eff if label=="`x'" & year<2020, ylabel(#3) lpattern(solid) lcolor(gs8) lwidth(thick) connect(ascending) ///
		|| line counterfac_rescale d_eff if label=="`x'" & year<2020 , connect(ascending) lpattern(dash) lwidth(thin) lcolor(black) ///
		||  scatter sigdifference_rescale d_eff if label=="`x'",  lwidth(medthick) msymbol(Th) mcolor(black)   cmissing(no) connect(ascending) ///
		ytitle("Weekly Sales (Litres)") ylabel(,angle(0) format(%12.0gc))  xtitle("") title("`x'") xlabel(#5, angle(60)) legend(off) aspectratio(.35) xlabel(#7) 
		graph save sales`y', replace 
		local y=`y'+1
	}  
	
	
	
	
	
	
	graph combine sales5.gph sales1.gph sales4.gph, cols(1) scheme(plotplain)  ysize(8) xsize(5) imargin(zero)  
	graph export "$outputfolder\Fig 7 -  sales over time_control.png", replace 
	
	graph combine sales6.gph sales7.gph sales9.gph sales2.gph, cols(1) scheme(plotplain)  ysize(8) xsize(5) imargin(zero)
	graph export "$outputfolder\Supp fig 10 -  sales over time_control ssbs.png", replace 
	
	graph combine sales15.gph sales12.gph sales11.gph  sales3.gph, cols(1) scheme(plotplain)  ysize(8) xsize(5) imargin(zero)
	graph export "$outputfolder\Supp fig 11 -  sales over time_control nonssbs.png", replace 
	
	graph combine sales10.gph , cols(1) scheme(plotplain)  ysize(8)  imargin(zero)
	graph export "$outputfolder\Supp fig 10b -  sales over time_control syrups.png", replace 
	
	
	
** keep estimates for absolute effects for specific weeks 
	keep if trend ==257
	keep trend est ci_lb ci_ub  cat label sdvolume
	
	gen est_rescale =est*sdvolume
	gen ci_lb_rescale =ci_lb*sdvolume
	gen ci_ub_rescale =ci_ub*sdvolume
	
	tostring est_rescale, replace force format(%9.1fc)
	tostring ci_lb_rescale, replace force format(%9.1fc)
	tostring ci_ub_rescale, replace force format(%9.1fc)
	gen ci_rescale=ci_lb_rescale+" to "+ci_ub_rescale 
	rename est_rescale final_abs
	rename ci_rescale final_abs_ci
	
	keep final* cat trend label
	
	tempfile abs
	save `abs', replace 

** prepping effect for specific weeks  (relative effects) -- when we figure out how to do this. 
/* 	use `relative', clear 
	keep if week1=257
	keep week1 coef ci_lower ci_upper cat 
	
	replace coef=coef*100
	replace ci_lower=ci_lower*100
	replace ci_upper=ci_upper*100
	tostring coef, replace force format(%9.1fc)
	tostring ci_lower, replace force format(%9.1fc)
	tostring ci_upper, replace force format(%9.1fc)
	
	gen ci=ci_lower+" to "+ci_upper
	keep coef ci week1 cat 
	rename coef final_rel
	rename ci final_rel_ci
	sort cat week1 
	
** merge on absolute 
	merge 1:1 cat using `abs'
	drop _m
	 */
** merge on mean effects
	merge 1:1 cat using `mean_effects'
	drop _m 
	
** merge on order	
	rename cat subcat1
	merge 1:1 subcat1 using "$outputfolder\order.dta" 
	
	sort order2
	order subcat1 abs_est abs_ci rel_est rel_ci final_abs final_abs_ci
	
	outsheet using "$outputfolder\\Supplementary Table 9 mean and final week of study estimates_control.csv", comma replace 
	 */
	 
** forest plot prepped
	insheet using "$outputfolder\\Supplementary Table 9 mean and final week of study estimates_control.csv", comma clear 
	
	keep subcat label rel* order2 
	split rel_ci, parse(" to ") generate(ci) 
	destring ci1 ci2, replace force 
	
	
	replace order =order+1 if order>=7 
	replace order =order+1 if order>=13
	replace order =order+1 if order>=17
	
	
	replace order=order*-1 
	
	
	label define names -1 "SSBs" -2 "Sodas" -3 "Juice Drinks" -4 "Syrups" -5 "SSB Dairy" -6 "Other SSBs" -7 "" -8 "Non-SSBs" -9 "Water" ///
	-10 "Unsweetened Juice" -11 "Unsweetened Dairy" -12 "Other non-SSBs" -13""  -14 "Powders" -15 "SSB Powders" -16 "Non-SSB Powders" -17 ""  -18 "Vinegar" , replace 
	
	label values order names 
	rename rel_est percent
	rename ci1 percentlower
	rename ci2 percentupper
	
	format percent* %9.1gc
	twoway rcap percentlower percentupper order , horizontal || ///
	scatter order percent, scheme(plotplain) xline(0) ///
	ylabel(-1 -2 -3 -4 -5 -6 -8 -9 -10 -11 -12 -14 -15 -16 -18, valuelabel) ytitle("") legend(off) ///
	title("Controlled Sales Change") 
	
	graph export "$outputfolder\Figure X forest plot sales 2.png", replace 
	
** merge on main analysis 
	rename percent controlledpercent
	rename percentlower  controlledpercentlower
	rename percentupper  controlledpercentupper
	
	merge 1:1 order using "$outputfolder\price_forestplot sales1.dta"
	
	drop if order==-18
	
	twoway rcap percentlower percentupper order , horizontal lcolor(black) || ///
	scatter order percent, scheme(plotplain) xline(0) mcolor(black) ///
	ylabel(-1 -2 -3 -4 -5 -6 -8 -9 -10 -11 -12 -14 -15 -16, valuelabel) ytitle("")  ///
	title("Sensitivity Analysis: Controlled") || ///
	rcap  controlledpercentlower  controlledpercentupper order , horizontal lcolor(gs10) || ///
	scatter order  controlledpercent, mcolor(gs10) legend(order(2 4) label(2 "Estimates of sales") label(4 "Controlled estimates of sales") pos(7))
		
	graph export "$outputfolder\Figure 6 forest plot sales 2 sens.png", replace 	
	
	
	
	
	
	
	
	
	}
	
	
	