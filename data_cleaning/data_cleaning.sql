-- Layoffs Data Cleaning Project
-- Description: This script cleans and prepares layoff data for analysis.
-- Steps include handling nulls, standardization, deduplication, and data validation.

-- 1. Create Backup Tables
-- Create two copies of the original data for safety
CREATE TABLE layoffs_1 LIKE layoffs;
INSERT INTO layoffs_1 SELECT * FROM layoffs;

CREATE TABLE layoffs_2 LIKE layoffs;
INSERT INTO layoffs_2 SELECT * FROM layoffs;


-- 2. Initial Data Exploration
SELECT * FROM word_layoffs_project.layoffs LIMIT 10;
DESCRIBE layoffs;


-- 3. Handle Missing Values
-- Replace empty strings with NULL for consistency
UPDATE layoffs 
SET 
    industry = NULLIF(industry, ''),
    total_laid_off = NULLIF(total_laid_off, 0),
    percentage_laid_off = NULLIF(percentage_laid_off, 'NULL');

-- Fill missing industry values using company matches
UPDATE layoffs t1
JOIN layoffs t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
    AND t2.industry IS NOT NULL;


-- 4. Data Standardization
-- Clean whitespace in company names
UPDATE layoffs SET company = TRIM(company);

-- Standardize crypto industry names
UPDATE layoffs
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Clean country names
UPDATE layoffs
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- Convert data types
UPDATE layoffs
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs
    MODIFY COLUMN percentage_laid_off DECIMAL(5,2),
    MODIFY COLUMN `date` DATE,
    MODIFY COLUMN funds_raised_millions DECIMAL(15,2);


-- 5. Remove Duplicates
-- Create temporary table with distinct values
CREATE TABLE layoffs_temp AS
SELECT DISTINCT * FROM layoffs;

-- Replace original table
DROP TABLE layoffs;
ALTER TABLE layoffs_temp RENAME TO layoffs;


-- 6. Data Validation
-- Check for remaining duplicates
SELECT 
    company, location, industry, total_laid_off, 
    percentage_laid_off, `date`, stage, country, 
    funds_raised_millions,
    COUNT(*) AS duplicate_count
FROM layoffs
GROUP BY 
    company, location, industry, total_laid_off, 
    percentage_laid_off, `date`, stage, country, 
    funds_raised_millions
HAVING COUNT(*) > 1;

-- Remove rows missing both layoff metrics
DELETE FROM layoffs
WHERE total_laid_off IS NULL 
    AND percentage_laid_off IS NULL;

-- Add data completeness indicator
ALTER TABLE layoffs
ADD COLUMN data_completeness ENUM('Full', 'Partial') 
    GENERATED ALWAYS AS (
        CASE 
            WHEN total_laid_off IS NOT NULL 
                AND percentage_laid_off IS NOT NULL THEN 'Full'
            ELSE 'Partial'
        END
    );


-- 7. Final Verification
-- Validate cleaned data
SELECT * FROM layoffs LIMIT 10;
DESCRIBE layoffs;

-- Check data completeness distribution
SELECT data_completeness, COUNT(*) 
FROM layoffs 
GROUP BY data_completeness;
