** Author: Miriam Alvarado
** Date: April 24, 2024
** Version: 02
** Purpose: Prep data for SSB ITS analyses 
** STATA version 17.0 SE


** *************************************************************************************************
** DATA prep - run this code to bring in raw data from data source and format it for analysis 
** *************************************************************************************************
{
** Bring in first datafile	
	cd "$inputfolder"
	import excel "Chronic Disease Research Centre Excise Tax Report Jan 2021 to Feb 2024.xlsx", clear 

** drop blanks from Excel template formatting
	drop in 1/5
	
** Note 'code' is listed twice as column label in columns D and F - change to 'subcode' in F 
	replace F="subcode" in 1 
	
** fix varnames - remove spaces in some names and rename vars properly
	foreach v of varlist B-N {
		replace `v'=lower(`v') in 1
		replace `v' =subinstr(`v', " ", "_", .) in 1 
		rename `v' `=`v'[1]'
	}
	
** drop row with var names after labelling 
	drop in 1
	
** tempfile first datafile	
	tempfile data1
	save `data1', replace
	
	
** Bring in second datafile from store and repeat cleaning process 
	import excel "Chronic Disease Research Centre Excise Tax Report Nov 2016 to Dec 2020.xlsx", clear 
	drop in 1/5
	
** Note code is listed twice in columns D and Feb
	replace F="subcode" in 1 
	
** fix varnames - remove spaces in some names and rename vars properly
	foreach v of varlist B-N {
		replace `v'=lower(`v') in 1
		replace `v' =subinstr(`v', " ", "_", .) in 1 
		rename `v' `=`v'[1]'
	}

	drop in 1
	
** append both datafiles together
	append using `data1'
	
** drop blank data	- rows with no data at all from Excel formatting issues 
	drop if upc==""
	
** destring numeric variables 
	foreach v of varlist upc code subcode  price unit_sales dollar_sales  {
		destring `v', replace force 
	}

** gen date variable in similar format to old data	
	gen d_eff=date(date,"MDY") 
	
	format d_eff %tdnn/dd/YY
	gen year = year(d_eff)
	gen month = month(d_eff)
	gen week =week(d_eff) 
	gen quarter =quarter(d_eff)

** trouleshooting that 2022 has 53 weeks since 12/31 is week start date - 
	replace week=53 if date=="12/31/2022"

** generate month/week/quarter trend over time indicators 
	egen monthind=group(year month )
	egen weekind =group(year week) 
	egen quarterind =group(year quarter) 
	
** formatting 'category' variable to remove "/" 
	replace category =subinstr(category, "/", "", .)
	
** estimating price  -  since the price listed is the current price and not historical price, we need to estimate the historical price at each time point and cross-check.
	** 1) divide dollar sales by units sold 
	** 2) then add VAT if applicable 
	** Note: there are a small group of products that are not VAT applicable, these are vinegars and chocolate syrups, and single week juice coupons 
	gen est_price_prevat = dollar_sales /unit_sales
	gen est_price_vat = est_price_prevat
	replace est_price_vat = est_price_prevat*1.175 if vat=="Y"
	
	
** organizing variables - only keeping the ones we use later and re-ordering 	
	keep upc d_eff year month week monthind weekind subdepartment category brand description size vat unit_sales dollar_sales est_price_prevat est_price_vat
	order upc d_eff year month week monthind weekind subdepartment category brand description size vat unit_sales dollar_sales est_price_prevat est_price_vat
	
	tempfile dataoriginal 
	save `dataoriginal', replace 
	
}	
	
	
** *************************************************************************************************
** Merge on prior product categories - in this section of code we categorize products by product type in a two-stage process. 
** *************************************************************************************************
{
** Bring in product category data from 2019 analysis (excel sheet with UPC codes and categories) - stored at G:\My Drive\01_PhD\01 SSB\02 Price and Sales\18 Month\08 Final\02 Data\01 Prepped
	import excel "G:\My Drive\02 Wellcome Fellowship\02 Project Files\05 Case Studies\02 Barbados\03 Sales Analysis\04 Data\product categories.xlsx", clear firstrow

** UPC is unique identifier - merge with recent data
	merge 1:m upc using `dataoriginal'
	tempfile dataproducts
	save `dataproducts', replace 


** generate estimate of how many products we need to categorize for this second analysis 
	keep if _m==2
	duplicates drop upc description, force
	
** I went through manually and reviewed descriptive data and product websites to assign categories to products. 
** For a subset of hard-to-classify products, I did an in-store review of ingredient panels to determine classifications. 
** Here, I prep a file to do this manually in Excel: 

	keep upc subdepartment category brand description ssb bigcat 
	order upc subdepartment category brand description ssb bigcat 

	export excel "G:\My Drive\02 Wellcome Fellowship\02 Project Files\05 Case Studies\02 Barbados\03 Sales Analysis\04 Data\product categories to be added template.xlsx", replace firstrow(variables)

** The next step is done manually outside of STATA. Return to code when this is completed. 
}

** *************************************************************************************************
** After manually identifying product categories, bring in updated product categories and work on product sizes
** *************************************************************************************************
{
** Bring in current dataset which has been merged with old product categorizations, and rename to prepare for second merge 
	use `dataproducts', clear
	keep if _m==3
	drop _m
	tempfile matched
	save `matched', replace 

** Bring in newly identified product category data from prior step 
	import excel "G:\My Drive\02 Wellcome Fellowship\02 Project Files\05 Case Studies\02 Barbados\03 Sales Analysis\04 Data\product categories to be added.xlsx", clear firstrow

** UPC is unique identifier - merge with current dataset first -> this is merging on all of the newly identified product categories
	merge 1:m upc using `dataoriginal'
	
** keep newly added products, and append with previously identified products. Important - check totals are the same (e.g. 142,712)
	keep if _m==3
	append using `matched' 
	
** count number of combo products
	gen combo=(bigcat=="combo") | size=="Combo" 
	preserve
	tab description if combo==1
	collapse (sum) dollar_sales, by(combo) 
	
	restore 
	
** generate new product category to correspond to white vinegar only - 
** we think this may be a better control since current vinegar cateogory includes high-end vinegars (i.e. flavored balsamic vinegars, etc.)
** Note three descriptions include an apostrophe that messes up the formatting of subsequent code - they have been commented out for now, but uncomment before running. 
	gen whitevinegar=. 
	replace whitevinegar=1 if description=="VALU TIME Vinegar White Distilled 1gal"
	replace whitevinegar=1 if description=="HEINZ Vinegar White 1.89 Litre"
	replace whitevinegar=1 if description=="HEINZ Vinegar White DISCONTINUED 16oz"
	replace whitevinegar=1 if description=="FOOD CLUB Vinegar 16oz"
	replace whitevinegar=1 if description=="FOOD CLUB Vinegar 64oz"
	replace whitevinegar=1 if description=="FOOD CLUB Vinegar 128oz"
	replace whitevinegar=1 if description=="DAILY CHEF Vinegar White 128oz"
	replace whitevinegar=1 if description=="T SMART T Smart Vinegar White 128oz"
	replace whitevinegar=1 if description=="WESTERN Vinegar White 1Gal"
	replace whitevinegar=1 if description=="WESTERN Vinegar White 500ml"
	replace whitevinegar=1 if description=="ATLANTIC FRESH Vinegar Pure White 500ml"
	replace whitevinegar=1 if description=="KARIBBEAN FLAVOURS Vinegar Pure White 1 Litre"
	replace whitevinegar=1 if description=="KARIBBEAN FLAVORS Vinegar White 4L"
	replace whitevinegar=1 if description=="HEINZ Vinegar White 1gal"
	replace whitevinegar=1 if description=="HEINZ Vinegar  Distilled White 946ml"
	replace whitevinegar=1 if description=="FOOD SERVICE Vinegar White 1gal"
	replace whitevinegar=1 if description=="MATOUK Vinegar White 500ml"
	replace whitevinegar=1 if description=="MATOUK Vinegar White 1lt"
	replace whitevinegar=1 if description=="MATOUK Vinegar White 2lt"
	replace whitevinegar=1 if description=="MATOUK Vinegar White 4lt"
	replace whitevinegar=1 if description=="MP Vinegar White 500ml"
	replace whitevinegar=1 if description=="MP Vinegar White 1lt"
	replace whitevinegar=1 if description=="MP Vinegar White 2lt"
	replace whitevinegar=1 if description=="MP Vinegar White 4lt"
	replace whitevinegar=1 if description=="IGA Vinegar White 128oz"
	replace whitevinegar=1 if description=="IGA Iga Vinegar White 16oz"
	replace whitevinegar=1 if description=="IGA Vinegar Distilled 32oz"
	replace whitevinegar=1 if description=="IGA Vinegar White 64oz"
	replace whitevinegar=1 if description=="KURTZ Vinegar White 128 oz"
	replace whitevinegar=1 if description=="KURTZ Vinegar White 32oz"
	replace whitevinegar=1 if description=="SELECTION Pure White Vinegar #88837  DISCDISCONTINUED 4lt"
	replace whitevinegar=1 if description=="NO NAME Vinegar Pure White 4L"
	replace whitevinegar=1 if description=="NO NAME Vinegar Pure White 1L"
	replace whitevinegar=1 if description=="WINDMILL Vinegar White 1lt"
	replace whitevinegar=1 if description=="DAILY CHEF Vinegar White 2x1gal"
	
	
** Organize categories. 
** create two sub-cat vars - one that is more detailed and one for replication studies using the more limited categories we had for the 2019 analysis 
** (see Table 1 in protocol) 
	gen subcat1=""
	replace subcat1="soda" if bigcat=="soda"
	replace subcat1="juicedrink" if bigcat=="juicedrink" | bigcat=="sweetenedjuice"
	replace subcat1="syrup" if bigcat=="syrup" | bigcat=="mauby" 
	replace subcat1="ssbdairy" if bigcat=="sweetmilk"
	replace subcat1="otherssb" if bigcat=="othersweet" | bigcat=="energy" | bigcat=="sports" | bigcat=="milksubsweet" | bigcat=="concentrate" 
	
	
	drop ssb
	gen ssb="ssb" if subcat1=="soda" | subcat1=="juicedrink" | subcat1=="syrup" | subcat1=="ssbdairy" | subcat1=="otherssb"
	
** nonSSBs
	replace subcat1="water" if bigcat=="water" 
	replace subcat1="nonssbjuice" if bigcat=="nonsweetenedjuice"
	replace subcat1="nonssbdairy" if bigcat=="milk" 
	replace subcat1="othernonssb" if bigcat=="othernonsweet" | bigcat=="dietsoda" | bigcat=="nonssbconcentrate" | bigcat=="syrupnonssb" | bigcat=="maubynonssb" | bigcat=="milksubnonssb"
	
	replace ssb="nonssb" if subcat1=="water" | subcat1=="nonssbjuice" | subcat1=="nonssbdairy" | subcat1=="othernonssb" 
	
** powders
	replace subcat1="ssbpowder" if bigcat=="powder" 
	replace subcat1="nonssbpowder" if bigcat=="powdernonssb" 
	replace ssb="powder" if subcat1=="ssbpowder" | subcat1=="nonssbpowder"
	
** vinegar	
	replace subcat1="vinegar_white" if whitevinegar==1
	replace ssb="vinegar" if whitevinegar==1
	
** Generate subcat2 to correspond to appendix subcategories (Table 2 in protocol) 	
	gen subcat2=""
	replace subcat2="soda" if bigcat=="soda"
	replace subcat2="otherssb" if bigcat=="juicedrink" | bigcat=="sweetenedjuice" | bigcat=="othersweet" | bigcat=="energy" | bigcat=="sports"
	replace subcat2="water" if bigcat=="water" 
	replace subcat2="othernonssb" if bigcat=="nonsweetenedjuice" | bigcat=="othernonsweet" | bigcat=="dietsoda" 
	
	gen ssb2 ="ssb" if subcat2=="soda" | subcat2=="otherssb" 
	replace ssb2 ="nonssb" if subcat2=="water" | subcat2=="othernonssb" 
	
	
** Note we'll have to deal with volumes/reconsistuted concentrate/powder/syrup volumes 
** Prep Size data
	replace size=trim(size) 
	replace size = subinstr(size, " ", "", .)
	replace size=lower(size) 
	
** see 	https://www.stata.com/support/faqs/data-management/regular-expressions/ for regular expression syntax. 
** use regular exressions to split up size variable into numeric and string components 
	moss size, match("(\.?[0-9]+\.?\/?[0-9]*)") regex pre(num)
	moss size, match("([a-z]+)") regex pre(word)

** take a look at the words extracted from 'size' to get a sense: 	
	tab wordmatch1 if numpos2==. 
	
** note that variables with numpos2!=. and numpos3!=. will need special attention (these are packs of things, eg. 4x2oz etc.) 
	tab wordmatch1 if numpos2!=. 
	tab wordmatch1 if numpos3!=. 
	
** for multi-packs, replace wordmatch2 and 3 into 1 so that we get sizing right. 
	replace wordmatch1=wordmatch2 if wordmatch2!=""
	replace wordmatch1=wordmatch3 if wordmatch3!=""
	

** converstion to litres for liquid products - use standard conversions (e.g. 1000ml =1L) 
	gen conversiontol=.
	replace conversiontol=.001 if wordmatch1=="ml" | wordmatch1=="m"
	replace conversiontol= 3.78541 if wordmatch1=="gallon" | wordmatch1=="gal" | wordmatch1=="gals" 
	replace conversiontol= 0.0295735 if wordmatch1=="fl" | wordmatch1=="floz" | wordmatch1=="fz" 
	replace conversiontol= 1 if wordmatch1=="l" | wordmatch1=="litre" | wordmatch1=="litres" | wordmatch1=="lt" | wordmatch1=="ltr" 
	replace conversiontol= 0.473176 if wordmatch1=="pint" | wordmatch1=="pints" 
	replace conversiontol= 0.946353 if wordmatch1=="qt"
	replace conversiontol=.01 if wordmatch1=="cl"
	
** for some products, they report oz but mean fluid oz (e.g. La Croix 12 oz cans)
	replace conversiontol=0.0295735 if wordmatch1=="oz" & subcat1!="nonssbpowder" & subcat1!="ssbpowder" & subcat1!="syrup" 

** notes	
** Assumed pint/pints = US pints because these products seemed to be US-based
** 'qt' seems to refer to reconsistituted quarts (e.g. Tang drink mix = xx quarts) 
	gen conversiontokg=.
	replace conversiontokg=0.0283495 if wordmatch1=="oz" & subcat1=="nonssbpowder" | subcat1=="ssbpowder" | subcat1=="syrup" 
	replace conversiontokg=0.001 if wordmatch1=="gr" | wordmatch1=="gm" | wordmatch1=="g" 
	replace conversiontokg=0.0002 if wordmatch1=="ct"
	replace conversiontokg=0.453592 if wordmatch1=="lb"	| wordmatch1=="lbs"
	
** after investigating, noticed some errors in product categories - correct
	replace subcat1="ssbpowder" if upc==62716485098
	replace subcat2="" if upc==62716485098
	replace ssb2="" if upc==62716485098
	
** Waitrose essential indian tonic reported in 425 gr when it's sold as 1L
	replace conversiontokg=. if upc==500016900922
	replace conversiontol=0.00235294117 if upc==500016900922


** calculate numbers to use, taking into account multi-packs	
	replace nummatch1=".5" if nummatch1=="1/2" 
	destring nummatch1 nummatch2 nummatch3, replace force 
	gen sizenumber=.
	replace sizenumber=nummatch1*nummatch2*nummatch3 if numpos3!=. 
	replace sizenumber=nummatch1*nummatch2 if numpos2!=. & numpos3==. 
	replace sizenumber=nummatch1 if numpos2==. 
	

** for liquid products, conver to litres
	gen litres = sizenumber * conversiontol
	
** for non-liquid products.. Assess
** first, get rid of non-beverage products (e.g. yogurts, teabags, etc. )
	drop if ssb==""
	
** review top-sellers of non-liquid products: 
	gsort - unit_sales
	
** top seller of ssb powders is Nestle cappucino
** "Recommended mix ratio: 28g per 6 fl. oz. (170 ml) water" - https://www.amazon.com/Nescafe-Coffee-French-Vanilla-Cappuccino/dp/B00B040C1W
** another top seller is Tang drink mix lemon 20g
** https://belairstore.com/product/tang-lemon-juice-mix-20g/
** 20gr makes 2 litres
** those are different enough - do this separately for powders by subdepartment=="HOT CHOCOLATE" vs subdepartment=="AMBIENT JUICES/BEVERAGES"
	
	gen reconsistitutedkgtol=.
	** 28gr=170ml = .170/.028=6.07
	replace reconsistitutedkgtol= 6.0714  if subdepartment=="HOT CHOCOLATE" & ssb=="powder"
	** 20gr=2L = .170/.028=6.07
	replace reconsistitutedkgtol= 100  if subdepartment=="AMBIENT JUICES/BEVERAGES" & ssb=="powder"
	** 1 scoop = 12 oz  - https://www.amazon.com/BioSteel-Hydration-Sugar-Free-Essential-Electrolytes/dp/B088H4QPTV
	** 7 gr = 12 oz =  1kg = 50L 
	replace reconsistitutedkgtol= 50  if subdepartment=="SOFT DRINKS" & ssb=="powder"
	
	
	
** syrups- "Ready to drink with cubes of ice, mix 1 part of syrup with 4 parts of water" https://www.amazon.com/Sorrel-Syrup-Windmill-Flavor-Barbados/dp/B09GWBXQHF 
** Assuming a common dilution ratio for syrups, which is often 1 part syrup to 4 parts water (a 1:5 ratio)
	replace reconsistitutedkgtol= 5  if subcat1=="syrup"
		
** Noticed some products missing sizes	
** for example, Caprisun products - fixed these manually as follows: 
	replace litres=.200 if brand=="CAPRISUN" & litres==. 
	replace litres = 6.75 if brand=="PHD" & description=="PHD Juices Mixed 27x250ml 27's" & litres==. 
	replace litres = 1.5 if brand=="FRUTA" & description=="FRUTA Juice Drink Buy 5+1 Free 6x 250ml" & litres==. 
	replace litres = 1.89 if brand=="TIPTON GROVE" & litres==. 
	
	replace litres =5.68  if size=="96ozx2"
	
** orchard drink sold with a free one- size was for individual product not combo 
	replace litres =1 if upc==1887182648
	
** for concentrates, assumed a 1:5 ratio again (the instructions for the 250ml bottle suggest a common dilution ratio such as 1 part concentrate to 4 parts water (a typical ratio for concentrates),)
	replace litres =litres*5 if bigcat=="concentrate" 

** actually do the calculation to replaces litres with reconstituted estimate in litres
	replace litres = reconsistitutedkgtol*conversiontokg*sizenumber if litres==. 
	
** fixing some issues
** some powders only list counts, not volume - e.g. swiss miss variety pack 8ct
	replace litres=. if wordmatch1=="ct" 
** note - this product was effectively dropped because of missing size information 

** generate $/Litre measure	
	gen costperl=est_price_vat/litres

** save a tempfile of data prepped so far 
	tempfile allyears
	save `allyears', replace 
	save "$outputfolder\allyears.dta", replace 
	
** bring in manually estimated product sizes
	import excel "G:\My Drive\02 Wellcome Fellowship\02 Project Files\05 Case Studies\02 Barbados\03 Sales Analysis\04 Data\missing sizes manual input.xlsx", clear firstrow
	tempfile sizestoadd
	save `sizestoadd', replace 
	
	
** merge on RPI and tourism data
	import excel "G:\My Drive\02 Wellcome Fellowship\02 Project Files\05 Case Studies\02 Barbados\03 Sales Analysis\04 Data\Barbados rpi.xlsx", clear firstrow
	drop tourism 
	rename tourism_cumulative tourism
	tempfile covar
	save `covar', replace
	
	use `allyears', clear
	
	cap drop _m
	merge m:1 month year using `covar'
	keep if _m==3
	
	** _m=2 are 2020 data - which we don't have data for. 
	** _m=1 are pre 2018 data, which we didn't extract covariates for. 
	
 
** Note: there are still products with missing size information - export and manually  fix: 

** merge on manually added size data
	drop _m 
	merge m:1 upc using `sizestoadd' 
	
	*_m =2 to exclude
	drop if _m==2
	
** replace liters with manual liters	
	replace litres =litres_est if litres_est!=. 
	drop litres_est

** now only 35 products are missing size data. 
** keep only products without missing size information: 
	keep if litres!=.
	
** save version of data to use	
	tempfile data
	save `data', replace 
	save "$outputfolder\data.dta", replace 

}

** *************************************************************************************************
**  data prep - append subcategories so that I can loop through all SSB and subcat1 categories
** *************************************************************************************************
{
*** Price analysis data prep 
** try to append subcategories so that I can loop through all SSB and subcat1 categories
	use `data', clear
	keep upc description weekind month year litres unit_sales bigcat ssb subcat1 costperl d_eff rpi tourism inflation_foodbevs inflation_restaurant_hotel inflation_all
	gen cat=ssb
	
	drop ssb subcat1
	tempfile file1
	save `file1', replace 
	
** generate second file to append on 
	use `data', clear
	keep upc description weekind month year litres unit_sales bigcat ssb subcat1 costperl d_eff rpi tourism inflation_foodbevs inflation_restaurant_hotel inflation_all
	gen cat=subcat1
	
	drop ssb subcat1
	
	append using `file1'
	
	
** adding holiday covariates 
	gen xmas=0
	replace xmas=1 if d_eff==22639 | d_eff==23003 | d_eff==23367 | d_eff==21540 | d_eff ==21904
	
	gen holidays =0
	replace holidays =1 if d_eff==22373   |  d_eff==22751 |    d_eff==22373  | d_eff==23108 
	** week before crop over and before xmas
	replace holidays =1 if d_eff==22632 | d_eff==22492 | d_eff==22856 | d_eff==22996 | d_eff==23220 | d_eff==23360 | d_eff==21897 | d_eff==21533
	replace holidays =1 if d_eff ==21911 
	
** generate hurricane indicator	
	gen hurricane=0
	replace hurricane =1 if d_eff==23185 //  tropical watch over Brett. https://reliefweb.int/report/barbados/lesser-antilles-caribbean-tropical-storm-bret-update-gdacs-noaa-echo-daily-flash-22-june-2023
	replace hurricane =1 if d_eff==21792 //https://www.weather.gov/sju/dorian2019
	replace hurricane =1 if d_eff==22464 // Elsa - https://www.weather.gov/tbw/HurricaneElsa#:~:text=Elsa%20affected%20many%20countries%20including,responsible%20for%2013%20direct%20fatalities.

** generate hours open to relate to covid19 restrictions = hours open/week 
	gen hoursopen=(6*12)+8
	replace hoursopen = 6*12 if d_eff<22436 & d_eff>=22282

** generate volume of sales measure 
	gen volume=unit_sales*litres
	
** gen covid indicator
	gen covid=(d_eff>=22282)

** 	re-anchor weekind at 1 for future regressions 
	summ weekind 
	replace weekind =weekind-`r(min)'+1
	
** generate a string version of date to make it easier to reference (e.g. for graphing the tax time point, etc.) 
	gen date=string(d_eff)
		
** drop 2 weeks pre/post Tax to account for any potential implementation issues
	drop if d_eff>=22723 & d_eff<22751
	replace weekind =weekind-4 if d_eff>=22751
	
** generate tax indicator 
	gen tax=d_eff>=22737
	
** gen trend
	gen trend =weekind 
	
** generate a numeric version of cat to help with setting panel data 		
	encode(cat), gen(catind)
	
** save dataset for analysis 
	tempfile appended_data
	save `appended_data', replace 
	
	save "$outputfolder\appended_data.dta", replace 
	

** price change data prep for analysis of weighted prices
** note that weighting happens in price var - doesn't need to happen in regression. 
	use "$outputfolder\appended_data.dta", clear
	
**	keep if pre_tax to use pre-tax volume to inform sales-weighting 
	keep if d_eff<22737

** generate sum of sales volume by product over whole pre-tax period 
	collapse (sum) volume, by(upc description cat) 

** generate product-type total sales volume over pre-tax period 
	bysort cat: egen totalsubcat1=total(volume)
	
** generate product-specific weight based on proportion of total pre-tax sales volume 
	gen weight=volume/total
	
	keep upc weight cat
	tempfile weights
	save `weights', replace 
	save "$outputfolder\weights.dta", replace 
	
** save order key to use later for table Export	
	import excel "G:\My Drive\02 Wellcome Fellowship\02 Project Files\05 Case Studies\02 Barbados\03 Sales Analysis\04 Data\order key.xlsx", clear firstrow
	tempfile order 
	save "$outputfolder\order.dta", replace 
	

}

** *************************************************************************************************
** Sales change analysis data prep 
** *************************************************************************************************
{
*** Sales analysis
** use the log-transformed total litres 
	use `appended_data', clear 
	
** generate a measure of volume SSB sales by cateogory and week - we are looking at total volume sold so sum over products within each category 
	collapse (sum) volume, by(weekind trend tax d_eff cat catind month rpi tourism holiday hoursopen xmas hurricane inflation_restaurant_hotel inflation_foodbevs inflation_all covid) 
	
** we had planned to use ln(volume) but after looking at these histograms it seems fine to use the untransformed volume measure instead. Generate to reproduce histograms. 
	gen ln_volume=ln(volume)
	
	// foreach x of local list {
		// histogram ln_volume  if cat=="`x'" & holiday==0 & xmas==0, scheme(plotplain) xtitle("") title("LN `x'")
		// graph export "`outputfolder'\histogram ln_sales_litres `x'.png", replace 
		
		// histogram volume  if cat=="`x'" & holiday==0 & xmas==0, scheme(plotplain) xtitle("") title("`x'")
		// graph export "`outputfolder'\histogram sales_litres `x'.png", replace 
		
		// twoway scatter ln_volume d_eff if cat=="`x'" & holiday==0 & xmas==0, xline(22737) scheme(plotplain) xtitle("") ytitle("Ln(Litres)") title("`x'")
		// graph export "`outputfolder'\sales_ln_litres `x'.png", replace 

		// twoway scatter volume d_eff if cat=="`x'" & holiday==0 & xmas==0, xline(22737) scheme(plotplain) xtitle("") ytitle("Litres") title("`x'") 
		// graph export "`outputfolder'\sales_litres `x'.png", replace 
		// }
	

** gen tax trend indicator ourselves 
	gen taxtrend=tax*trend 
	
** re-set so taxtrend starts at 1 
	replace taxtrend=taxtrend-167 if taxtrend!=0

** drop vinegar - because we have vinegar_white
	drop if cat=="vinegar" 
	
** generate control 
	gen control =(cat=="vinegar_white") 	
	
** generate month indicators
	forvalues y=1/12 {
		gen month`y'=(month==`y')
		} 

** make sine and cosine variables for seasonality
	gen sin1= sin(1 * -3.14 * trend/52)
	gen cos1= cos(1 * -3.14 * trend/52)
	gen sin2= sin(2 * -3.14 * trend/52)
	gen cos2= cos(2 * -3.14 * trend/52)
	gen sin3= sin(3 * -3.14 * trend/52)
	gen cos3= cos(3 * -3.14 * trend/52)
	

** generate fractional polynomial for seasonality 
	fp generate fpmonth = month^(-2 -1 -.5 0 .5 1 2 3)
		
** make rescaled data to enable controlled ITS (SSBs and vinegar are on such different scales, need to re-scale for analysis)
	bysort cat tax: egen mean=mean(volume) 
	bysort cat tax: egen sdvolume=sd(volume) 
	
** we only want to rescale using pre-tax mean/sd values - so get rid of post-tax ones and extend pre-tax measures 
	replace mean =. if tax==1
	replace sdvolume=. if tax==1
		
	gsort cat tax
	carryforward mean sdvolume, replace 

** generate a re-scaled volume measure to be used in the controlled sales ITS 
	gen volume2=(volume-mean)/sdvolume 
		
	tempfile dataforsales
	save `dataforsales', replace 
	
	save "$outputfolder\dataforsales.dta", replace 
	
 }
 
 