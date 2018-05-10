#!/bin/bash
#
# Script that defines various environment variables for
# different environment setups.

# Bucket and project must be unique for each project 
# we are setting up to run the demo.
export BUCKET=kubecon-gh-demo
export DEMO_PROJECT=${PROJECT}
export PROJECT=kubecon-gh-demo-1

# The name of the ip address as defined in cluster.jinja
export IP_NAME=static-ip

export IMAGE=gcr.io/kubeflow-examples/tf-job-issue-summarization:v20180428-ff948b2-dirty-3b553c
# ksonnet environment
export ENV=${PROJECT}
export NAMESPACE=kubeflow
# Only project kubecon-gh-demo-1 uses .org every other project
# should use .dev
export FQDN=${PROJECT}.kubeflow.org
