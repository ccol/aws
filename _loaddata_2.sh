#This script is the second half of the main loaddata_auto.sh, and is typically used for debugging purposes. It does the following:
#Step 0. Prep the variables
#Step 1. Connects to the Postgres db
#Step 2. Executes the \COPY command to load the export file which MUST already exist

#NOTE: Text in {{double curly brackets}} is to be replaced with your details

#BEGIN
#Step 0: prepare the varaibles to be used throughout this script. 
#This sets MONDAYTHISWEEK to the datetime of the most recent Monday that just passed, and does so in YYYY-MM-DD 00:00:00 format. This var will be the enddate parameter in the UNLOAD query below
MONDAYTHISWEEK=$(date -vmonday +"%Y-%m-%d 00:00:00")
#This sets MONDAYLASTWEEK to the datetime of the Monday BEFORE the most recent Monday that just passed, and does so in YYYY-MM-DD 00:00:00 format. This var will be the startdate parameter in the UNLOAD query below
MONDAYLASTWEEK=$(date -vmonday -v-7d +"%Y-%m-%d 00:00:00")
#This sets MONDAYTHISWEEK_DATEONLY to the date only of the most recent Monday that just passed, and does so in YYYY-MM-DD format. This is then used in file naming throughout the script (don't need the time component in file names!)
MONDAYTHISWEEK_DATEONLY=$(date -vmonday +"%Y-%m-%d")
echo "_2 script started at: $(date)"


#Step 1 - Connect to the Postgres db
export PGHOST={{POSTGRES SERVER}}
export PGPORT={{PORT NUMBER}}
export PGDATABASE={{DB_NAME}}
export PGUSER={{USERNAME}}
export PGPASSWORD={{PASSWORD}}

#Step 2 - Execute the \COPY command to insert the data. Remember, this \COPY command assumes that the exact same table definition as what was in Redshift, exists on the target Postgres db
RUN_PSQL="psql -X --set AUTOCOMMIT=off --set ON_ERROR_STOP=on "

${RUN_PSQL} <<SQL
\copy {{TABLE}} from '{{EXPORT_FILE_NAME}}_NULLS_$MONDAYTHISWEEK_DATEONLY.csv000' with DELIMITER ',' NULL AS '(null)' CSV;
commit;
SQL


psql_exit_status=$?
if [ $psql_exit_status != 0 ]; then
    echo "psql to Postgres DB failed while trying to run this sql script" 1>&2
    exit $psql_exit_status
fi
echo "Postgres psql finished successfully"
echo "_loaddata_2 script finished at: $(date)"