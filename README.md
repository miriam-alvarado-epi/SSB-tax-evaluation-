Evaluation of an Increased Tax on Sugar-Sweetened Beverages in Barbados

Overview

This repository contains the Stata code underlying the interrupted time series (ITS) analyses associated with this protocol (Alvarado, M. Assessing the Barbados sugar-sweetened beverage tax increase from 10% to 20%. https://osf.io/7md5y/ (2024)) and reported in: 
Alvarado M, Sobers N, Adams J, Anderson S, Hambleton I, Murphy MM, Ng SW, Sharp SJ, Whiteman S, White M. Evaluation of an increased tax on sugar-sweetened beverages in Barbados: a case study in evidential pluralism to improve causal inference. [DOI: forthcoming]

The Government of Barbados introduced a 10% excise tax on sugar-sweetened beverages (SSBs) in 2015 and increased it to 20% in 2022. 
Using electronic point-of-sale data from a leading grocery chain (2018–2023, excluding 2020), we assessed the impact of the tax increase on SSB prices and sales volumes. 
We also assessed the potential impact of a 2023 school SSB ban on grocery store sales. 

Study Design

The analyses use single-group and controlled interrupted time series designs:
1.  Price analyses estimate mean percentage changes in sales-weighted cost per litre using log-transformed OLS regression with Newey-West standard errors.
2.  Sales analyses estimate mean absolute and relative changes in weekly litres sold using OLS regression with Newey-West standard errors.
3.  Controlled analyses use white vinegar as an untaxed, non-beverage control product to strengthen the counterfactual, with volume rescaled.
4.  Relative change estimation uses simulation (1,000 draws) from meta-analytic pooled estimates of absolute effects and counterfactual sales to construct 95% confidence intervals for percentage change.

Models adjust for monthly seasonality, retail price inflation, tourism arrivals, holidays (Crop Over, Easter, Christmas), hurricanes, and the COVID-19 period.
Beverage categories analysed include SSBs (sodas, juice drinks, syrups, sweetened dairy, other SSBs), non-SSBs (water, unsweetened juices, unsweetened dairy, other non-SSBs), and powders (sweetened and unsweetened).

Repository Structure and Analysis Pipeline
The master do-file (00_Master_Code_v2.do) runs all steps sequentially. Each step can also be run independently after Step 1 (data preparation) has been completed.
Step	Script	Description	Paper Reference
1.  data prep v2.do	Cleans raw electronic point-of-sale data; classifies products into beverage categories; converts concentrated products (syrups, powders) to reconstituted litre equivalents; generates analytical variables (trend, tax indicators, covariates)	Appendix Aim 1, Methods
2.  price analysis sales-weighted v3.do	Estimates percentage change in sales-weighted mean cost per litre for each beverage category using log-transformed ITS with Newey-West SEs	Table 1 (Price change columns); Appendix Eq. 1
3.  price analysis unweighted v2.do	Repeats price analysis without sales-weighting as a sensitivity analysis	Appendix Eq. 2
4.  price analysis controlled v2.do	Controlled price ITS using vinegar; estimates differential price change between SSBs and vinegar	Appendix Eq. 3
5.  sales analysis v2.do	Estimates absolute and relative changes in weekly sales volume (litres) for each beverage category; generates counterfactual predictions, and time series figures	Table 1 (Sales change columns); Figure 1; Appendix Eq. 4
6.  sales analysis controlled v2.do	Controlled sales ITS using vinegar with rescaled volumes; meta-analytic pooling of weekly effects; simulation-based relative change CIs; combined forest plots	Table 1 (Controlled columns); Appendix Figure 6; Appendix Eq. 5

Requirements
Software
•	Stata SE 17.0 (or later)

User-Written Stata Packages
The following community-contributed packages are required. Installation commands are included in the master do-file:
estout	Export regression tables
asgen	Weighted summary statistics
metan	Meta-analysis of weekly effects
moss	String parsing utilities
regsave	Save regression results to dataset
grstyle	Graph styling
plotplain	Clean graph scheme

Data
The analyses use electronic point-of-sale data from a major supermarket chain in Barbados covering 2,334 individual beverage products across all store locations, with weekly product-level volume and dollar sales from January 2018 to December 2023 (excluding 2020). These data are not publicly available due to restrictions required as a condition of the voluntary data-sharing agreement with the grocery store chain. Enquiries about data access should be directed to the corresponding author.

The code also requires:
1.   Monthly retail price index (RPI) for Barbados
2.   Monthly tourism arrival statistics
3.   Holiday and hurricane indicator data

Setup and Execution
1.	Install Stata SE 17.0 or later.
2.	Install all required user-written packages (see above).
3.	Update the folder paths in 00_Master_Code_v2.do (global inputfolder, global outputfolder, global codefolder)
4.	Run the master file: do "00_Master_Code_v2.do"

Key Outputs
The pipeline generates:
1.  Regression tables (CSV): coefficient estimates for all price and sales models
2.  Time series figures (PNG): observed data with modelled predictions and counterfactual estimates for each beverage category
3.  Summary tables (CSV): mean and end-of-study absolute and relative effect estimates by category

Citation
If you use this code, please cite the accompanying paper (forthcoming). 

License
This code is released under the MIT License.

Contact
For questions about the code or data access, please contact:
Miriam Alvarado (Corresponding Author) MRC Epidemiology Unit, University of Cambridge 
mra47@cam.ac.uk
