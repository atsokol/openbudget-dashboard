-- Create DuckDB database tables from CSV files with explicit schema
-- This script sets up the budget data warehouse from scratch
-- Each table has explicit column types and primary key constraints

-- Drop existing tables and views if they exist
DROP VIEW IF EXISTS budget_summary;
DROP TABLE IF EXISTS incomes;
DROP TABLE IF EXISTS expenses;
DROP TABLE IF EXISTS expenses_functional;
DROP TABLE IF EXISTS debts;
DROP TABLE IF EXISTS credits;

-- Create incomes table with explicit types and primary key
CREATE TABLE incomes (
    CITY VARCHAR NOT NULL,
    REP_PERIOD DATE NOT NULL,
    FUND_TYP VARCHAR NOT NULL,
    COD_BUDGET BIGINT NOT NULL,
    COD_INCO BIGINT NOT NULL,
    NAME_INC VARCHAR,
    ZAT_AMT DOUBLE,
    PLANS_AMT DOUBLE,
    FAKT_AMT DOUBLE,
    PRIMARY KEY (REP_PERIOD, FUND_TYP, COD_BUDGET, COD_INCO)
);

-- Load data into incomes table (CSV has different column order)
COPY incomes (REP_PERIOD, FUND_TYP, COD_BUDGET, COD_INCO, NAME_INC, ZAT_AMT, PLANS_AMT, FAKT_AMT, CITY) FROM 'csvs/incomes.csv' (HEADER true, nullstr 'NA');

-- Create expenses table with explicit types and primary key
CREATE TABLE expenses (
    CITY VARCHAR NOT NULL,
    REP_PERIOD DATE NOT NULL,
    FUND_TYP VARCHAR NOT NULL,
    COD_BUDGET BIGINT NOT NULL,
    COD_CONS_EK BIGINT NOT NULL,
    COD_CONS_EK_NAME VARCHAR,
    ZAT_AMT DOUBLE,
    PLANS_AMT DOUBLE,
    FAKT_AMT DOUBLE,
    FAKT_V2MB_AMT DOUBLE,
    FAKTSIK_AMT DOUBLE,
    FAKTSIK_V2MB_AMT DOUBLE,
    FAKTSPP_AMT DOUBLE,
    FAKTSPP_V2MB_AMT DOUBLE,
    FAKTSID_AMT DOUBLE,
    FAKTSID_V2MB_AMT DOUBLE,
    PRIMARY KEY (REP_PERIOD, FUND_TYP, COD_BUDGET, COD_CONS_EK)
);

-- Load data into expenses table (CSV has different column order)
COPY expenses (REP_PERIOD, FUND_TYP, COD_BUDGET, COD_CONS_EK, COD_CONS_EK_NAME, ZAT_AMT, PLANS_AMT, FAKT_AMT, FAKT_V2MB_AMT, FAKTSIK_AMT, FAKTSIK_V2MB_AMT, FAKTSPP_AMT, FAKTSPP_V2MB_AMT, FAKTSID_AMT, FAKTSID_V2MB_AMT, CITY) FROM 'csvs/expenses.csv' (HEADER true, nullstr 'NA');

-- Create expenses_functional table with explicit types and primary key
CREATE TABLE expenses_functional (
    CITY VARCHAR NOT NULL,
    REP_PERIOD DATE NOT NULL,
    FUND_TYP VARCHAR NOT NULL,
    COD_BUDGET BIGINT NOT NULL,
    COD_CONS_MB_FK BIGINT NOT NULL,
    COD_CONS_MB_FK_NAME VARCHAR,
    COD_CONS_MB_PK BIGINT NOT NULL,
    ZAT_AMT DOUBLE,
    FAKT_AMT DOUBLE,
    FAKT_V2MB_AMT DOUBLE,
    FAKTSIK_AMT DOUBLE,
    FAKTSIK_V2MB_AMT DOUBLE,
    FAKTSPP_AMT DOUBLE,
    FAKTSPP_V2MB_AMT DOUBLE,
    FAKTSID_AMT DOUBLE,
    FAKTSID_V2MB_AMT DOUBLE,
    PRIMARY KEY (REP_PERIOD, FUND_TYP, COD_BUDGET, COD_CONS_MB_FK, COD_CONS_MB_PK)
);

-- Load data into expenses_functional table (CSV has different column order, NA values in COD_CONS_MB_FK converted to 0)
INSERT INTO expenses_functional 
SELECT 
    CITY,
    REP_PERIOD,
    FUND_TYP,
    COD_BUDGET,
    COALESCE(COD_CONS_MB_FK, 0) as COD_CONS_MB_FK,
    COD_CONS_MB_FK_NAME,
    COD_CONS_MB_PK,
    ZAT_AMT,
    FAKT_AMT,
    FAKT_V2MB_AMT,
    FAKTSIK_AMT,
    FAKTSIK_V2MB_AMT,
    FAKTSPP_AMT,
    FAKTSPP_V2MB_AMT,
    FAKTSID_AMT,
    FAKTSID_V2MB_AMT
FROM read_csv('csvs/expenses_functional.csv', 
    columns = {
        'REP_PERIOD': 'DATE',
        'FUND_TYP': 'VARCHAR',
        'COD_BUDGET': 'BIGINT',
        'COD_CONS_MB_FK': 'BIGINT',
        'COD_CONS_MB_FK_NAME': 'VARCHAR',
        'COD_CONS_MB_PK': 'BIGINT',
        'ZAT_AMT': 'DOUBLE',
        'FAKT_AMT': 'DOUBLE',
        'FAKT_V2MB_AMT': 'DOUBLE',
        'FAKTSIK_AMT': 'DOUBLE',
        'FAKTSIK_V2MB_AMT': 'DOUBLE',
        'FAKTSPP_AMT': 'DOUBLE',
        'FAKTSPP_V2MB_AMT': 'DOUBLE',
        'FAKTSID_AMT': 'DOUBLE',
        'FAKTSID_V2MB_AMT': 'DOUBLE',
        'CITY': 'VARCHAR'
    },
    header = true,
    nullstr = 'NA'
);

-- Create debts table with explicit types and primary key
CREATE TABLE debts (
    CITY VARCHAR NOT NULL,
    REP_PERIOD DATE NOT NULL,
    FUND_TYP VARCHAR NOT NULL,
    COD_BUDGET BIGINT NOT NULL,
    COD_FINA BIGINT NOT NULL,
    NAME_FIN VARCHAR,
    ZAT_AMT DOUBLE,
    FAKT_AMT DOUBLE,
    PRIMARY KEY (REP_PERIOD, FUND_TYP, COD_BUDGET, COD_FINA)
);

-- Load data into debts table (CSV has different column order)
COPY debts (REP_PERIOD, FUND_TYP, COD_BUDGET, COD_FINA, NAME_FIN, ZAT_AMT, FAKT_AMT, CITY) FROM 'csvs/debts.csv' (HEADER true, nullstr 'NA');

-- Create credits table with explicit types and primary key
CREATE TABLE credits (
    CITY VARCHAR NOT NULL,
    REP_PERIOD DATE NOT NULL,
    FUND_TYP VARCHAR NOT NULL,
    COD_BUDGET BIGINT NOT NULL,
    COD_CRED_KK BIGINT NOT NULL,
    COD_CRED_KK_NAME VARCHAR,
    ZAT_AMT DOUBLE,
    PLANS_AMT DOUBLE,
    FAKT_AMT DOUBLE,
    FAKTBN_AMT DOUBLE,
    PRIMARY KEY (REP_PERIOD, FUND_TYP, COD_BUDGET, COD_CRED_KK)
);

-- Load data into credits table (CSV has different column order)
COPY credits (REP_PERIOD, FUND_TYP, COD_BUDGET, COD_CRED_KK, COD_CRED_KK_NAME, ZAT_AMT, PLANS_AMT, FAKT_AMT, FAKTBN_AMT, CITY) FROM 'csvs/credits.csv' (HEADER true, nullstr 'NA');

-- Create indexes for better query performance
CREATE INDEX idx_incomes_city_period ON incomes(CITY, REP_PERIOD);
CREATE INDEX idx_expenses_city_period ON expenses(CITY, REP_PERIOD);
CREATE INDEX idx_expenses_functional_city_period ON expenses_functional(CITY, REP_PERIOD);
CREATE INDEX idx_debts_city_period ON debts(CITY, REP_PERIOD);
CREATE INDEX idx_credits_city_period ON credits(CITY, REP_PERIOD);

-- Create aggregated view for dashboard
CREATE VIEW budget_summary AS
SELECT 
    i.CITY,
    i.REP_PERIOD,
    SUM(CASE WHEN i.FUND_TYP = 'T' THEN i.FAKT_AMT ELSE 0 END) / 1000000 as income,
    SUM(CASE WHEN e.FUND_TYP = 'T' THEN e.FAKT_AMT ELSE 0 END) / 1000000 as expense,
    YEAR(i.REP_PERIOD) as year,
    MONTH(i.REP_PERIOD) as month
FROM incomes i
LEFT JOIN expenses e ON i.CITY = e.CITY AND i.REP_PERIOD = e.REP_PERIOD
GROUP BY i.CITY, i.REP_PERIOD
ORDER BY i.CITY, i.REP_PERIOD;
