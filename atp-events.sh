#!/bin/bash

# Do not include trailing slash for ATPLOGDIR
ATPLOGDIR=/var/log/atp

# check if already running
pidof -o %PPID -x atp-events\.sh >> /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo Found atp script already running at $(pidof -o %PPID -x atp-events.sh)
    exit 1
fi
TOKENEXPIRY=0

apipull() {
    ATPLOGDATE=$(date +'%Y%m%d')
    # Check if token is set to expire within 11 minutes
    if [ "$(date +'%s' --date "+11 minutes")" -ge "$TOKENEXPIRY" ]
        then
            # Get new access token.
            ACCESSTOKENDATA=$(curl -XPOST https://login.windows.net/PRIVATE_TOKEN_DATA/oauth2/token -d 'resource=https%3A%2F%2Fgraph.windows.net&client_id=CLIENT_ID&client_secret=CLIENT_SECRET&grant_type=client_credentials' | jq .access_token,.expires_on)
            ACCESSTOKEN=$(echo $ACCESSTOKENDATA | awk '{print $1}' | sed 's/"//g')
            TOKENEXPIRY=$(echo $ACCESSTOKENDATA | awk '{print $2}' | sed 's/"//g')
        else
            # Don't get a new access token.
            :
    fi
    FIVEMINAGO=$(date -u -Iminutes --date "5 minutes ago" | sed 's/\+.*$/:00.00/g')
    curl -XGET -H "Authorization: Bearer $(echo $ACCESSTOKEN)" "https://wdatp-alertexporter-us.windows.com/api/alerts?limit=100&sinceTimeUtc=$FIVEMINAGO" | jq . >> $ATPLOGDIR/atp-events.$ATPLOGDATE.log
}

atpapi() {
    while true; 
        do sleep 300; 
        if [[ "$(grep -h 'MASTER' /var/run/keepalive.*.*.state | wc -l)" -eq "$(grep vrrp_instance /etc/keepalived/keepalived.conf | grep -v '^#' | wc -l)" ]]
            then
                apipull
            else
                :
        fi
    done
}

atpapi
