#!/bin/bash
set -e

# The host name for which you want to change the DNS IP address
hostname=home.herlein.com

# The AWS id for the zone containing the record, obtained by logging into aws route53
zoneid=Z1BH53QHTY1W11

# The name server for the zone, can also be obtained from route53
nameserver=ns-448.awsdns-56.com

# Optional -- Uncomment to use the credentials for a named profile
#export AWS_PROFILE=examplecom

# Get your external IP address using opendns service
newip=`dig +short myip.opendns.com @resolver1.opendns.com`
if [[ ! $newip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
then
    echo "Could not get current IP address: $newip"
    exit 1
fi

# Get the IP address record that AWS currently has, using AWS's DNS server
oldip=`dig +short "$hostname" @"$nameserver"`
if [[ ! $oldip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
then
    echo "Could not get old IP address: $oldip"
    exit 1
fi

# Bail if everything is already up to date
if [ "$newip" == "$oldip" ]
then
    echo "up to date - $oldip eq $newip"
    exit 0
fi

# aws route53 client requires the info written to a JSON file
tmp=$(mktemp /tmp/dynamic-dns.XXXXXXXX)
cat > ${tmp} << EOF
{
    "Comment": "Auto updating @ `date`",
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "ResourceRecords":[{ "Value": "$newip" }],
            "Name": "$hostname",
            "Type": "A",
            "TTL": 300
        }
    }]
}
EOF

echo "Changing IP address of $hostname from $oldip to $newip"
aws route53 change-resource-record-sets --hosted-zone-id $zoneid --change-batch "file://$tmp"

rm "$tmp"
