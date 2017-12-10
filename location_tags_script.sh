currentTime=$(date -vmonday +"%Y-%m-%d %H-%M-%S")
echo "Script started at: $currentTime"

#create VPN connection using osascript
osascript -e "tell application \"Tunnelblick\"" -e "connect \"ol-vpc\"" -e "get state of first configuration where name = \"ol-vpc\"" -e "repeat until result = \"CONNECTED\"" -e "delay 1" -e "get state of first configuration where name = \"ol-vpc\"" -e "end repeat" -e "end tell"

#Step 1 - connect to Amazon redshift database
#This isn't the ideal way of connecting, probably better to use .pgpass somehow
export PGHOST={{REDSHIFT HOST NAME GOES HERE, E.G. something.redshift.amazonaws.comPO}}
export PGPORT={{PORT NUMBER}}
export PGDATABASE={{DB_NAME}}
export PGUSER={{USERNAME}}
export PGPASSWORD={{PASSWORD}}

#Step 2 - execute the UNLOAD command 
RUN_PSQL="psql -X --set AUTOCOMMIT=off --set ON_ERROR_STOP=on "

${RUN_PSQL} <<SQL
UNLOAD ('your_sql_query_here') TO 's3://{{YOUR S3 BUCKET DIRECTORY}}/{{EXPORT_FILE_NAME}}_$currentTime.csv' CREDENTIALS 'aws_access_key_id={{YOUR_ACCESS_KEY}};aws_secret_access_key={{YOUR_SECRET}}' delimiter as ',' escape addquotes parallel off; 
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
aws s3 cp s3://{{YOUR S3 BUCKET DIRECTORY}}/{{EXPORT_FILE_NAME}}_$currentTime.csv000 {{EXPORT_FILE_NAME}}_$currentTime.csv

#Step 4 - loop through the file, lookup the IP address and create a new CSV file with the results
echo "trackingId,country,state,city" > {{NEW_FILE_NAME}}_$currentTime.csv
cat {{EXPORT_FILE_NAME}}_$currentTime.csv | while IFS="," read f1 f2
do
  locationResponse=$(curl -http://freegeoip.net/csv/$f2)
  IFS=","; locationArray=($locationResponse)
  country=${locationArray[2]}
  state=${locationArray[4]}
  city=${locationArray[5]}
  #i know you don't really need variable names here, you could just put the ${locationArray[2]} into the eccho statement, but i like doing this - it's clear to the reader
  echo "$f1,$country,$state,$city"
done >> {{NEW_FILE_NAME}}_$currentTime.csv

#upload the file to another S3 bucket optionally
#aws s3 cp {{NEW_FILE_NAME}}_$currentTime.csv s3://{{new_s3_bucket_location}}/{{NEW_FILE_NAME}}_$currentTime.csv
