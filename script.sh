#!/bin/bash

# Execute Redshift SQL statement and get statement ID
statementId=$(aws redshift-data execute-statement --region us-east-1 --secret arn:aws:secretsmanager:us-east-1:273940060047:secret:testcluster-9PrWHu --cluster-identi>
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

echo "getting results"

#statement result
RESULT=$(aws redshift-data get-statement-result --id $statementId --query 'Records[*]' --output json)
echo "Result: ${RESULT}"

RESULT_ARRAY=$(echo "${RESULT}" | jq -r '.[] | "\(.[0].longValue),\(.[1].stringValue)"' --raw-output)
echo "Result Array: ${RESULT_ARRAY}"

IFS=$'\n' read -ra RESULT_PAIRS <<< "${RESULT_ARRAY}"
echo "Start looping"

for pair in "${RESULT_PAIRS[@]}"
do
  IFS=',' read -ra VALUES <<< "${pair}"
  longValue=${VALUES[0]}
  stringValue=${VALUES[1]}
  echo "LongValue: ${longValue}, StringValue: ${stringValue}"
done
