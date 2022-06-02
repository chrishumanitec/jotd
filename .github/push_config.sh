#!/bin/bash

set -e

HUMANITEC_ORG=product-demo-01
HUMANITEC_APP=of-the-day
IMAGE_NAME="registry.humanitec.io/product-demo-01/jotd:${GITHUB_SHA}"

echo Fetching yq
wget -q https://github.com/mikefarah/yq/releases/download/v4.25.2/yq_linux_amd64 -O yq

chmod u+x yq

# Convert humanitec.yaml into a delta
DELTA="$(./yq e -o json ' .workload.spec.containers.main.image="'${IMAGE_NAME}'" |
.workload.spec.containers.main.id="jotd" | 
{
    "modules":{
        "add": ([{
            "key": .id,
            "value": .workload
        }]|from_entries)
    }
}' ${GITHUB_WORKSPACE}/humanitec.yaml)"

curl https://api.humanitec.io/orgs/${HUMANITEC_ORG}/apps/${HUMANITEC_APP}/deltas \
  -H "Authorization: Bearer $HUMANITEC_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "${DELTA}" -o tmp_delta_id.json -v

DELTA_ID="$(cat tmp_delta_id.json | jq -r)"


curl https://api.humanitec.io/orgs/${HUMANITEC_ORG}/apps/${HUMANITEC_APP}/envs/development/deploys \
  -H "Authorization: Bearer $HUMANITEC_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{
      "delta_id": "'${DELTA_ID}'",
      "comment": "Automated deployment of '${IMAGE_NAME}'"
  }'

