
PROJECT STRUCTURE


econometrics_project/
├── code/                    # Stata do files
├── data/                    # Raw and processed data
│   └── temp/               # Temporary files for analysis
├── log/                     # Log files from do file execution
├── output/                  # Final output (Excel tables)
└── README.txt              # This file


DO FILES DESCRIPTION


1. Replication_20251129.do (MAIN FILE)
   
   Purpose: Complete replication of Roychowdhury (2006) and extensions
            Includes Table 2, Table 4, and 3 extension analyses

   Input:   data/compustat_annual_1950_2025.dta
            data/ibes_summary_statistics.dta

   Output:  output/Replication_20251128.xlsx
            data/temp/compa_rem.dta
            data/temp/analysis_ready.dta

   Sections:

   A. Variable Construction (Lines 1-174)
      - Jones (1991) accruals: TA_at, normal_TA_at, abn_TA_at
      - Modified Jones (Dechow et al., 1995): modified_TA_at, abn_modified_TA_at
      - Roychowdhury (2006) real earnings management:
        * abn_cfo_at = actual CFO - normal CFO
        * abn_disexp_at = actual DISEXP - normal DISEXP
        * abn_prod_at = actual PROD - normal PROD
      - Control variables: SIZE, MTB, NI_scaled, IBEI_scaled

   B. IBES Matching (Lines 180-244)
      - Cleans IBES data: annual EPS forecasts only (FPI=="1", MEASURE=="EPS")
      - Uses consensus forecast one month before fiscal year end
      - Matching: CUSIP (8-digit) + year-month (ym) via joinby
      - For duplicates: keeps ACTUAL closest to epspx

   C. SUSPECT Variables (Lines 247-278)
      - SUSPECT_NI: IBEI/lagAT ∈ [0, 0.005)
      - SUSPECT_NI_ana: ufe (ACTUAL - MEDEST) ∈ (0, 0.005)
      - SUSPECT_NI_ana_fill: uses ufe if available, else IBEI/lagAT

   D. Table 2 Replication (Lines 303-452)
      - Sample: 1987-2001
      - Fama-MacBeth regressions for normal CFO, DISEXP, PROD, Accruals
      - Output: Excel sheet "Table2"

   E. Table 4 Replication (Lines 454-492)
      - Sample: 1987-2001
      - Model: Y_t = α + β1(SIZE)_{t-1} + β2(MTB)_{t-1} + β3(NI)_t + β4(SUSPECT)_t
      - Fama-MacBeth with Newey-West (3 lags)
      - Output: Excel sheets "Table4_original", "Table4_analyst"

   F. Extension 1: COVID × Contact Industry (Lines 494-516)
      - Sample: 2015-2023
      - Contact industries: Retail (SIC 52-59), Hospitality (70), Transportation (40-49)
      - DID: contact_sic2 × post (post = fyear >= 2020)
      - Output: Excel sheet "covid"

   G. Extension 2: Liquidity × COVID (Lines 518-565)
      - Sample: 2015-2023
      - Liquidity proxies:
        * cash_at = che/at (high cash → more EM capacity)
        * lev = (dltt + dlc)/at (high leverage → less EM capacity)
      - DID: hq2_cash_at × post, hq2_lev × post
      - Industry FE (sic2), clustered SE by gvkey
      - Output: Excel sheet "liquidity"


OUTPUT FILES


output/Replication_20251128.xlsx
   - Table2: Roychowdhury (2006) Table 2 replication (1987-2001)
   - Table4_original: Table 4 with SUSPECT_NI based on IBEI
   - Table4_analyst: Table 4 with SUSPECT_NI based on analyst forecast (filled with IBEI if missing)
   - covid: COVID × Contact Industry extension
   - liquidity: Liquidity × COVID extension (cash/assets and leverage)


NOTES


1. Analyst Forecast Extension:
   - Uses ufe = ACTUAL - MEDEST (unexpected forecast error)
   - If no analyst coverage, fills in with IBEI/AT
   - This allows using more observations while maintaining analyst-based measures where available

2. Liquidity Extension:
   - Cash/AT: Higher cash to assets → more capacity for earnings management (positive effect)
   - Leverage: Higher leverage → less flexibility for EM (negative effect)
   - Both measured as above/below median (hq2_*)

3. Results align with proposal directions, though some coefficients are not significant.
