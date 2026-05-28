-- Set defaults
USE WAREHOUSE COMPUTE_WH;
USE DATABASE MEDICAL;

CREATE SCHEMA IF NOT EXISTS RAW;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE raw_doctors (
    doctor_id INT,
    doctor_name VARCHAR,
    specialty VARCHAR,
    updated_at TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE raw_patients (
    patient_id INT,
    first_name VARCHAR,
    last_name VARCHAR,
    insurance_provider VARCHAR,
    city VARCHAR,
    updated_at TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE raw_visits (
    visit_id INT,
    patient_id INT,
    doctor_id INT,
    visit_date TIMESTAMP_NTZ,
    diagnosis_code VARCHAR,
    billed_amount NUMBER(10, 2)
);

CREATE OR REPLACE STORAGE INTEGRATION gcs_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'GCS'
  ENABLED = TRUE
  STORAGE_ALLOWED_LOCATIONS = ('gcs://snowflake_cicd')
  -- STORAGE_BLOCKED_LOCATIONS = ('gcs://<your-bucket-name>/<sensitive-path>/') -- Optional
  ;

DESCRIBE STORAGE INTEGRATION gcs_int;

CREATE OR REPLACE STAGE medical_stage
URL='gcs://snowflake_cicd/'
STORAGE_INTEGRATION = gcs_int;

-- Example for loading the doctors table from an internal stage:
COPY INTO raw_doctors
FROM @medical_stage/raw_doctors/raw_doctors.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);

COPY INTO raw_patients
FROM @medical_stage/raw_patients_initial/raw_patients_initial.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);

COPY INTO raw_visits
FROM @medical_stage/raw_visits_initial/raw_visits_initial.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);


SELECT * FROM MEDICAL.raw.raw_doctors;

SELECT * FROM MEDICAL.raw.raw_patients;

SELECT * FROM MEDICAL.raw.raw_visits;

