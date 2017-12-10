# aws
AWS-related scripts

"loaddata_auto.sh"
This script is designed to connect to a redshift database (where VPN is required to access), export some data, then insert that data into a Postgres database which has the same table definition. Note that Postgres on AWS doesn't have the same nifty features as Redshift so you still need to download the file locally, then use \COPY to insert. 

"_loaddata_1.sh" and "_loaddata_2.sh" - THESE ARE DEBUGGING SCRIPTS.
They're really just loaddata_auto.sh chopped up into two, but it helps if let's say the first part of loaddata_auto.sh ran successfully, but the second part failed... you can fix the issue then just run _loaddata_2.sh. 

"location_tags_script"
This script is designed to connect to a redshift database (where VPN is required to access), export some data, loop through the data file and lookup remote IP addresses to a free service to fetch location-based information like Country, State and City, and then create a new file from that.