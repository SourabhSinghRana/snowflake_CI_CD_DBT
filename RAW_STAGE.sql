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






USE WAREHOUSE COMPUTE_WH;
USE DATABASE MEDICAL;

CREATE SCHEMA IF NOT EXISTS AUDIT;
USE SCHEMA AUDIT;

CREATE OR REPLACE TABLE MEDICAL.AUDIT.DEPLOYMENT_HISTORY_GITHUB_ACTION (
    GH_RUN_ID            VARCHAR(50) PRIMARY KEY, -- The deterministic join key
    DEPLOYMENT_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    BRANCH_NAME          VARCHAR(100),
    WORKFLOW_NAME        VARCHAR(100),
    COMMIT_SHA           VARCHAR(40),
    DEPLOYMENT_STATUS    VARCHAR(25),
    TRIGGERED_BY         VARCHAR(100),
    TRIGGER_EVENT        VARCHAR(50),
    ERROR_MESSAGE        VARCHAR(1000)
);

CREATE OR REPLACE TABLE MEDICAL.AUDIT.DEPLOYMENT_HISTORY_DBT_MODEL (
    MODEL_EXECUTION_ID   INT IDENTITY(1,1) PRIMARY KEY,
    GH_RUN_ID            VARCHAR(50),             -- The foreign key to join on
    DBT_MODEL_NAME       VARCHAR(255),
    QUERY_START_TIME     VARCHAR(50),
    QUERY_END_TIME       VARCHAR(50),
    DEPLOYMENT_STATUS    VARCHAR(25)
);