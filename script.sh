#!/bin/bash

# Execute Redshift SQL statement and get statement ID
statementId=$(aws redshift-data execute-statement --region us-east-1 --secret arn:aws:secretsmanager:us-east-1:273940060047:secret:testcluster-9PrWHu --cluster-identifier redshift-cluster-1 --database dev --sql "select catid,catname from category"  --query 'Id' --output text)

# Wait for statement execution to complete
while true; do
    status=$(aws redshift-data describe-statement --region us-east-1 --id $statementId --output json | jq -r '.Status')
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

for pair in "${RESULT_PAIRS[@]}"
do
  IFS=',' read -ra VALUES <<< "${pair}"
  trip_id=${VALUES[0]}
  driver_id=${VALUES[1]}
  telematics_url="http://telematics-alb.mentor.internal/api/v4/drivers/${trip_id}/trips/${driver_id}?facet=all"
  echo "downloading file for user trip : ${trip_id} and driver : ${driver_id}"
  touch  $trip_id.$driver_id
  echo "ziping file ..."
  zip -u $trip_id-$driver_id.zip $trip_id.$driver_id
  echo "zip done" 
done
