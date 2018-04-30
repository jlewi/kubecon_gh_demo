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

1. copy project_creation/config-kubecon-gh-demo-1.yaml  to `project_creation/config-${PROJECT}.yaml`

	* Modify `config-${PROJECT}.yaml` change the project name

1. Run

```
cd project_creation
gcloud deployment-manager --project=kf-demo-owner deployments create ${PROJECT}--config config-${PROJECT}.yaml
```

Once you create the deployment if you need to make changes you can just update it with

```
gcloud deployment-manager --project=kf-demo-owner deployments update ${PROJECT} --config=config-${PROJECT}.yaml
```


* You might want to update the IAM section in config.yaml to add users who should be owner of the project

1. Copy `env-kubecon-gh-demo-1.sh` to `env-${PROJECT}`.sh

  * Change the name of the project 
  * Set `FQDN` to 

  ```
  FQDN=${PROJECT}.kubeflow.dev
  ```

    * **.dev** not **.org**

1. Update Resource Quotas for the Project

	* Currently this has to be done via the UI
	* Suggested quota usages
	* Recommendations
		* In regions us-east1 & us-central1
		* 100 CPUs per region
		* 200 CPUs (All Region)
		* 100 Tb PDs standard in each region
		* 5 K80s in each region
		* 10 backend services
		* 50 health checks

1. Create a new bucket for this project

  ```
  gsutil mb -p ${PROJECT} gs://${PROJECT}-gh-demo
  ```

  * TODO(jlewi): We should create this with deployment manager.

1. Copy `env-kubecon-gh-demo-1.sh` to `env-${PROJECT}.sh`

  * Set/change all the values to correspond to this new project.

## To Setup the cluster

### Create the Cluster
1. Copy `gke/config-kubecon-gh-demo-1.yaml` to `gke/config-${DEMO_PROJECT}.yaml`

	* Make sure name and zone are set correctly (note `gke-cluster` will be prependend to the name)

1. Create the cluster

```
gcloud deployment-manager --project=${DEMO_PROJECT} deployments create ${DEMO_PROJECT} --config=cluster-${DEMO_PROJECT}.yaml
```

	* DEMO_PROJECT should be the project created in the previous step.

### Setup GPUs

```
kubectl create -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/k8s-1.9/nvidia-driver-installer/cos/daemonset-preloaded.yaml
```

### Setup RBAC

```
gcloud --project=${DEMO_PROJECT} container clusters get-credentials --zone=us-east1-d demo
kubectl create clusterrolebinding cluster-admin-binding-${USER} \
--clusterrole cluster-admin --user $(gcloud config get-value account)
```

### Prepare IAP

1. Follow the instructions [Create oauth client credentials](https://github.com/kubeflow/kubeflow/blob/master/docs/gke/iap.md#create-oauth-client-credentials) to set
  * Only follow the Create oauth client credentials instructions
  * Skip the step to create a static IP

Create the DNS record

```
./create_dns_record.sh
```
  * Make sure you sourced the env-${DEMO_PROJECT}-${CLUSTER}.sh file and set the environment variables.

## Deploying Kubeflow

We use the ksonnet app checked in [here](https://github.com/jlewi/kubecon_gh_demo) in directory `git_examples/github_issue_summarization/ks-kubeflow`

Create an environment for this deployment

```
gcloud --project=${DEMO_PROJECT} container clusters get-credentials --zone=${ZONE} gke-cluster-demo
cd git_examples/github_issue_summarization/ks-kubeflow
ks env add ${DEMO_PROJECT} --namespace=kubeflow
```

Configure the environment

```
ks param set --env=${ENV} iap-ingress ipName static-ip
ks param set --env=${ENV} iap-ingress hostname ${FQDN}
ks param set --env=${ENV} kubeflow-core jupyterHubAuthenticator iap
```

Deploy Kubeflow

```
kubectl create clusterrolebinding cluster-admin-${USER}-kubeflow --clusterrole=cluster-admin --user=${YOUR GOOGLE ACCOUNT}
kubectl create namespace ${NAMESPACE}
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
ks apply ${ENV} -c issue-summarization-model-serving
ks apply ${ENV} -c ui
```

## Access the App

The UI will be availabe at 

```
https://${FQDN}/issue-summarization/
```

## Creating the ksonnet app 

TODO(jlewi): These instructions are probably wrong. We should probably be using the ksonnet app checked into kubeflow-examples.
  * All we should have to do is add an environment.

These instructions only need to be run when creating the ksonnet app which should probably be checked into source control

1. Follow our user guide create an inital app
1. Follow [iap.md](https://github.com/kubeflow/kubeflow/blob/master/docs/gke/iap.md) to create IAP components
	* Skip the step to create a static IP
	

## Precache images

1. Launch the image prepuller

```
ks apply ${ENV} -c prepull-daemon
```

## Prepare the demo

1. Launch a notebook with PVC.

 * Use the image for tf job; you can get the image as follows
 
 ```
 ks param --env=${ENV} list | grep "tfjob.*image.*"
 ```

1. Switch to JupyterLab by changing the suffix of the url from `/tree` to `/lab` e.g.

```
https://kubecon-gh1.kubeflow.org/user/accounts.google.com%3Ajlewi@kubeflow.org/tree? ->
https://kubecon-gh1.kubeflow.org/user/accounts.google.com%3Ajlewi@kubeflow.org/lab?
```
1. Create a terminal in the notebook
1. Confirm that a PD is mounted in /home/joyvan/work

  ```
  df -h
  Filesystem      Size  Used Avail Use% Mounted on
  overlay          95G   13G   82G  14% /
  tmpfs            15G     0   15G   0% /dev
  tmpfs            15G     0   15G   0% /sys/fs/cgroup
  /dev/sda1        95G   13G   82G  14% /etc/hosts
  shm              64M     0   64M   0% /dev/shm
  /dev/sdb        9.8G   37M  9.3G   1% /home/jovyan/work
  tmpfs            15G     0   15G   0% /sys/firmware
  ```

  * Put any work that you want to be saved between container restarts in /home/jovyan/work

1. Due to a bug we need to do the following to make `/home/jovyan/work` writable

   ```
   kubectl exec -it ${JUPYTER_POD} /bin/bash
   chown -R jovyan /home/jovyan/work/
   ```

1. Clone the examples repository into the container

```
git clone https://github.com/jlewi/examples.git /home/jovyan/work/git_examples
cd /hom/jovyan/work/git_examples
git checkout kubecon_demo
```

	* We are cloning [jlewi@'s fork](https://github.com/jlewi/examples/blob/kubecon_demo/github_issue_summarization/notebooks/Training.ipynb) which has some changes to the notebook
	  to support the demo on branch kubecon_demo.

	* If you use this branch you shouldn't have to make the changes listed
	  below to the notebook

1. Open in `/home/jovyan/work/git_examples/github_issue_summarization/notebooks/Training.ipynb`
	* Make sure its a Python3 kernel (look in the upper right corner)

1. Modify the notebook; change DATA_DIR to the following

	```
	%env DATA_DIR=/home/jovyan/work/github-issues-data
	```

	* TODO(jlewi): We should consider checking this into the demo repository.

1. Download the pretrained model; execute the following in a terminal in the notebook

```
mkdir -p /home/jovyan/work/model
gsutil cp -r gs://kubeflow-examples-data/gh_issue_summarization/model/v20180426 /home/jovyan/work/model
```
 
    * This allows us to load the model in the notebook for predictions

 1. Load the trained model

    * Go to the notebook section see Example Results on hold out set
    * Add and execute the following cell

    ```
    from keras.models import load_model
    import dill as dpickle
    body_pp_file = "/home/jovyan/work/model/v20180426/body_pp.dpkl"

    with open(body_pp_file, 'rb') as body_file:
      body_pp = dpickle.load(body_file)
        
    title_pp_file = "/home/jovyan/work/model/v20180426/title_pp.dpkl"
    with open(title_pp_file, 'rb') as title_file:
      title_pp = dpickle.load(title_file)
          
    model_file = "/home/jovyan/work/model/v20180426/seq2seq_model_tutorial.h5"
    seq2seq_Model = load_model(model_file)
    ```

    	* TODO(jlewi): We should probably check this in possibly to the existing notebook

1. Comment out the cell to download the data

	* TODO(jlewi): Maybe add an if statement so we can disable it easily

1. Run all cells

    * It will fail before Train Model because we are missing pydot
    * Scroll down to Train Model and Run all cells below

1. Source the environment variables for your environment

  ```
  source env-${NAME-OF-ENVIRONMENT}.sh
  ```

1. Submit the trainining job.

  
  ```
  cd git_examples/github_issue_summarization/ks-kubeflow
  SUFFIX=$(date +%m%d%H%M)
  T2TOUTPUT=gs://${BUCKET}/gh-t2t-out/${SUFFIX}
  T2TNAME=gh-t2t-trainer-${SUFFIX}
  ks param set --env=${ENV} tensor2tensor name ${T2TNAME}
  ks param set --env=${ENV} tensor2tensor outputGCSPath ${T2TOUTPUT}
  ks apply ${ENV} -c tensor2tensor
  ```  

    * TODO(jlewi): I don't think this actually sets the job name.

1. Setup TensorBoard

  ```
  ks param set --env=${ENV} tensorboard logDir ${T2OUTPUT}
  ks appy ${ENV} -c tensorboard
  ```

  * Check you can access tensorboard at

  ```
  https://${FQDN}/tensorboard/${T2TNAME}/
  ```

  * The trailing slash matters
  * If you get an error **upstream connect failure** try waiting and refreshing.

## Demo Script

1. Start at JupyterHub; spawn a notebook use the image

 ```
 ks param --env=kubecon-gh-demo-1 list | grep "tfjob.\*image"
 ```

 	* TODO(jlewi): Need to add daemonset to precache images so loading it is fast.

 	* Talking points

 		* Jupyter on K8s provides reproducible environments via containers
 		* HTTPS - Can manage security centrally

1. Talk about developing/experimenting in a notebook

   * Use sampled data 
   * Look at output

1. Show define model architecture

1. Generate some predictions

	* Go to section See Example Results on Holdout
	* Load the model (if you haven't already)
	* Execute cells to generate predictions

1. Now train at scale.

```
 ks apply ${ENV} -c tensor2tensor
```

  * TODO(jlewi): Give the job a unique name?

  * Show the pods

  ```
  kubectl get pods -l kubeflow.org=""
  ```

  * You can show logs to show progress

  ```
  kubectl logs pod ${MAST_POD}
  ```

1. Show tensorboard

   * We provide manifests for running tensorboard
   * We've also integrated it with our reverse proxy for Ambassador to make it easy for datascientists to access


1. Show predictions in the notebook

1. Now want a server

   * Show Seldon code 

   ```
    kubectl get seldondeployments -o yaml
   ```

    * Show Seldon 
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
