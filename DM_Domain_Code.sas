Libname oncology "C:\Users\HP\Desktop\My Folder\Project\Oncology Project\crfdata v1";

Libname SDTM "C:\Users\HP\Desktop\My Folder\Project\Oncology Project\SDTM_Oncology_Domains";


Options Validvarname= Upcase;                                                                                                                      

Data SDTM.DM;
 Attrib STUDYID LABEL='Study Identifier' LENGTH=$6
        DOMAIN LABEL='Domain Abbreviation' LENGTH=$2
        USUBJID LABEL='Unique Subject Identifier' LENGTH=$16
        SUBJID LABEL='Subject Identifier for the Study' LENGTH=$9
        BRTHDTC LABEL='Date/Time of Birth' Format= IS8601DT23.
        AGEU LABEL='Age Units' LENGTH=$5
        SEX LABEL='Sex' LENGTH=$1
        RACE LABEL='Race' LENGTH=$5
        ETHNIC LABEL='Ethnicity' LENGTH=$22;
 Set ONCOLOGY.DM;
  STUDYID = 'CMP135';
  DOMAIN = 'DM';
  SUBJID = SUBJECT;
  USUBJID = Studyid||Subjid;
  SITEID = sitenumber ;
  BRTHDTC = BRTHDTN;
  Ageu = 'Year';
  SEX= SEX_COD;
  RACE= race;
  ETHNIC= ETHNIC;
 Keep Studyid Domain Subjid Usubjid Siteid Brthdtc Ageu Sex Race Ethnic ;
Run;

 /* Creating the next variable by merging datasets.
   This step involves merging datasets to extract the necessary values from other datasets. */

/* Sorting the datasets for merging and renaming the subject variable to subjid.
   This step ensures that the datasets are sorted properly before merging,
   and it also renames the subject variable for consistency. */

Proc sort data=SDTM.DM;
  BY SUBJID;
Run;


proc sort data=oncology.EX (Rename = (SUBJECT=SUBJID));
  by  SUBJID  EXSTDTN;
run;


proc sort data=oncology.DS (Rename = (SUBJECT=SUBJID));
  by  SUBJID  ;
run;


proc sort data=oncology.ENR (Rename = (SUBJECT=SUBJID));
  by SUBJID ;
run;


Data  SDTM.DM (drop= EXSTDTN EXDOSE DSSTDAT CNSTDTN  ENRGRP);
 ATTRIB RFSTDTC LaBEL = 'Subject Reference Start Date/Time' Format= IS8601DT23.
        RFENDTC Label = 'Subject Reference End Date/Time'   Format= IS8601DT23.
        RFXSTDTC Label = 'Date/Time of First Study Treatment' Format= IS8601DT23.
        RFXENDTC Label = 'Date/Time of Last Study Treatment' Format= IS8601DT23.
        RFICDTC Label = 'Date/Time of Informed Consent' Format= IS8601DT23.
        RFPENDTC Label = 'Date/Time of End of Participation' Format= IS8601DT23.
        AGE Label = 'Age' length= 8
        ARMCD Label = 'Planned Arm Code' length=$8
        ARM Label = 'Description of Planned Arm'  length=$7
        ACTARMCD Label= 'Actual Arm Code' length=$8
        ACTARM Label= 'Description of Actual Arm' length=$7 ;

/* Retain variables to ensure they carry forward in the merge process */

  Retain RFSTDTC RFXSTDTC RFXENDTC;
  merge SDTM.DM
        Oncology.EX (keep = SUBJID EXSTDTN EXDOSE)
        Oncology.DS (keep= SUBJID DSSTDAT)
        Oncology.ENR (Keep= SUBJID CNSTDTN  ENRGRP) ;
   by SUBJID;
    RFENDTC = DSSTDAT;
    RFICDTC = CNSTDTN;
    RFPENDTC = RFENDTC;
    AGE=int(yrdif(datepart(BRTHDTC),datepart(CNSTDTN),'actual')) ;
    ARM= ENRGRP;
    IF ENRGRP = 'Group 1' then ARMCD = 'CMP135_5' ;

 /* Assign values for RFXSTDTC and RFXENDTC based on conditions */

   If First.SUBJID then RFSTDTC = EXSTDTN ;
   If first.SUbjid AND EXDOSE>0 then RFXSTDTC =EXSTDTN;
   If Last.subJID AND EXDOSE>0 then RFXENDTC =EXSTDTN;
   If last.subjid;
   If SUM(EXDOSE > 0) > 0 THEN do;
        ACTARMCD = 'CMP135_5';
        ACTARM='Group 1' ;

/* Explanation of Summation Logic */
/* The dataset is sorted by subject identifier (subjid), leading to multiple records for a single subjid in the EX dataset.
   This is due to subjects receiving multiple doses. The goal, as per the specification, is to assign values for ACTARMCD and ACTARM.
   According to the specification, if a subject received a drug dose, certain values need to be assigned. To determine if a subject received a dose,
   Utilized a summation approach with a BY group. If the sum of doses (EXDOSE) within a subjid group is greater than 0,
   it indicates the subject received the drug, and the corresponding values are assigned for ACTARMCD and ACTARM. */


   End;
Run;


/* Handling Multiple Records for Single Subjid */
/* The presence of multiple records for a single subjid is due to subjects receiving multiple doses on different dates. */

  /* Data Validation Using PROC SQL */


/*To ensure data integrity and accuracy, a PROC SQL query is used to check if there are any occurrences of AEOUT with the value "Fatal".
   The query also examines unique combinations of COUNTRY and AEOUT in the ONCOLOGY.INV and Oncology.AE datasets to assess the distribution of data
*/


/* This section involves using PROC SQL to perform data validation checks.
   The first query counts the occurrences of AEOUT values that might indicate fatalities ("Fatal" or "fatal" or "FATAL").
   This helps ensure that the specified conditions are met for further processing. */

proc sql;
    /* Counting occurrences of "Fatal" values in AEOUT */
    select count(*)
    from Oncology.AE
    where AEOUT = "Fatal" or AEOUT = "fatal" or AEOUT = "FATAL";
quit;


/* Further Validation of Data Integrity */

/* In this query, DISTINCT combinations of COUNTRY and AEOUT are examined from the ONCOLOGY.INV and Oncology.AE datasets.
   This assessment provides insights into the distribution of data across different countries and AEOUT values. */

PROC SQL;
    /* Selecting distinct combinations of COUNTRY and AEOUT */
    SELECT DISTINCT COUNTRY, AEOUT
    FROM ONCOLOGY.INV, Oncology.AE;
RUN;



/* The results reveal that there are no instances of AEOUT being "Fatal", and the only observed country is the USA.
   This information informs the creation of the COUNTRY and DTHFL variables. */

/* Creating Variables DTHDTC, DTHFL, and COUNTRY */
/* The following data manipulation involves creating or updating variables in the SDTM.DM dataset.
   The variable DTHDTC (Date/Time of Death) is assigned a missing value (.).
   The DTHFL (Subject Death Flag) variable is assigned the value 'N' (no death flag).
   The COUNTRY variable is uniformly assigned the value 'USA' as determined by the earlier analysis. */



Data SDTM.DM;
  Attrib DTHDTC Label = 'Date/Time of Death' format= IS8601DT23.
         DTHFL Label = 'Subject Death Flag' length= $1
         COUNTRY LABEL = 'Country' LENGTH=$3;

  /* Copying existing dataset SDTM.DM */
  SET SDTM.DM;

  /* Assigning values to variables */
  DTHDTC = .;   /* No specific date/time of death available */
  DTHFL = 'N';  /* No death flag */
  COUNTRY = 'USA';  /* All patients belong to the USA */

Run;



 /* Data Preparation and Merge */

 /* In this section, data is being prepared and merged to fulfill a specific requirement from the specification.
   The purpose is to find the Date/Time of Collection (DMDTC) for demographic data by merging DM with DOV on SUBJECT */

 /* Sorting the oncology.dm dataset by subject for future merge */
proc sort data=oncology.dm out=dm_sorted;
    by subject;
run;


 /* Sorting the oncology.dov dataset by subject for future merge */
proc sort data=oncology.dov out=dov_sorted;
    by subject;
run;


 /* Merging the sorted DM and DOV datasets on subject */
Data DM_DOV (rename=(SUBJECT=SUBJID));
    merge dm_sorted dov_sorted;
    by subject;
    /* Selecting only instances where INSTANCENAME is "Screening" */
    if INSTANCENAME = "Screening";
run;



 /* Creating the final SDTM.DM dataset */
Data SDTM.DM (Drop=VISDTN);
    Attrib DMDTC label='Date/Time of Collection' format=IS8601DT23.;
    Set SDTM.DM; /* Starting with the original SDTM.DM dataset */
    Set DM_DOV(Keep=SUBJID VISDTN); /* Merging with the DM_DOV dataset */
    DMDTC = VISDTN; /* Assigning DMDTC as VISDTN value from the DM_DOV dataset */
Run;




/* Setting an option to ensure valid variable names are uppercase */
options validvarname=upcase;

/* Ordering DM domain's variable as per specification by using Retain statement */

Data SDTM.DM;
    /* Retaining variables from the original dataset and setting order */
    Retain STUDYID DOMAIN USUBJID SUBJID RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC RFPENDTC DTHDTC
           DTHFL SITEID BRTHDTC AGE AGEU SEX RACE ETHNIC ARMCD ARM ACTARMCD ACTARM COUNTRY DMDTC;
    set SDTM.DM;
Run;

/* The code retains specified variables from the original SDTM.DM dataset and creates a new dataset named SDTM.DM.
   The option 'validvarname=upcase' ensures that variable names are converted to uppercase, which can be useful for consistency and compatibility. */
