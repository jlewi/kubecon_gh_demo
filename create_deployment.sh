#!/bin/bash
# A script to facilitate redeploying Kubeflow using the latest templates.
#

set -ex
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

VERSION=v0.2.1

# Need to strip out the v in the version number
export KUBEFLOW_VERSION=${VERSION//v/}

if [ -z ${VERSION} ]; then
	echo "usage create_deployment.sh <version>"
	exit 1
fi	

VERSION_NAME=${VERSION//./-}

cd ${DIR}

# We need to copy the source to a directory otherwise it will try to check it out via 
# an HTTP link which isn't what we want since we want to try out our source

# Source environment variables containing client id and secret
.  env-kubecon-gh-demo-1-v0.2.sh
DEPLOYMENT_NAME=${DEPLOYMENT_NAME}-${VERSION_NAME}
. ~/secrets/kubecon-gh-demo-oauth.sh

if [ "${VERSION}" == "local" ]; then
	export KUBEFLOW_REPO=~/git_kubeflow
	rm -rf ./scripts
	cp -r ${KUBEFLOW_REPO}/scripts ./scripts
else
	export _KUBEFLOW_REPO=$(mktemp -d /tmp/tmp.kubeflow-${VERSION_NAME}-XXXX)
fi	

export KUBEFLOW_DM_DIR=${DIR}/${DEPLOYMENT_NAME}-dm-configs
export KUBEFLOW_KS_DIR=${DIR}/${DEPLOYMENT_NAME}-app
# Delete existing directories because we want to regenerate the config.
rm -rf ${KUBEFLOW_KS_DIR}
rm -rf ${KUBEFLOW_DM_DIR}

# create_k8s_secrets
# Delete any of the previous service account keys
rm -f *iam.gserviceaccount.com.json

# TODO(jlewi): we can probably set this to true
export SETUP_PROJECT=false

if [ "${VERSION}" == "local" ]; then
	cd ${DIR}/scripts/gke
	./deploy.sh
else
	# TODO(jlewi): Uncomment since this is a hack to try out my changes
	#curl https://raw.githubusercontent.com/kubeflow/kubeflow/${VERSION}/scripts/gke/deploy.sh | bash
	~/git_kubeflow/scripts/gke/deploy.sh
fi

gcloud --project=${PROJECT} container clusters get-credentials --zone=${ZONE} ${DEPLOYMENT_NAME}
~/git_kubeflow-dev/create_context.sh ${DEPLOYMENT_NAME} kubeflow
