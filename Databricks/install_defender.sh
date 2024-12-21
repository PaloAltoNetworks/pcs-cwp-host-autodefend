#!/bin/bash
token=$(curl -s -k $PCC_URL/api/v1/authenticate -X POST -H "Content-Type: application/json" -d '{"username":"'"$PCC_USER"'","password":"'"$PCC_PASS"'"}' | grep -Po '"'"token"'"\s*:\s*"\K([^"]*)')
curl -sSL -k --header "authorization: Bearer $token" -X POST $PCC_URL/api/v1/scripts/defender.sh | sudo bash -s -- -c "$PCC_SAN" -m -u --install-host

sed -i '/^PCC_URL/d' /databricks/spark/conf/spark-env.sh
sed -i '/^PCC_USER/d' /databricks/spark/conf/spark-env.sh
sed -i '/^PCC_PASS/d' /databricks/spark/conf/spark-env.sh
sed -i '/^PCC_SAN/d' /databricks/spark/conf/spark-env.sh