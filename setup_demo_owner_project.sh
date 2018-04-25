#!/bin/bash

# Setup the project kf-demo-owner project.
# This is one time setup. This project will be used to own the Google cloud deployment management
# see https://github.com/GoogleCloudPlatform/deploymentmanager-samples/tree/master/examples/v2/project_creation
#
# Usage set the environment variable BILLING_ACCOUNT to the id of the billing account to use
set -ex
PROJECT=kf-demo-owner
PROJECT_NUM=$(gcloud projects describe ${PROJECT} --format='value(project_number)')

gcloud beta billing projects  link ${PROJECT} \
      --billing-account ${BILLING_ACCOUNT}

gcloud services --project=${PROJECT} enable deploymentmanager.googleapis.com
gcloud services --project=${PROJECT} enable cloudresourcemanager.googleapis.com
gcloud services --project=${PROJECT} enable cloudbilling.googleapis.com
gcloud services --project=${PROJECT} enable iam.googleapis.com
gcloud services --project=${PROJECT} enable servicemanagement.googleapis.com

# TODO(jlewi) give ${PROJECT_NUM}@cloudservices.gserviceaccount.com
# Permission on the folder containing the demo projects so that account can create projects.