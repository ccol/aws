#This script is the first half of the main loaddata_auto.sh, and is typically used for debugging purposes. It does the following:
#Step 0. Prep the variables
#Step 1. Connects to a redshift db
#Step 2. Executes an UNLOAD which puts the export file into an S3 bucket
#Step 3. Downloads the export file to the local directory where the script is being run from
#Step 4. Manipulates the file to clean it up a little, getting it ready for the \COPY command (which is done in the second half: _loaddata_2.sh)

#NOTE: Text in {{double curly brackets}} is to be replaced with your details

#BEGIN
#Step 0: prepare the varaibles to be used throughout this script. 
#This sets MONDAYTHISWEEK to the datetime of the most recent Monday that just passed, and does so in YYYY-MM-DD 00:00:00 format. This var will be the enddate parameter in the UNLOAD query below
MONDAYTHISWEEK=$(date -vmonday +"%Y-%m-%d 00:00:00")
#This sets MONDAYLASTWEEK to the datetime of the Monday BEFORE the most recent Monday that just passed, and does so in YYYY-MM-DD 00:00:00 format. This var will be the startdate parameter in the UNLOAD query below
MONDAYLASTWEEK=$(date -vmonday -v-7d +"%Y-%m-%d 00:00:00")
#This sets MONDAYTHISWEEK_DATEONLY to the date only of the most recent Monday that just passed, and does so in YYYY-MM-DD format. This is then used in file naming throughout the script (don't need the time component in file names!)
MONDAYTHISWEEK_DATEONLY=$(date -vmonday +"%Y-%m-%d")
echo "_1 script started at: $(date)"


#Step 1 - connect to Amazon redshift database
#This isn't the ideal way of connecting, TODO: use .pgpass
export PGHOST={{REDSHIFT HOST NAME GOES HERE, E.G. something.redshift.amazonaws.com}}
export PGPORT={{PORT GOES HERE, TYPICALLY 5439}}
export PGDATABASE={{DB_NAME}}
export PGUSER={{USERNAME}}
export PGPASSWORD={{PASSWORD}}

#Step 2 - execute the UNLOAD command 
RUN_PSQL="psql -X --set AUTOCOMMIT=off --set ON_ERROR_STOP=on "
${RUN_PSQL} <<SQL
UNLOAD ('select {{FIELDS}} from {{TABLE}} where {{DATEFIELD}} >= ''$MONDAYLASTWEEK'' and {{DATEFIELD}} < ''$MONDAYTHISWEEK''') TO 's3://{{YOUR S3 BUCKET DIRECTORY}}/{{EXPORT_FILE_NAME}}_$MONDAYTHISWEEK_DATEONLY.csv' CREDENTIALS 'aws_access_key_id={{YOUR_ACCESS_KEY}};aws_secret_access_key={{YOUR_SECRET}}' delimiter as ',' escape addquotes parallel off; 
SQL


psql_exit_status=$?
if [ $psql_exit_status != 0 ]; then
    echo "psql failed while trying to run this sql script" 1>&2
    exit $psql_exit_status
fi
echo "1. psql unload finished successfully"


#Step 3 - Download the CSV file - requires aws command line tools: https://aws.amazon.com/cli/
#Note 1- the "csv000" file format is thanks to an UNLOAD thing designed to handle parts
#Note 2 - this downloads the file to wherever this script is running - feel free to change to a different directory
aws s3 cp s3://{{YOUR S3 BUCKET DIRECTORY}}/{{EXPORT_FILE_NAME}}_$MONDAYTHISWEEK_DATEONLY.csv000 {{EXPORT_FILE_NAME}}_$MONDAYTHISWEEK_DATEONLY.csv000

echo "2. aws s3 download finished successfully!"

#Step 4 - clean up the files
#I've seen the COPY part of the script fail because of a stupid backslash in the data. Need to 'sed' but want to keep file naming structure, so replacing backslashes with nothing, BEFORE the null's thing below, to use an intermediate file name
sed 's/\\//g' < {{EXPORT_FILE_NAME}}_$MONDAYTHISWEEK_DATEONLY.csv000 > {{EXPORT_FILE_NAME}}_NOBACKSLASHES_$MONDAYTHISWEEK_DATEONLY.csv000
echo "2a. finished removing any backslashes"

#Replace "" with (null) because the psql \COPY command doesn't like the ""
sed 's/""/(null)/g' < {{EXPORT_FILE_NAME}}_NOBACKSLASHES_$MONDAYTHISWEEK_DATEONLY.csv000 > {{EXPORT_FILE_NAME}}_NULLS_$MONDAYTHISWEEK_DATEONLY.csv000

echo "2b. finished adding (null) to file"
echo "_loaddata_1 script finished at: $(date)"