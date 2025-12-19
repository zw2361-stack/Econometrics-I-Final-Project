
glo path "/Users/ziqingwang/Dropbox/econometrics_project/data/"
global excel_name "/Users/ziqingwang/Dropbox/econometrics_project/output/Replication_20251128.xlsx"
//glo path "/Users/note/Library/CloudStorage/Dropbox/econometrics_project/data/"
//global excel_name "/Users/note/Library/CloudStorage/Dropbox/econometrics_project/output/Replication_20251128.xlsx"

* Start log file
capture log close
log using "$path/../output/Replication_20251129.log", replace
**********************************************************************************************************************************
************************* Compustat-revelant values ********************************
**********************************************************************************************************************************
use "$path/compustat_annual_1950_2025.dta",clear
keep act che lct dd1 txp dp at ppent revt ni csho prcc_f sale ib oancf xidoc cogs invt epspx xrd xad xsga ni sich gvkey datadate fyear pstk dltt dlc invt dlc rect fyr ceq cusip lt
drop if at == .

duplicates drop gvkey fyear,force
destring gvkey, gen(gvkey_num)
xtset gvkey_num fyear

*firm age, identify the first year the firm exist
bys gvkey: egen first_fyear = min(fyear)
gen firm_age = fyear - first_fyear

*calculate some variables
xtset gvkey_num fyear
gen lagAT = l1.at


*******************************
*Jones (Jones EtAl 1991)
*******************************
* follows: TAt = [delta_Current Assets-deltaCasht (1)] - [deltaCurrent Liabilitiest (5) - deltaCurrent Maturities of deltaLong-Term Debtt (44) - deltaIncome Taxes Payablet (71)] - deltaDepreciation and Amortization Expenset (14), 
*TAt = [delta_Current Assets-deltaCasht (1)] - [deltaCurrent Liabilitiest (5) ] - deltaDepreciation and Amortization Expenset (14), 
* Section5: TA_at = a1(1/Asset ) + a2(Delta_REV/Asset) +a3 (PPE/Asset)
//gen TA_at = (((act-l1.act) - (che-l1.che)) - ((lct-l1.lct)-(dd1-l1.dd1)-(txp-l1.txp)) -dp )/lagAT
gen TA_at = (((act-l1.act) - (che-l1.che)) - (lct-l1.lct) -dp )/lagAT
gen ppent_at = ppent/lagAT
gen rev_chg_at = (revt - l1.revt)/lagAT

*******************************
*Modified Jones (Deschow EtAL, 1995)
*******************************
* TAt = (Delta_CAt- Delta_CL, - Delta_Casht + Delta_STD - Dept)/Asset
* TA_at = a1(1/Asset ) + a2((Delta_REV - Delta_REC)/Asset) +a3 (PPE/Asset)
/*
Delta_CA = change in current assets (COMPUSTAT item 4);
Delta_CL = change in current liabilities (COMPUSTAT item 5);
Delta_Cash = change in cash and cash equivalents (COMPUSTAT item 1);
Delta_STD = change in debt included in current liabilities (COMPUSTAT item 34); 
Dep = depreciation and amortization expense (COMPUSTAT item 14); and A = Total Assets (COMPUSTAT item 6).
*/
gen modified_TA_at = ((act-l1.act) - (che-l1.che) - (lct-l1.lct) +(dlc-l1.dlc) -dp )/lagAT
gen modified_rev_chg_at = ((revt - l1.revt) - (rect - l1.rect))/lagAT

*******************************
*Roychowdhury (Roychowdhury, 2006)
*******************************
/*
CFOt/At-1 = a0+a1(1/At-1)+b1(St/At-1)+b2(DSt/At-1)+et
DISEXPt/At-1 = a0+a1(1/At-1)+b(St-1/At-1)+et
PRODt/At-1 = a0+a1(1/At-1)+b1(St/At-1)+b2(DSt/At-1)+b3(DSt-1/At-1)+et 
Accrualst/At-1 = a0+a1(1/At-1)+b1(DSt/At-1)+b2(PPEt-1/At-1)+et
*/
gen cfo_at=oancf/lagAT
gen inv_at = 1/lagAT
gen sale_at = sale/lagAT
gen sale1_at = l1.sale/lagAT
gen sale_chg_at = (sale-l1.sale)/lagAT
gen sale1_chg_at = (l1.sale- l2.sale)/lagAT
*Discretionary expenses (DISEXP): R&D (data#46)+Advertising (data#45)+Selling, General and Administrative expenses (data#189); as long as SG&A is available, advertising and R&D are set to zero if they are missing
gen xrd1 = xrd
replace xrd1 = 0 if xrd == .
gen xad1 = xad
replace xad1 = 0 if xad == .
gen disexp_at = (xrd1 + xad1 + xsga)/lagAT
*Production costs: COGS+Change in inventory, inventory is COMPUSTAT data#3
gen prod_at = (cogs+ (invt-l1.invt))/lagAT
*Accruals : IBEI–CFO
gen accrual_at = (ib- oancf)/lagAT

**********************
*additional vars
**********************
* Calculate Market Value of Equity (MVE)
gen mve = prcc_f * csho

* Calculate SIZE (log of market value of equity at beginning of year)
* Need lagged value, so first calculate current then lag
gen SIZE_current = log(mve)
xtset gvkey_num fyear
gen SIZE = l1.SIZE_current  // SIZE_{t-1}

* Calculate MTB (Market-to-Book ratio)
* Book value of equity = Total Assets - Preferred Stock
gen MTB_current = mve / ceq
gen MTB = l1.MTB_current  // MTB_{t-1}

* Calculate Net Income scaled by lagged total assets (for control variable)
* Following Roychowdhury (2006): "net income scaled by lagged total assets, similar to ROA"
gen NI_scaled = ni / lagAT

* Calculate IBEI scaled by lagged total assets (for SUSPECT_NI definition)
* Following Roychowdhury (2006): "indicator variable set equal to one if income before
* extraordinary items (IBEI) scaled by lagged total assets is between 0 and 0.005"
gen IBEI_scaled = ib / lagAT

* Drop observations with missing values
drop if SIZE == . | MTB == . | NI_scaled == . | IBEI_scaled == .


*drop if missing industry
drop if sich == . 
keep if sich>1000
gen sic2 = int(sich/100)

bys sic2 fyear: gen ind_year_n = _N
* Keep only industry-years with at least 15 firms (as in the paper)
keep if ind_year_n >= 15
drop ind_year_n

gen cusip8 = upper(trim(substr(cusip, 1, 8)))
replace cusip8 = "" if length(cusip8) < 8

*keep Roychowdhury Sample
//keep if fyear>=1987 & fyear<=2001
winsor2 TA_at modified_TA_at  cfo_at disexp_at prod_at accrual_at inv_at sale_at sale_chg_at sale1_chg_at ppent_at modified_rev_chg_at , cuts(1 99) replace

*generate normal value and abnormal value
*Normal Jones
*TA_at = a1(1/Asset ) + a2(Delta_REV/Asset) +a3 (PPE/Asset)
*Because earnings manipulation involves both positive and negative values of accruals, therefore, we take the absolute value, (Bergstresser and Philippon,2006 JFE also use the absolute value)
bys sic2 fyear: asreg TA_at inv_at rev_chg_at ppent_at 
gen normal_TA_at = _b_cons + _b_inv_at*inv_at + _b_rev_chg_at*rev_chg_at + _b_ppent_at*ppent_at
rename _* NJ_*

gen abn_TA_at = abs(TA_at - normal_TA_at)

*Modified Jones
*TA_at = a1(1/Asset ) + a2((Delta_REV - Delta_REC)/Asset) +a3 (PPE/Asset)
bys sic2 fyear: asreg modified_TA_at inv_at modified_rev_chg_at ppent_at 
gen normal_modified_TA_at = _b_cons + _b_inv_at*inv_at + _b_modified_rev_chg_at*modified_rev_chg_at + _b_ppent_at*ppent_at
rename _* MJ_*

gen abn_modified_TA_at = abs(modified_TA_at - normal_modified_TA_at)

*Roychowdhury, 2006
*CFOt/At-1 = a0+a1(1/At-1)+b1(St/At-1)+b2(DSt/At-1)+et
*Roychowdhury: suspect firm-years exhibit at least one of the following: unusually low cash flow from operations (CFO) OR unusually low discretionary expenses. therefore, the lower the cfo, the higher the earning mgt.
bys sic2 fyear: asreg cfo_at inv_at sale_at sale_chg_at 
gen normal_cfo_at = _b_cons + _b_inv_at*inv_at + _b_sale_at*sale_at + _b_sale_chg_at*sale_chg_at
rename _* RoyC1_*

gen abn_cfo_at = (cfo_at - normal_cfo_at)

*DISEXPt/At-1 = a0+a1(1/At-1)+b(St-1/At-1)+et
*Roychowdhury: Reduction of discretionary expenditures. therefore, the lower the disexp, the higher the earning mgt.
bys sic2 fyear: asreg disexp_at inv_at sale1_at
gen normal_disexp_at = _b_cons + _b_inv_at*inv_at + _b_sale1_at*sale1_at 
rename _* RoyC2_*

gen abn_disexp_at = (disexp_at - normal_disexp_at)

*PRODt/At-1 = a0+a1(1/At-1)+b1(St/At-1)+b2(DSt/At-1)+b3(DSt-1/At-1)+et 
*Roychowdhury: Overproduction, or increasing production to report lower COGS. therefore, the larger the production cost, the higher the earning mgt.
bys sic2 fyear: asreg prod_at inv_at sale_at sale_chg_at sale1_chg_at 
gen normal_prod_at = _b_cons + _b_inv_at*inv_at + _b_sale_at*sale_at + _b_sale_chg_at*sale_chg_at + _b_sale1_chg_at*sale1_chg_at 
rename _* RoyC3_*

gen abn_prod_at = prod_at - normal_prod_at

*Accrualst/At-1 = a0+a1(1/At-1)+b1(DSt/At-1)+b2(PPEt-1/At-1)+et
bys sic2 fyear: asreg accrual_at inv_at sale_chg_at ppent_at 
gen normal_accrual_at = _b_cons + _b_inv_at*inv_at + _b_sale_chg_at*sale_chg_at + _b_ppent_at*ppent_at 
rename _* RoyC4_*

gen abn_accrual_at = abs(accrual_at - normal_accrual_at)

drop if abn_cfo_at == . | abn_disexp_at == . | abn_prod_at == .
save "$path/temp/compa_rem.dta",replace



*************************************************
*IBES
*************************************************
use "$path/ibes_summary_statistics.dta", clear
*only keep annual forecast
keep if FPI == "1"  
drop if ANNDATS_ACT == .
* keep only EPS forecast
keep if MEASURE == "EPS"
keep if STATPERS<ANNDATS_ACT
drop if MEDEST == .
drop if ACTUAL == .
drop if STDEV == .
drop if NUMEST == .

gen ufe = ACTUAL - MEDEST
* Keep only firms with analyst coverage
keep if NUMEST > 0 & NUMEST != .
drop if MEDEST == .

* Generate year-month of the statistics period (when forecast was made)
gen ym = mofd(STATPERS)
format ym %tm

* Clean CUSIP for merging (8-digit, uppercase)
gen cusip8 = upper(trim(substr(CUSIP, 1, 8)))
replace cusip8 = "" if cusip8 == "" | length(cusip8) < 6

* Keep necessary variables (including ACTUAL for duplicate handling)
keep cusip8 ym NUMEST MEANEST MEDEST STDEV FPEDATS ACTUAL ufe

save "$path/temp/ibes_clean.dta", replace

**************************************************************************************************
*Merge Compustat with IBES via CUSIP and year-month
**************************************************************************************************
* Use the consensus forecast one month before fiscal year end

use "$path/temp/compa_rem.dta", clear

* Generate year-month of fiscal year end from Compustat
* fyr = fiscal year end month (1-12)
gen year_temp = fyear
replace year_temp = fyear + 1 if fyr <= 5  // Adjust for fiscal years ending in Jan-May
gen ym = ym(year_temp, fyr)
format ym %tm

* Get forecast one month before fiscal year end
replace ym = ym - 1
drop year_temp

* Merge with IBES using joinby (allows multiple matches, then we pick the best)
joinby cusip8 ym using "$path/temp/ibes_clean.dta", unmatched(master)

* Handle duplicates: if multiple forecasts for same firm-year, keep ACTUAL closest to epspx
bys gvkey fyear: gen dup = _N
gen diff = abs(ACTUAL - epspx)
sort gvkey fyear diff
duplicates drop gvkey fyear, force
drop dup diff

* Create indicator for analyst coverage
gen has_analyst = (NUMEST != . & NUMEST > 0)
drop _merge


* SUSPECT_NI: Indicator = 1 if firm-year is in earnings category just right of zero
* Following Roychowdhury (2006):
*   "An indicator variable that is set equal to one if income before extraordinary
*    items (IBEI) scaled by lagged total assets is between 0 and 0.005,
*    and is set equal to zero otherwise."
* Note: IBEI = ib (Compustat item), NOT ni (net income)

gen SUSPECT_NI = 0 if IBEI_scaled!=.
replace SUSPECT_NI = 1 if IBEI_scaled >= 0 & IBEI_scaled < 0.005 & IBEI_scaled != .

*definition of suspect ni using the analyst forecasts
gen SUSPECT_NI_ana = 0 if ufe!=.
replace SUSPECT_NI_ana = 1 if ufe > 0 & ufe < 0.005 & ufe != .

gen SUSPECT_NI_ana1 = 0 if ufe!=.
replace SUSPECT_NI_ana1 = 1 if ufe > 0 & ufe < 0.01 & ufe != .

gen SUSPECT_NI_ana2 = 0 if ufe!=.
replace SUSPECT_NI_ana2 = 1 if ufe > 0 & ufe < 0.03 & ufe != .

*if missing analyst, using IBEI_scaled instead
gen SUSPECT_NI_ana_fill = 0 if ufe!=. | IBEI_scaled!=.
replace SUSPECT_NI_ana_fill = 1 if ufe > 0 & ufe < 0.005 & ufe != .
replace SUSPECT_NI_ana_fill = 1 if ufe == . & IBEI_scaled >= 0 & IBEI_scaled < 0.005 & IBEI_scaled != .

gen SUSPECT_NI_ana1_fill = 0 if ufe!=. | IBEI_scaled!=.
replace SUSPECT_NI_ana1_fill = 1 if ufe > 0 & ufe < 0.001 & ufe != .
replace SUSPECT_NI_ana1_fill = 1 if ufe == . & IBEI_scaled >= 0 & IBEI_scaled < 0.001 & IBEI_scaled != .

gen SUSPECT_NI_ana2_fill = 0 if ufe!=. | IBEI_scaled!=.
replace SUSPECT_NI_ana2_fill = 1 if ufe > 0 & ufe < 0.003 & ufe != .
replace SUSPECT_NI_ana2_fill = 1 if ufe == . & IBEI_scaled >= 0 & IBEI_scaled < 0.003 & IBEI_scaled != .

 
*Deviation of industry-year mean
* Since dependent variables are deviations from 'normal' levels within industry-year,
* all control variables are also expressed as deviations from industry-year means

* Variables to demean: SIZE, MTB, NI_scaled (controls)
* Dependent variables (abn_cfo_at, abn_disexp_at, abn_prod_at) are already abnormal values

foreach var in SIZE MTB NI_scaled {
    bys sic2 fyear: egen mean_`var' = mean(`var')
    gen `var'_dev = `var' - mean_`var'
    label var `var'_dev "Deviation from ind-year mean: `var'"
}
rename NI_scaled_dev NI_dev
* Winsorize at 1% and 99%
winsor2 SIZE_dev MTB_dev NI_dev abn_cfo_at abn_disexp_at abn_prod_at ufe, cuts(1 99) replace

* Save temp file for extension analysis later
save "$path/temp/analysis_ready.dta", replace




*************************************************************************************************************************************************************************************************************************************
******************************************************************************
*Replication Table2
******************************************************************************
use "$path/temp/analysis_ready.dta",clear
keep if fyear>=1987 & fyear<=2001
*exclude utilities (SIC 4900-4999)
gen exclude_industry = (sic2 >= 49 & sic2 <= 49) | (sic2 >= 60 & sic2 <= 67)
tab exclude_industry
drop if exclude_industry == 1
drop exclude_industry

keep sic2 fyear Roy*

collapse (mean) Roy*, by(sic2 fyear)
*Industry-years with fewer than 15 firms are eliminated from the sample
keep if RoyC1_Nobs>=15 & RoyC2_Nobs>=15 & RoyC3_Nobs>=15 & RoyC4_Nobs>=15 & RoyC1_Nobs!=. & RoyC2_Nobs!=. & RoyC3_Nobs!=. & RoyC4_Nobs!=.
/*
. dis _N
697
*Notes: More obs than Roychowdhury
*/
winsor2 Roy*, cuts(1 99) replace
foreach var in inv_at sale_at sale_chg_at cons{
gen RoyC1_t_`var' = .
summ RoyC1_b_`var'
replace RoyC1_t_`var' = r(mean) / (r(sd) / sqrt(_N))
}

foreach var in inv_at sale1_at  cons{
gen RoyC2_t_`var' = .
summ RoyC2_b_`var'
replace RoyC2_t_`var' = r(mean) / (r(sd) / sqrt(_N))
}

foreach var in inv_at sale_at sale_chg_at sale1_chg_at  cons{
gen RoyC3_t_`var' = .
summ RoyC3_b_`var'
replace RoyC3_t_`var' = r(mean) / (r(sd) / sqrt(_N))
}

foreach var in inv_at sale_chg_at ppent_at   cons{
gen RoyC4_t_`var' = .
summ RoyC4_b_`var'
replace RoyC4_t_`var' = r(mean) / (r(sd) / sqrt(_N))
}


collapse (mean) Roy*
keep RoyC1_* RoyC2_* RoyC3_* RoyC4_*
gen id = 1   // temporary ID to reshape
reshape long RoyC1_ RoyC2_ RoyC3_ RoyC4_ , i(id) j(param) string

*order the rows as Table 2 in Roychowdhury (2006)
gen order = .

replace order = 1    if param == "b_cons"
replace order = 1.1  if param == "t_cons"

replace order = 2    if param == "b_inv_at"
replace order = 2.1  if param == "t_inv_at"

replace order = 3    if param == "b_sale_at"
replace order = 3.1  if param == "t_sale_at"

replace order = 4    if param == "b_sale1_at"
replace order = 4.1  if param == "t_sale1_at"

replace order = 5    if param == "b_sale_chg_at"
replace order = 5.1  if param == "t_sale_chg_at"

replace order = 6    if param == "b_sale1_chg_at"
replace order = 6.1  if param == "t_sale1_chg_at"

replace order = 7    if param == "b_ppent_at"
replace order = 7.1  if param == "t_ppent_at"

replace order = 8    if param == "adjR2"
sort order
drop if order == .
drop order

* tabulate Table 2
gen CFO     = ""
gen DISEXP  = ""
gen PROD    = ""
gen ACCRUAL = ""

local N = _N

forvalues i = 1/`N' {

    local p = param[`i']

    * coef _b
    if substr("`p'",1,2)=="b_" {

        * next row is tstat
        local j = `i' + 1

        * --- coef ---
        scalar c1 = RoyC1_[`i']
        scalar c2 = RoyC2_[`i']
        scalar c3 = RoyC3_[`i']
        scalar c4 = RoyC4_[`i']

        * --- tstat ---
        scalar t1 = RoyC1_[`j']
        scalar t2 = RoyC2_[`j']
        scalar t3 = RoyC3_[`j']
        scalar t4 = RoyC4_[`j']

        * stars
        local s1 ""
        if abs(t1)>=2.58    local s1 "***"
        else if abs(t1)>=1.96  local s1 "**"
        else if abs(t1)>=1.645 local s1 "*"

        local s2 ""
        if abs(t2)>=2.58    local s2 "***"
        else if abs(t2)>=1.96  local s2 "**"
        else if abs(t2)>=1.645 local s2 "*"

        local s3 ""
        if abs(t3)>=2.58    local s3 "***"
        else if abs(t3)>=1.96  local s3 "**"
        else if abs(t3)>=1.645 local s3 "*"

        local s4 ""
        if abs(t4)>=2.58    local s4 "***"
        else if abs(t4)>=1.96  local s4 "**"
        else if abs(t4)>=1.645 local s4 "*"

        * coef 
        replace CFO     = string(c1,"%9.4f") + "`s1'" if !missing(c1) in `i'
        replace DISEXP  = string(c2,"%9.4f") + "`s2'" if !missing(c2) in `i'
        replace PROD    = string(c3,"%9.4f") + "`s3'" if !missing(c3) in `i'
        replace ACCRUAL = string(c4,"%9.4f") + "`s4'" if !missing(c4) in `i'

        * t-stat
        replace CFO     = "(" + string(t1,"%9.2f") + ")" if !missing(t1) in `j'
        replace DISEXP  = "(" + string(t2,"%9.2f") + ")" if !missing(t2) in `j'
        replace PROD    = "(" + string(t3,"%9.2f") + ")" if !missing(t3) in `j'
        replace ACCRUAL = "(" + string(t4,"%9.2f") + ")" if !missing(t4) in `j'
    }

    * R2
    if "`p'"=="adjR2" {
        replace CFO     = string(RoyC1_,"%4.2f") in `i'
        replace DISEXP  = string(RoyC2_,"%4.2f") in `i'
        replace PROD    = string(RoyC3_,"%4.2f") in `i'
        replace ACCRUAL = string(RoyC4_,"%4.2f") in `i'
    }
}

keep param CFO DISEXP PROD ACCRUAL
export excel using "$excel_name", sheet("Table2") firstrow(variables) sheetreplace

******************************************************************************
*Replication Table4
******************************************************************************
use "$path/temp/analysis_ready.dta",clear
*exclude utilities (SIC 4900-4999)
gen exclude_industry = (sic2 >= 49 & sic2 <= 49) | (sic2 >= 60 & sic2 <= 67)
tab exclude_industry
drop if exclude_industry == 1
drop exclude_industry

keep if fyear>=1987 & fyear<=2001
winsor2 SIZE_dev MTB_dev NI_dev abn_cfo_at abn_disexp_at abn_prod_at ufe, cuts(1 99) replace

xtset gvkey_num fyear
capture drop _*
asreg abn_cfo_at SIZE_dev MTB_dev NI_dev SUSPECT_NI,fmb newey(3)
outreg2 using "$path/temp/t4.txt", replace adjr2 tstat tdec(2) bdec(3) 

asreg abn_disexp_at SIZE_dev MTB_dev NI_dev SUSPECT_NI,fmb newey(3)
outreg2 using "$path/temp/t4.txt", append adjr2 tstat tdec(2) bdec(3) 

asreg abn_prod_at SIZE_dev MTB_dev NI_dev SUSPECT_NI,fmb newey(3)
outreg2 using "$path/temp/t4.txt", append adjr2 tstat tdec(2) bdec(3) 


preserve
import delimited using "$path/temp/t4.txt", clear
export excel using "$excel_name", sheet("Table4_original", replace)
restore

**using the suspect ni from analyst forecast, fill in with IBEI/AT if missing
asreg abn_cfo_at SIZE_dev MTB_dev NI_dev SUSPECT_NI_ana,fmb newey(3)
outreg2 using "$path/temp/t4.txt", replace adjr2 tstat tdec(2) bdec(3) 

*suspect NI
asreg abn_disexp_at SIZE_dev MTB_dev NI_dev SUSPECT_NI_ana,fmb newey(3)
outreg2 using "$path/temp/t4.txt", append adjr2 tstat tdec(2) bdec(3) 

asreg abn_prod_at SIZE_dev MTB_dev NI_dev SUSPECT_NI_ana,fmb  newey(3)
outreg2 using "$path/temp/t4.txt", append adjr2 tstat tdec(2) bdec(3) 

preserve
import delimited using "$path/temp/t4.txt", clear
export excel using "$excel_name", sheet("Table4_analyst_only", replace)
restore

**using the suspect ni from analyst forecast, fill in with IBEI/AT if missing
asreg abn_cfo_at SIZE_dev MTB_dev NI_dev SUSPECT_NI_ana1_fill,fmb newey(3)
outreg2 using "$path/temp/t4.txt", replace adjr2 tstat tdec(2) bdec(3) 

*suspect NI
asreg abn_disexp_at SIZE_dev MTB_dev NI_dev SUSPECT_NI_ana1_fill,fmb newey(3)
outreg2 using "$path/temp/t4.txt", append adjr2 tstat tdec(2) bdec(3) 

asreg abn_prod_at SIZE_dev MTB_dev NI_dev SUSPECT_NI_ana1_fill,fmb  newey(3)
outreg2 using "$path/temp/t4.txt", append adjr2 tstat tdec(2) bdec(3) 

preserve
import delimited using "$path/temp/t4.txt", clear
export excel using "$excel_name", sheet("Table4_analyst", replace)
restore

******************************************************************************
*Covid
******************************************************************************
use "$path/temp/analysis_ready.dta",clear
winsor2 abn_cfo_at abn_disexp_at abn_prod_at SIZE_dev MTB_dev NI_dev, cuts(1 99) replace
*exclude utilities (SIC 4900-4999)
gen exclude_industry = (sic2 >= 49 & sic2 <= 49) | (sic2 >= 60 & sic2 <= 67)
tab exclude_industry
drop if exclude_industry == 1
drop exclude_industry

keep if fyear>=2015 & fyear<=2023
*Hospitality, Retail, Transportation Industry
gen contact_sic2 = (sic2>=52 & sic2<=59) | sic2==70 | (sic2>=40 & sic2<=49)
gen post = (fyear>=2020)

reghdfe abn_cfo_at c.contact_sic2##c.post SIZE_dev MTB_dev NI_dev , noabsorb  cl(gvkey)
outreg2 using "$path/temp/covid.txt", replace adjr2 tstat tdec(2) bdec(3) 

reghdfe abn_disexp_at c.contact_sic2##c.post SIZE_dev MTB_dev NI_dev , noabsorb  cl(gvkey)
outreg2 using "$path/temp/covid.txt", append adjr2 tstat tdec(2) bdec(3) 

reghdfe abn_prod_at c.contact_sic2##c.post SIZE_dev MTB_dev NI_dev , noabsorb  cl(gvkey)
outreg2 using "$path/temp/covid.txt", append adjr2 tstat tdec(2) bdec(3) 

preserve
import delimited using "$path/temp/covid.txt", clear
export excel using "$excel_name", sheet("covid", replace)
restore

******************************************************************************
*Liquidity
******************************************************************************
use "$path/temp/analysis_ready.dta",clear

*exclude utilities (SIC 4900-4999)
gen exclude_industry = (sic2 >= 49 & sic2 <= 49) | (sic2 >= 60 & sic2 <= 67)
tab exclude_industry
drop if exclude_industry == 1
drop exclude_industry

keep if fyear>=2015 & fyear<=2023
gen post = (fyear>=2020)
* Cash to assets
gen cash_at = che / at

* Book leverage (common)
gen lev = (dltt + dlc) / at

*Definition: cash/At (positively affect EM) OR Leverage above median (negatively affect EM)
foreach i in 2 {
foreach var in cash_at lev  {
			egen q`i'_`var' = xtile(`var'), nq(`i')
			gen hq`i'_`var' = 0 if `var'!=.
			replace hq`i'_`var' = 1 if q`i'_`var' ==`i'
			drop q`i'*
}
}

winsor2 abn_cfo_at abn_disexp_at abn_prod_at SIZE_dev MTB_dev NI_dev cash_at lev , cuts(1 99) replace

reghdfe abn_cfo_at c.hq2_cash_at##c.post SIZE_dev MTB_dev NI_dev , absorb(sic2)   cl(gvkey)
outreg2 using "$path/temp/liquidity.txt", replace adjr2 tstat tdec(2) bdec(3) 

reghdfe abn_disexp_at c.hq2_cash_at##c.post SIZE_dev MTB_dev NI_dev , absorb(sic2)   cl(gvkey)
outreg2 using "$path/temp/liquidity.txt", append adjr2 tstat tdec(2) bdec(3) 

reghdfe abn_prod_at c.hq2_cash_at##c.post SIZE_dev MTB_dev NI_dev , absorb(sic2)   cl(gvkey)
outreg2 using "$path/temp/liquidity.txt", append adjr2 tstat tdec(2) bdec(3) 


reghdfe abn_cfo_at c.hq2_lev##c.post SIZE_dev MTB_dev NI_dev , absorb(sic2)   cl(gvkey)
outreg2 using "$path/temp/liquidity.txt", append adjr2 tstat tdec(2) bdec(3) 

reghdfe abn_disexp_at c.hq2_lev##c.post SIZE_dev MTB_dev NI_dev , absorb(sic2)   cl(gvkey)
outreg2 using "$path/temp/liquidity.txt", append adjr2 tstat tdec(2) bdec(3) 

reghdfe abn_prod_at c.hq2_lev##c.post SIZE_dev MTB_dev NI_dev , absorb(sic2)   cl(gvkey)
outreg2 using "$path/temp/liquidity.txt", append adjr2 tstat tdec(2) bdec(3) 

preserve
import delimited using "$path/temp/liquidity.txt", clear
export excel using "$excel_name", sheet("liquidity", replace)
restore



