
/*------------------------------------------
 1. Basic Data Exploration
-------------------------------------------*/
-- View raw data structure
SELECT * FROM layoffs LIMIT 10;

-- Extreme values analysis
SELECT 
    MAX(percentage_laid_off) AS max_percentage,
    MAX(total_laid_off) AS max_total_laid_off
FROM layoffs;

/* Key Insight:
   Identifies worst-case scenarios - companies with 100% staff reduction
   and largest absolute layoff numbers */

-- Full closure analysis
SELECT *
FROM layoffs
WHERE percentage_laid_off = 1
ORDER BY total_laid_off DESC;

/*------------------------------------------
 2. Dimension-Based Analysis
-------------------------------------------*/
-- Company impact ranking
SELECT 
    company,
    SUM(total_laid_off) AS total_layoffs,
    COUNT(*) AS layoff_events,
    AVG(percentage_laid_off) AS avg_percentage
FROM layoffs
GROUP BY company
ORDER BY total_layoffs DESC;

-- Industry impact analysis
SELECT 
    industry,
    SUM(total_laid_off) AS total_layoffs,
    ROUND(SUM(total_laid_off) * 100.0 / 
        (SELECT SUM(total_laid_off) FROM layoffs), 2) AS industry_share
FROM layoffs
GROUP BY industry
ORDER BY total_layoffs DESC;

-- Geographic impact breakdown
SELECT 
    country,
    SUM(total_laid_off) AS total_layoffs,
    COUNT(DISTINCT company) AS affected_companies
FROM layoffs
GROUP BY country
ORDER BY total_layoffs DESC;

/*------------------------------------------
 3. Temporal Analysis
-------------------------------------------*/
-- Dataset time range
SELECT 
    MIN(date) AS first_layoff,
    MAX(date) AS last_layoff,
    DATEDIFF(MAX(date), MIN(date)) AS analysis_period_days
FROM layoffs;

-- Year-over-year trend
-- Check records with missing dates
SELECT 
    COALESCE(YEAR(date), 'Unknown') AS layoff_year,
    SUM(total_laid_off) AS total_layoffs,
    COUNT(DISTINCT company) AS companies_affected,
    ROUND(SUM(total_laid_off) * 100.0 / 
        (SELECT SUM(total_laid_off) FROM layoffs), 2) AS percentage_of_total
FROM layoffs
GROUP BY layoff_year
ORDER BY 
    CASE WHEN layoff_year = 'Unknown' THEN 1 ELSE 0 END,
    total_layoffs DESC;
    
/*------------------------------------------
 4. Time Series & Rolling Calculations
-------------------------------------------*/
-- Monthly trend with rolling totals
WITH MonthlyLayoffs AS (
    SELECT 
        DATE_FORMAT(date, '%Y-%m') AS month_year,
        SUM(total_laid_off) AS monthly_layoffs
    FROM layoffs
    GROUP BY month_year
    HAVING month_year IS NOT NULL
)
SELECT 
    month_year,
    monthly_layoffs,
    SUM(monthly_layoffs) OVER (
        ORDER BY month_year
    ) AS rolling_total,
    AVG(monthly_layoffs) OVER (
        ORDER BY month_year
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS 3_month_avg
FROM MonthlyLayoffs
ORDER BY month_year;

/*------------------------------------------
 5. Company Performance Ranking
-------------------------------------------*/
-- Annual company rankings
WITH CompanyYearlyStats AS (
    SELECT 
        company,
        YEAR(date) AS layoff_year,
        SUM(total_laid_off) AS total_layoffs,
        COUNT(*) AS layoff_events
    FROM layoffs
    GROUP BY company, layoff_year
),
RankedCompanies AS (
    SELECT 
        *,
        DENSE_RANK() OVER (
            PARTITION BY layoff_year 
            ORDER BY total_layoffs DESC
        ) AS company_rank
    FROM CompanyYearlyStats
    WHERE layoff_year IS NOT NULL
)
SELECT 
    layoff_year,
    company,
    total_layoffs,
    layoff_events,
    company_rank
FROM RankedCompanies
WHERE company_rank <= 5
ORDER BY layoff_year DESC, company_rank ASC;

/* Key Features:
   - Shows top 5 companies by layoffs each year
   - Includes multiple layoff event counts
   - Maintains rank consistency with DENSE_RANK()
   - Filters out null dates */
