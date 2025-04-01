Typical usage:

# index the astronomy database (calls mkcodes)
   ./doindex ast               

# update the astronomy index and capture log output (calls doindex)
   ./doindex-weekly.sh ast

# update all the databases once a week (calls doindex-weekly.sh and mkcodes.sh)
   ./weekly-update.sh
