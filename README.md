We will use [Google Cloud Deployment Manager](https://cloud.google.com/deployment-manager/docs/configuration/supported-resource-types)

To make it really easy to declaratively define demo infrastructure e.g.

  - Create GCP projects for the demo
  - Configure the project (enable APIs, enable billing etc...)
  - Create GKE clusters


 ## One time setup

In order to use Deployment Manager to create other projects we need to setup a project that will own the deployments.

I created:
  * In GCP org kubeflow.org I created folder demo-projects to contain all the projects
  - Project: kf-demo-owner to own the deployments
  - script setup_demo_owner_project.sh to run required commands to setup kf-demo-owner

On the folder containing the project we need to give the service account used by deployment manager (${PROJECT_NUMBER}@cloudservices.gserviceaccount.com) 
permission to create projects

	* TODO(jlewi): Add gcloud command for this.
	* Project number is for the project that owns the deployments (e.g. kf-demo-owner)

## To create a new project

1. Modify project_creation/config.yaml

	* Change the project name

1. Run

```
cd project_creation
gcloud deployment-manager --project=kf-demo-owner deployments create ${NAME} --config config.yaml
```

Once you create the deployment if you need to make changes you can just update it with

```
gcloud deployment-manager --project=kf-demo-owner deployments update kubecon-gh-demo-1 --config=config.yaml
```


* You might want to update the IAM section in config.yaml to add users who should be owner of the project

1. Update Resource Quotas for the Project

	* Currently this has to be done via the UI
	* Suggested quota usages
	* Recommendations
		* In regions us-east1 & us-central1
		* 100 CPUs per region
		* 200 CPUs (All Region)
		* 100 Tb PDs in each region
		* 10 K80s in each region
		* 10 backend services
		* 10 health checks

## To Setup the cluster

### Create the Cluster
1. Edit `jinja2/config.yaml`

	* Make sure name and zone are set correctly (note `gke-cluster` will be prependend to the name)

1. Create the cluster

```
gcloud deployment-manager --project=${DEMO_PROJECT} deployments create --config=cluster.yaml
```

	* DEMO_PROJECT should be the project created in the previous step.

### Updating Node Pools
Because the the update method for nodepools doesn't allow arbitrary fields to be changed so if we want to make changes the way to do this

	* Delete existing deployment
	* Create new deployment with updated configs


### Setup GPUs

```
kubectl create -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/k8s-1.9/nvidia-driver-installer/cos/daemonset-preloaded.yaml
```

### Setup RBAC
kubectl create clusterrolebinding cluster-admin-binding \
--clusterrole cluster-admin --user $(gcloud config get-value account)

## Deploying Kubeflow

We use the ksonnet app checked in [here](https://github.com/kubeflow/examples/tree/master/github_issue_summarization/ks-kubeflow)

Create an environment for this deployment

```
gcloud --project=${DEMO_PROJECT} container clusters get-credentials --zone=${ZONE} gke-cluster-demo
cd git_examples/github_issue_summarization/ks-kubeflow
ks env add demo --namespace=kubeflow
```

Configure the environment

```
ks param set --env=${ENV} iap-ingress ipName static-ip
ks param set --env=${ENV} iap-ingress hostname ${FQDN}
ks param set --env=${ENV} kubeflow-core jupyterHubAuthenticator iap
```

Use your domain registrar to register the FQDN

   * TODO(jlewi): Can we use CLOUD DNS to register a domain like kubeflow-demos? How would we register DNS names for IPs in a different
     project?

Deploy Kubeflow

```
kubectl create clusterrolebinding cluster-admin-${USER}-kubeflow --clusterrole=cluster-admin --user=${YOUR GOOGLE ACCOUNT}
kubectl create namespace kubeflow
ks apply ${ENV} -c kubeflow-core
ks apply ${ENV} -c cert-manager
ks apply ${ENV} -c iap-ingress
``````

## Deploying the GH demo

Create a GitHub token

```
kubectl -n kubeflow create secret generic github-token --from-literal=github-oauth=${GITHUB_TOKEN}
```

```
ks apply ${ENV} -c seldon
ks apply ${ENV} -c issue-summarization
ks apply ${ENV} -c ui
```

## Access the App

The UI will be availabe at 

```
https://${FQDN}/issue-summarization/
```

## Creating the ksonnet app 

These instructions only need to be run when creating the ksonnet app which should probably be checked into source control

1. Follow our user guide create an inital app
1. Follow [iap.md](https://github.com/kubeflow/kubeflow/blob/master/docs/gke/iap.md) to create IAP components
	* Skip the step to create a static IP
	
## Troubleshooting

### Deployment Manager

```
ERROR: (gcloud.deployment-manager.deployments.update) Error in Operation [operation-1524679659292-56ab0257d0560-60fae1f4-f22ce361]: errors:
- code: RESOURCE_ERROR
  location: /deployments/kubecon-gh-demo-1/resources/kubecon-gh-demo-1
  message: '{"ResourceType":"cloudresourcemanager.v1.project","ResourceErrorCode":"403","ResourceErrorMessage":{"code":403,"message":"User
    is not authorized.","status":"PERMISSION_DENIED","statusMessage":"Forbidden","requestPath":"https://cloudresourcemanager.googleapis.com/v1/projects","httpMethod":"POST"}}'

```

	* This error indicates the service account used by deployment manager doesn't have permission to create projects


```
ERROR: (gcloud.deployment-manager.deployments.update) Error in Operation [operation-1524681274999-56ab085cac0d9-9b39ef39-a5f3583b]: errors:
- code: RESOURCE_ERROR
  location: /deployments/kubecon-gh-demo-1/resources/patch-iam-policy-kubecon-gh-demo-1
  message: '{"ResourceType":"gcp-types/cloudresourcemanager-v1:cloudresourcemanager.projects.setIamPolicy","ResourceErrorCode":"400","ResourceErrorMessage":{"code":400,"message":"Request
    contains an invalid argument.","status":"INVALID_ARGUMENT","details":[{"@type":"type.googleapis.com/google.cloudresourcemanager.v1.ProjectIamPolicyError","type":"ORG_MUST_INVITE_EXTERNAL_OWNERS","member":"user:vishnuk@google.com","role":"roles/owner"},{"@type":"type.googleapis.com/google.cloudresourcemanager.v1.ProjectIamPolicyError","type":"ORG_MUST_INVITE_EXTERNAL_OWNERS","member":"user:aronchick@google.com","role":"roles/owner"},{"@type":"type.googleapis.com/google.cloudresourcemanager.v1.ProjectIamPolicyError","member":"group:google-team@
    kubeflow.org"}],"statusMessage":"Bad Request","requestPath":"https://cloudresourcemanager.googleapis.com/v1/projects/kubecon-gh-demo-1:setIamPolicy","httpMethod":"POST"}}'
```
	* You can work around this by creating a group within the org and then adding external members to the group.

### Seldon Server

* If model server is crash looping; try deleting the pod.
