We will use [Google Cloud Deployment Manager](https://cloud.google.com/deployment-manager/docs/configuration/supported-resource-types)

To make it really easy to declaratively define demo infrastructure e.g.

  - Create GCP projects for the demo
  - Configure the project (enable APIs, enable billing etc...)
  - Create GKE clusters


 ## One time setup

In order to use Deployment Manager to create other projects we need to setup a project that will own the deployments.

I created:
  * Folder demo-projects to contain all the projects
  - Project: kf-demo-owner to own the deployments
  - script setup_demo_owner_project.sh to run required commands to setup kf-demo-owner

On the folder containing the project we need to give the service account used by deployment manager (${PROJECT_NUMBER}@cloudservices.gserviceaccount.com) 
permission to create projects

	* TODO(jlewi): Add gcloud command for this.
	* Project number is for the project that owns the deployments (e.g. kf-demo-owner)

## To create a new project

1. Modify project_createion/config.yaml

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

## To Setup the cluster

### Create the Cluster
1. Edit `jinja2/config.yaml`

	* Make sure name and zone are set correctly (note `gke-cluster` will be prependend to the name)

1. Create the cluster

```
gcloud deployment-manager --project=${DEMO_PROJECT} deployments create --config=cluster.yaml
```

	* DEMO_PROJECT should be the project created in the previous step.

### Create Node Pools
Node pools are managed as a separate deployment because the update the update method for nodepools doesn't allow arbitrary fields to be changed so if we want to make changes the way to do this

	* Delete existing deployment
	* Create new deployment with updated configs


```
gcloud deployment-manager --project=kubecon-gh-demo-1 deployments create node-pools --config=node_pools.yaml
```

TODO(jlewi): We should use [dependsOn](https://cloud.google.com/deployment-manager/docs/configuration/create-explicit-dependencies)
to create ordering
   * We'd like to have a single deployment with multiple resources
   
## Troubleshooting

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