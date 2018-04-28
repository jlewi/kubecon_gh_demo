#!/bin/bash
#
# Script that defines various environment variables for
# different environment setups.

# Bucket and project must be unique for each project 
# we are setting up to run the demo.
BUCKET=kubecon-gh-demo
PROJECT=kubecon-gh-demo-1

# ksonnet environment
ENV=${PROJECT}
NAMESPACE=kubeflow

