-- ################################################
-- ################# Question 2 ###################
-- ################################################

--https://www.mssqltips.com/sqlservertutorial/183/information-schema-columns/
--https://www.w3schools.com/sql/sql_ref_like.asp

SELECT
	table_name,
	column_name,
	column_default,
	is_nullable,
	data_type, 
	character_maximum_length 
FROM 
	INFORMATION_SCHEMA.COLUMNS 
WHERE 
	table_name LIKE 'cprdsyn_%'
ORDER BY
column_name;

----------------------------------------------

SELECT * from cprdsyn_pd WHERE drugsubstancename IS NULL; 
-- No other tables appear to have rectifiable missing values

UPDATE cprdsyn_pd
SET drugsubstancename = 'Alginic acid'
WHERE prodcodeid = 624841000033110;

UPDATE cprdsyn_pd
SET drugsubstancename = 'Paracetamol'
WHERE prodcodeid = 2711441000033111;

------------------------------------------------

SELECT 
	'cprdsyn_patient' AS Name_Of_Table, 
	COUNT(DISTINCT(patsid)) AS No_Of_Unique_Rows,
	COUNT(patsid) AS No_Of_Total_Rows
FROM cprdsyn_patient
UNION ALL
SELECT 
	'cprdsyn_medication' AS Name_Of_Table, 
	COUNT(DISTINCT(patsid)) AS No_Of_Unique_Rows,
	COUNT(patsid) AS No_Of_Total_Rows
FROM cprdsyn_medication
UNION ALL
SELECT 
	'cprdsyn_observation' AS Name_Of_Table, 
	COUNT(DISTINCT(patsid)) AS No_Of_Unique_Rows,
	COUNT(patsid) AS No_Of_Total_Rows
FROM cprdsyn_observation
UNION ALL
SELECT 
	'cprdsyn_gender' AS Name_Of_Table, 
	COUNT(DISTINCT(genderid)) AS No_Of_Unique_Rows,
	COUNT(genderid) AS No_Of_Total_Rows
FROM cprdsyn_gender
UNION ALL
SELECT 
	'cprdsyn_md' AS Name_Of_Table, 
	COUNT(DISTINCT(medcodeid)) AS No_Of_Unique_Rows,
	COUNT(medcodeid) AS No_Of_Total_Rows
FROM cprdsyn_md
UNION ALL
SELECT 
	'cprdsyn_patienttype' AS Name_Of_Table, 
	COUNT(DISTINCT(patienttypeid)) AS No_Of_Unique_Rows,
	COUNT(patienttypeid) AS No_Of_Total_Rows
FROM cprdsyn_patienttype
UNION ALL
SELECT 
	'cprdsyn_pd' AS Name_Of_Table, 
	COUNT(DISTINCT(drugsubstancename)) AS No_Of_Unique_Rows, 
 --Different doses of same drug substance are regarded 
 --as identical for categorisation 
	COUNT(prodcodeid) AS No_Of_Total_Rows
FROM cprdsyn_pd
UNION ALL
SELECT 
	'cprdsyn_practice' AS Name_Of_Table, 
	COUNT(DISTINCT(pracid)) AS No_Of_Unique_Rows,
	COUNT(pracid) AS pracid 
FROM cprdsyn_practice
UNION ALL
SELECT 
	'cprdsyn_region' AS Name_Of_Table, 
	COUNT(DISTINCT(regionid)) AS No_Of_Unique_Rows,
	COUNT(regionid) AS No_Of_Total_Rows
FROM cprdsyn_region

-- ################################################
-- ################# Question 3 ###################
-- ################################################

	SELECT 
	--  Patient data	
	
	cprdsyn_patient.patsid::VARCHAR AS Patient_ID, 
	--  Cast to text as Long numbers may result in loss of precision per CPRD guidance.
	
	cprdsyn_gender.genderid::SMALLINT AS Patient_GenderID,
	cprdsyn_gender.description::VARCHAR AS Patient_Gender,	
	
	DATE_PART('year',cprdsyn_patient.regstartdate)::INT AS Patient_Registered_YRs,
	-- Do not need granular date of reg
	
	cprdsyn_patient.dob AS Patient_DateDOB,
	cprdsyn_patient.emis_ddate AS Patient_DateDeath,
	CASE WHEN cprdsyn_patient.emis_ddate IS NULL THEN 
	           (current_date - cprdsyn_patient.dob)/365::SMALLINT
	       ELSE (cprdsyn_patient.emis_ddate - cprdsyn_patient.dob)/365::SMALLINT
	END AS Patient_Age_YRs,	
	--  Calculate age by subtracting current date/Date of death from DOB
	
	cprdsyn_region.regionid::SMALLINT AS Patient_RegionID, 
	cprdsyn_region.description::VARCHAR AS Patient_Region,    
	
	--  Observation data
	
	cprdsyn_observation.obsdate AS Obs_DateDiagnosis,
	cprdsyn_md.medcodeid::BIGINT AS Obs_MedcodeID,
	cprdsyn_md.cleansedreadcode::VARCHAR AS Obs_CleanedReadcode,
	
	--  Medication data
	
	cprdsyn_medication.issuedate AS Medication_DateIssue,
	DATE_PART('year',cprdsyn_medication.issuedate) AS Medication_DateIssue_YRs, 
	
	cprdsyn_medication.prodcodeid::BIGINT AS Medication_ProductCode,	
	CASE WHEN cprdsyn_pd.drugsubstancename IS NULL THEN 
	               cprdsyn_medication.prodcodeid::VARCHAR
	   ELSE cprdsyn_pd.drugsubstancename::VARCHAR 
	END AS Medication_IDorName,
	-- If drug's active substance is null, replace with product code
 
	cprdsyn_medication.quantity::INT AS Medication_Quantity, 
	cprdsyn_medication.duration::INT AS Medication_DurationOfTreatment_Days
	-- Convert days into years to maintain uniformity? Too small
	
	INTO DASC5090
	
	FROM 
	cprdsyn_patient 
	-- Join with Region
	LEFT JOIN cprdsyn_practice ON cprdsyn_patient.pracid = cprdsyn_practice.pracid
	LEFT JOIN cprdsyn_region ON cprdsyn_practice.region = cprdsyn_region.regionid 
	-- Join with gender description
	LEFT JOIN cprdsyn_gender ON cprdsyn_patient.gender = cprdsyn_gender.genderid
	--  Join with patient type description
	-- LEFT JOIN cprdsyn_patienttype ON cprdsyn_patient.patienttypeid = cprdsyn_patienttype.patienttypeid
	--  Join with observation data
	LEFT JOIN cprdsyn_observation ON cprdsyn_patient.patsid = cprdsyn_observation.patsid
	LEFT JOIN cprdsyn_md ON cprdsyn_observation.medcodeid = cprdsyn_md.medcodeid
	--  Join with medication data
	LEFT JOIN cprdsyn_medication ON cprdsyn_patient.patsid = cprdsyn_medication.patsid
	LEFT JOIN cprdsyn_pd ON cprdsyn_medication.prodcodeid = cprdsyn_pd.prodcodeid
	
	WHERE cprdsyn_patient.acceptable = 1 
	-- 37153 rows remain of research quality data
	AND (cprdsyn_observation.obsdate > cprdsyn_patient.dob) 
	-- 37508 rows remain; Pt can not be diagnosed before birth
	AND (cprdsyn_observation.obsdate > cprdsyn_patient.regstartdate) ;
	-- 27074 rows remain; Pt cannot be diagnosed before registration with doctor

------------------------------------------------
 
	SELECT * 
	INTO DASC5091
	FROM(
    	SELECT
        	-- Patient details
        	DISTINCT patient_id::VARCHAR AS patient_id,
        	MIN (patient_gender)::VARCHAR AS patient_gender,
        	-- Distinct(varchar) does not work, but Min(varchar) does? Same value. 
        	MIN (patient_registered_yrs)::INT AS patient_registered_yrs,
        	MIN (patient_datedob) AS patient_datedob,
        	MIN (patient_datedeath) AS patient_datedeath,
        	MIN (patient_age_yrs)::INT AS patient_age_yrs,
        	MIN (patient_region)::VARCHAR AS patient_region,
        	
        	-- Observations
        	MIN (obs_datediagnosis) AS obs_earliestdiagnosis,
        	MAX (obs_datediagnosis) AS obs_latestdiagnosis,	
        	COUNT(obs_medcodeid)::INT AS obs_diagnoses_total,
        	
        	-- Medications
        	MIN (medication_dateissue) AS medication_earliestprescription,
        	MAX (medication_dateissue) AS medication_latestprescription,	
        	SUM(Medication_Durationoftreatment_DAYS)::INT AS medication_duration_total_DAYs,
        	AVG(Medication_Durationoftreatment_DAYS)::INT AS medication_duration_average_DAYs,    	
        	COUNT(Medication_Productcode)::INT AS medication_prescriptionstotal,
        	CASE WHEN ((MAX (medication_dateissue)-MIN (medication_dateissue))/365) > 0
        	       THEN COUNT(Medication_Productcode)/
                                    ((MAX (medication_dateissue)-MIN (medication_dateissue))/365)
        	       ELSE 0
                        -- If not forced to 0, it divides by 0.
        	   END AS medication_patientyr,
        	COUNT(DISTINCT Medication_IDorName)::INT AS medication_unique
    	FROM DASC5090
    	GROUP BY patient_id
	)
	WHERE obs_earliestdiagnosis <= medication_earliestprescription
	AND (patient_datedeath IS NULL OR patient_datedeath > obs_latestdiagnosis)
	AND (patient_datedeath IS NULL OR patient_datedeath > medication_latestprescription);

------------------------------------------------

CREATE OR REPLACE FUNCTION Numeric_Summaries(table_name TEXT, column_name TEXT)
RETURNS TABLE (
    Tble_Name TEXT,
    Clumn_Name TEXT,
    Minimum NUMERIC,
    Maximum NUMERIC,
    Mean NUMERIC,
    Stdev NUMERIC,
    Median NUMERIC,
    IQR NUMERIC,
    No_Of_Rows BIGINT,
    No_Of_Unique_Rows BIGINT
   ) AS $$
DECLARE
    SumStats TEXT;
BEGIN
    -- Force cast to numeric to prevent mismatches. 
    SumStats := format(
    'SELECT
        %L AS Tble_Name,
        %L AS Clumn_Name,
        MIN(%I)::NUMERIC AS Minimum,
        MAX(%I)::NUMERIC AS Maximum,
        AVG(%I)::NUMERIC AS Mean,			
        STDDEV_SAMP(%I)::NUMERIC AS Stdev,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY %I)::NUMERIC AS Median,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY %I)::NUMERIC - 
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY %I)::NUMERIC AS IQR,
        COUNT(%I) AS No_Of_Rows,
        COUNT(DISTINCT(%I)) AS No_Of_Unique_Rows
    FROM %I',
        table_name, column_name,column_name,column_name, column_name, column_name, 
		column_name, column_name, column_name,column_name,column_name, table_name
    );

    RETURN QUERY EXECUTE SumStats;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Cat_Summaries(table_name TEXT, column_name TEXT)
RETURNS TABLE (
    Tble_Name TEXT,
    Clumn_Name TEXT,
    No_Of_Rows BIGINT,
    No_Of_Unique_Rows BIGINT
   ) AS $$
DECLARE
    CatStats TEXT;
BEGIN
   CatStats := format(
    'SELECT
        %L AS Tble_Name,
        %L AS Clumn_Name,        
        COUNT(%I) AS No_Of_Rows,
        COUNT(DISTINCT(%I)) AS No_Of_Unique_Rows
    FROM %I',
        table_name, column_name,column_name,column_name, table_name
    );
    RETURN QUERY EXECUTE CatStats;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Date_Summaries(table_name TEXT, column_name TEXT)
RETURNS TABLE (
    Tble_Name TEXT,
    Clumn_Name TEXT,
    Earliest DATE,
    Latest DATE,
	Earliest_Year NUMERIC,
	Latest_Year NUMERIC,
    No_Of_Rows BIGINT,
    No_Of_Unique_Rows BIGINT
   ) AS $$
DECLARE
    DateStats TEXT;
BEGIN
    -- Force cast to numeric to prevent mismatches. 
    DateStats := format(
    'SELECT
        %L AS Tble_Name,
        %L AS Clumn_Name,
        MIN(%I)::DATE AS Earliest,
        MAX(%I)::DATE AS Latest,
		DATE_PART(''year'',MIN(%I))::numeric AS Earliest_Year,
		-- Double quote to escape properly 
		DATE_PART(''year'',MAX(%I))::numeric AS Latest_Year,		
        COUNT(%I) AS No_Of_Rows,
        COUNT(DISTINCT(%I)) AS No_Of_Unique_Rows
    FROM %I',
        table_name, column_name,column_name,column_name, column_name, column_name, 
		column_name, column_name,table_name
    );
	RETURN QUERY EXECUTE DateStats;
END;
$$ LANGUAGE plpgsql;

------------------------------------------------

-- Summaries of numeric columns
SELECT * FROM Numeric_Summaries('dasc5091','patient_registered_yrs')
UNION ALL
SELECT * FROM Numeric_Summaries('dasc5091','patient_age_yrs')
UNION ALL
SELECT * FROM Numeric_Summaries('dasc5091','obs_diagnoses_total')
UNION ALL
SELECT * FROM Numeric_Summaries('dasc5091','medication_duration_total_days')
UNION ALL
SELECT * FROM Numeric_Summaries('dasc5091','medication_duration_average_days')
UNION ALL
SELECT * FROM Numeric_Summaries('dasc5091','medication_prescriptionstotal')
UNION ALL
SELECT * FROM Numeric_Summaries('dasc5091','medication_patientyr')
UNION ALL
SELECT * FROM Numeric_Summaries('dasc5091','medication_unique');

-- Summaries of categorical columns
SELECT * FROM Cat_Summaries('dasc5091', 'patient_id')
UNION ALL
SELECT * FROM Cat_Summaries('dasc5091', 'patient_gender')
UNION ALL
SELECT * FROM Cat_Summaries('dasc5091', 'patient_region');

-- Summaries of Dates
SELECT * FROM Date_Summaries('dasc5091', 'patient_datedob')
UNION ALL
SELECT * FROM Date_Summaries ('dasc5091', 'patient_datedeath') 
UNION ALL
SELECT * FROM Date_Summaries('dasc5091', 'obs_earliestdiagnosis')
UNION ALL
SELECT * FROM Date_Summaries('dasc5091', 'obs_latestdiagnosis')
UNION ALL
SELECT * FROM Date_Summaries('dasc5091', 'medication_earliestprescription')
UNION ALL
SELECT * FROM Date_Summaries('dasc5091', 'medication_latestprescription');

-- ################################################
-- ################# Question 4 ###################
-- ################################################

SELECT 
	DISTINCT obs_medcodeid::varchar,
	cprdsyn_md.term::varchar,
	cprdsyn_md.cleansedreadcode::varchar,
	cprdsyn_md.snomedctconceptid::varchar,
	cprdsyn_md.snomedctdescriptionid::varchar
FROM dasc5090
LEFT JOIN cprdsyn_md ON dasc5090.obs_medcodeid = cprdsyn_md.medcodeid
WHERE 
    dasc5090.patient_id IN (SELECT patient_id FROM dasc5091) 
    -- Apply the exclusion criteria 
    AND obs_medcodeid != 999999999;

-- ################################################
-- ################# Question 5 ###################
-- ################################################

SELECT
	MIN(Yr),
	COUNT(No_patients) AS No_patients,
	MIN(medication_prescriptionstotal)::INT AS medication_prescriptionmin,
	MAX(medication_prescriptionstotal)::INT AS medication_prescriptionmax,
	SUM(medication_prescriptionstotal)::INT AS medication_prescriptiontotal,
	AVG(medication_prescriptionstotal)::INT AS medication_ppyavg,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY medication_prescriptionstotal) AS medication_ppymed
FROM(
	SELECT 
	    MIN(medication_dateissue_Yrs)::INT AS yr,
	    COUNT(DISTINCT patient_id)::INT AS No_patients,
	    COUNT(Medication_Productcode)::INT AS medication_prescriptionstotal
	    FROM DASC5090
		WHERE DASC5090.patient_id IN (SELECT patient_id FROM DASC5091) 
		GROUP BY medication_dateissue_Yrs, patient_id)
GROUP BY yr
ORDER BY yr;
