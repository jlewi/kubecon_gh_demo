#!/bin/bash
#
# Script that defines various environment variables for
# different environment setups.

# Bucket and project must be unique for each project 
# we are setting up to run the demo.
export PROJECT=kubecon-booth
export DEMO_PROJECT=${PROJECT}
export BUCKET=${PROJECT}-gh-demo

# The name of the ip address as defined in cluster.jinja
export IP_NAME=static-ip

# ksonnet environment
export ENV=${PROJECT}
export NAMESPACE=kubeflow
export FQDN=${PROJECT}.kubeflow.dev
