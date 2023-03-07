#!/bin/bash
# Setting Variables
Database='dev'
secret='arn:aws:secretsmanager:us-east-1:273940060047:secret:testcluster-9PrWHu'
region='us-east-1'
query='select catid,catname from category'
cluster_identifier='redshift-cluster-1'
sftp_host='192.168.1.13'
sftp_user='tester'
sftp_password='password'
date=$(date +%m-%d-%Y)
# Execute Redshift SQL statement and get statement ID
statementId=$(aws redshift-data execute-statement --region $region --secret $secret --cluster-identifier $cluster_identifier --database $Database --sql "$query"  --query 'Id' --output text)

# Wait for statement execution to complete
while true; do
    status=$(aws redshift-data describe-statement --region $region --id $statementId --output json | jq -r '.Status')
    if [ "$status" == "FINISHED" ]; then
        echo "Statement is finished"
        break
    elif [ "$status" == "FAILED" ]; then
        echo "Statement execution failed"
        exit 1
    fi
    sleep 1
done



#statement result

RESULT=$(aws redshift-data get-statement-result --id $statementId --query 'Records[*]' --output json)


RESULT_ARRAY=$(echo "${RESULT}" | jq -r '.[] | "\(.[0].longValue),\(.[1].stringValue)"' --raw-output |  tr '\n' ' ')

IFS=$' ' read -ra RESULT_PAIRS <<< "${RESULT_ARRAY}"

# Define function to print progress bar
function progress_bar() {
  local progress=$(( $1 * 100 / $2 ))
  local bar_size=$(( $progress / 2 ))
  printf "\r[%-${bar_size}s] %d%%" "${bar// /#}" $progress
}
# Set up variables for progress bar
bar="                                                  "
total=${#RESULT_PAIRS[@]}
count=0

for pair in "${RESULT_PAIRS[@]}"
do
  IFS=',' read -ra VALUES <<< "${pair}"
  trip_id=${VALUES[0]}
  driver_id=${VALUES[1]}
  telematics_url="http://telematics-alb.mentor.internal/api/v4/drivers/${trip_id}/trips/${driver_id}?facet=all"
  #curl $telematics_url
  touch $trip_id.$driver_id
  zip -u $trip_id-$driver_id-$date.zip $trip_id.$driver_id > /dev/null 2>&1
  sshpass -p ${sftp_password} scp -P 2222 -s ${trip_id}-${driver_id}-${date}.zip  ${sftp_user}@${sftp_host}:${trip_id}-${driver_id}-${date}.zip
  rm $trip_id.$driver_id
  rm $trip_id-$driver_id-$date.zip
  count=$(( count + 1 ))
  progress_bar $count $total

done
echo " "
echo -e "Download  \e[0m[\e[32mDone\e[0m]"
echo -e "Zipping   \e[0m[\e[32mDone\e[0m]"
echo -e "Uploading \e[0m[\e[32mDone\e[0m]"
