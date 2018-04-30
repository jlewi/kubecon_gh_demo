#!/bin/bash
# Script to create a DNS record.
# Assumes relevant variables have been set in the environment by sourcing an env-....sh script
set -ex
IP_ADDRESS=$(gcloud  --project=${DEMO_PROJECT} compute addresses describe --global ${IP_NAME} --format=json  | jq -r .address)
gcloud --project=kubeflow-dns dns record-sets transaction start -z=kubeflowdev
gcloud --project=kubeflow-dns dns record-sets transaction add -z=kubeflowdev \
    --name="${FQDN}." \
   --type=A \
   --ttl=300 "${IP_ADDRESS}"
gcloud --project=kubeflow-dns dns record-sets transaction execute -z=kubeflowdev 