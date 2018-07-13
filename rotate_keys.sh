#!/bin/bash
# Rotate the secrets
set -ex
. env-kubecon-gh-demo-1-v0.2.sh 

K8S_NAMESPACE=kubeflow

DEPLOYMENT_NAME=${DEPLOYMENT_NAME}-v0-2-1
ADMIN_EMAIL=${DEPLOYMENT_NAME}-admin@${PROJECT}.iam.gserviceaccount.com
USER_EMAIL=${DEPLOYMENT_NAME}-user@${PROJECT}.iam.gserviceaccount.com

SECRETS_DIR=~/secrets

# If you get a PERMISION_DENIED error most likely it means you got the email wrong
gcloud --project=${PROJECT} iam service-accounts keys create ${SECRETS_DIR}/${ADMIN_EMAIL}.json --iam-account ${ADMIN_EMAIL}
gcloud --project=${PROJECT} iam service-accounts keys create ${SECRETS_DIR}/${USER_EMAIL}.json --iam-account ${USER_EMAIL}

kubectl create secret generic --namespace=${K8S_NAMESPACE} admin-gcp-sa --from-file=admin-gcp-sa.json=${SECRETS_DIR}/${ADMIN_EMAIL}.json
kubectl create secret generic --namespace=${K8S_NAMESPACE} user-gcp-sa --from-file=user-gcp-sa.json=${SECRETS_DIR}/${USER_EMAIL}.json
