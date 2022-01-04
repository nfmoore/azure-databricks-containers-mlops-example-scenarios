# Implementation Guide

## Prerequisites

- Azure subscription (contributor or owner)
- GitHub account

## 1. Infrastructure Setup

### 1.1. Create repository

Log in to your GitHub account, navigate to the [databricks-kubernetes-real-time-mlflow-model-deployment-poc](https://github.com/nfmoore/databricks-kubernetes-real-time-mlflow-model-deployment-poc) repository and click `use this template` to create a new repository from this template. Rename the template and leave it public. Use [these](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/creating-a-repository-from-a-template) instructions for more details about creating a repository from a template.

### 1.2. Deploy resources

The Azure resources required to implement this proof-of-concept include an [Azure Databricks](https://docs.microsoft.com/en-us/azure/databricks/scenarios/what-is-azure-databricks) workspace, an [Azure Log Analytics](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/data-platform-logs) workspace, an [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-intro) (ACR), and 2 [Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/intro-kubernetes) (AKS) instances (for a staging and production environment respectively). These can be deployed via the following [ARM templates](https://github.com/nfmoore/azure-infrastructure-templates):

- [**Template one:** Databricks workspace]( https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fnfmoore%2Fazure-infrastructure-templates%2Fmain%2Ftemplates%2Fdata-databricks-workspace%2Fmain.json)

- [**Template two:** Kubernetes with ACR and a Log Analytics workspace]( https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fnfmoore%2Fazure-infrastructure-templates%2Fmain%2Ftemplates%2Fapps-microservices%2Fmain.json)

When deploying these templates the same resource group can be used for this proof-of-concept. You can create this as part of the custom deployment. Deploy template one once, and template two twice. Template one can be deployed using default values and template two can be deployed using default values for the first deployment only. For the second deployment of template two, you need to reference the ACR and a Log Analytics workspace from the first deployment of template two. To do this you will need to change the following parameters (shown in the image below):

- `Resource Instance`: change to a value other than the value used in template one.

- `Container Registry Name`: change to the name of the Container Registry service deployed during the first deployment of template two.

- `Log Analytics Workspace Name`: change to the name of the Log Analytics workspace deployed during the first deployment of template two.

![1-1](.github/../images/implementation/1-1.png)

### 1.3. Configure resources

After the resources have been successfully deployed some services need to be configured before you can train, register, deploy and monitor the machine learning models.

#### Log Analytics Workspace

For the Log Analytics workspace, Azure Monitor for Containers needs to be enabled. To enable this, click on an AKS cluster deployed as part of 1.2 above, click on the Logs tab in the monitoring section, then select your Log Analytics workspace and click enable. This process is shown in the image below. Ensure to repeat this process for the second AKS cluster in your resource group.

![1-2](.github/../images/implementation/1-2.png)

#### Azure Databricks

For Azure Databricks you need to enable the [Files in Repo](https://docs.microsoft.com/en-us/azure/databricks/repos#enable-support-for-arbitrary-files-in-databricks-repos) feature (which is not enabled by default at the time of developing this proof-of-concept), generate a new [Databricks Access Token](https://docs.microsoft.com/en-au/azure/databricks/dev-tools/api/latest/authentication), and create a [cluster with custom libraries](https://docs.microsoft.com/en-au/azure/databricks/libraries/cluster-libraries).

On the sidebar hover over `Settings` and click `Admin Console`. From the `Admin Console` select `Workspace Settings` from the menu. Scroll down until the `Repos` section and click the toggle next to the `Files in Repos` item to enable the feature.

![1-3](.github/../images/implementation/1-3.png)

Next, from the sidebar hover over `Settings` and click `User Settings`. From `User Settings`, under the `Access Tokens` menu, click the `Generate New Token` button. Enter a name for the token and click the `Generate` button. Make sure you copy the token value (you need to use it in `1.5`). You won't be able to see this value again.

![1-4](.github/../images/implementation/1-4.png)

Add the Git repository (with the required artifacts) you created in step 1.1 by selecting the `Repos` section from the sidebar and clicking the `Add Repo` button in the flyout menu. Copy the URL of your Git repository in the `Git repo URL` field.

![1-5](.github/../images/implementation/1-5.png)

Next, you will need to create a cluster and install libraries that are not part of the default Databricks Runtimes. Select `Compute` from the sidebar and click the `Create Cluster` button. From the options:

- `Cluster Name`: enter a name for your cluster.

- `Cluster Mode`: select the `Single Node` option to reduce costs when executing this proof-of-concept.

- `Databricks Runtime Version`: select `Runtime: 10.1 ML` from the dropdown.

Click the `Create Cluster` button to create the cluster.

![1-6](.github/../images/implementation/1-6.png)

Once the cluster has been created select the cluster from the table on the `Compute` section and navigate to the `Libraries` section shown on the menu. Click the `Install Now` button, select `PyPI` as the library source and enter `alibi-detect` as the `Package` and click `Install`. Repeat this process for the `alibi` package.

[Alibi Detect](https://github.com/SeldonIO/alibi-detect) is an open source Python library focused on outlier, adversarial and drift detection. In this proof-of-concept detectors from this package will be used to monitor for outliers and data drift.

![1-7](.github/../images/implementation/1-7.png)

### 1.4. Configure GitHub environments

For this proof-of-concept, one Kubernetes cluster will be used as part of a staging environment and the second will be used as part of a production environment. To enable these different deployment targets with custom secrets and protection rules [GitHub environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) will be used.

To set up these environments, from your GitHub repository you created in `1.1` click the `Settings` tab in the menu bar. On the new page than select `Environments` from the side bar. Click the `New Environment` button and create an environment with the `Name` of `Staging` and click the `Configure Environment` button. Click the `Add Secret` button and create the following secrets with values from your deployments from `1.2`.

| Secret name | How to find secret value |
|:------------|:-------------------------|
| KUBERNETES_NAME | This can be found on the Azure portal. It will be the AKS cluster from the first deployment of template two. |
| KUBERNETES_RESOURCE_GROUP | This can be found on the Azure portal. It will be the resource group into which the AKS service has been deployed. |

![1-8](.github/../images/implementation/1-8.png)

Like above, create a second environment called `Production` with the same secrets from above. Make sure you replace the secret values to correspond to the AKS cluster and corresponding resource group from the second deployment of template two.

After creating these secrets for the production environment, you can enable `Required Viewers` before deploying to this environment. This will allow you to specify people or teams that may approve workflow runs when they access this environment. To enable `Required Viewers`, under the `Environment Protection Rules` section, click the checkbox next to `Required Viewers` and search for your GitHub username and select it from the dropdown and click the `Save Protection Rules` button.

![1-9](.github/../images/implementation/1-9.png)

### 1.5. Configure GitHub secrets

Next, you will configure GitHub Action secrets. These are encrypted environment variables used within GitHub Actions Workflows. Click the `Settings` tab in the menu bar of your GitHub repository and on the new page then select `Secrets` from the sidebar. Click the `New Repository Secret` button to create a new secret and then the `Add Secret` button to create the secret.

You need to create the following secrets:

| Secret name | How to find secret value |
|:------------|:-------------------------|
| AZURE_CREDENTIALS | A JSON object with details of your Azure Service Principal. [This](https://github.com/marketplace/actions/azure-login#configure-deployment-credentials) document will help you configure a service principal with a secret. The value will look something like: ` {  "clientId": "<GUID>", "clientSecret": "<GUID>", "subscriptionId": "<GUID>", "tenantId": "<GUID>", ... }`|
| DATABRICKS_HOST | This is the `instance name` or `per-workspace URL` of your Azure Databricks service. Its value can be found from the Databricks service page on the Azure Portal under the `URL` parameter.  For more information [this]( https://docs.microsoft.com/en-us/azure/databricks/workspace/workspace-details#per-workspace-url) resource can be used. The value will look something like ` https://adb-5555555555555555.19.azuredatabricks.net`|
| DATABRICKS_TOKEN | This is the value of the `Access Token` you created in `1.3`. The value should look something like `dapi55555555555555555555555555555555-2`. |
| CONTAINER_REGISTRY_NAME | The name of the ACR service deployed in template two. |
| CONTAINER_REGISTRY_PASSWORD | This can be found in the access keys section of the ACR service page. The Admin Account section of [this]( https://docs.microsoft.com/en-us/azure/container-registry/container-registry-authentication?tabs=azure-cli#admin-account) document contains more information. |
| CONTAINER_REGISTRY_IMAGE_PULL_SECRET | A image pull secret you create. |

![1-10](.github/../images/implementation/1-10.png)

## 2. Model Development

The model development process has been encapsulated in a single notebook called `train_register_model`. This notebook aims to train and register necessary MLFlow models to be deployed as part of this solution. This notebook will create:

- a model used to make predictions from inference data.

- a model used to detect outliers for monitoring purposes.

- a model used to detect data drift for monitoring purposes.

In practice, the model development process requires more effort than illustrated in this notebook. This notebook does incorporate experiment tracking and model registration and versioning which are critical elements of well-developed ML Ops processes.

This notebook has been adapted from a tutorial notebook in the Databricks documentation available [here](https://docs.databricks.com/applications/mlflow/end-to-end-example.html). The machine learning model in this notebook (called `wine_quality`) will predict the quality of Portuguese "Vinho Verde" wine based on the wine's physicochemical properties. The dataset is available from the UCI Machine Learning Repository available [here](https://archive.ics.uci.edu/ml/machine-learning-databases/wine-quality/).

### 2.1. Train models

To execute the notebook to develop the models required by the machine learning service select the `Repos` section from the sidebar and navigate to `notebooks/train_register_model` (click the file to open it).

![2-1](.github/../images/implementation/2-1.png)

When the notebook is open click the `Run All` button to execute the notebook. If prompted to select a cluster, select the cluster you created in `1.3`.

Once the notebook has been successfully executed, navigate to the `Models` section from the sidebar. Ensure you have set the `Machine Learning` persona for your Databricks workspace. This option is available from the sidebar as the first option.

On the registered models page you should see 3 models:

- `wine_quality`: a model used to make predictions from inference data.

- `wine_quality_outliers`: a model used to detect outliers for monitoring purposes.

- `wine_quality_drift`: a model used to detect data drift for monitoring purposes.

![2-2](.github/../images/implementation/2-2.png)

### 2.2. Commit model configuration

After developing these models, a JSON configuration file is used to define which model and version from the [ML Flow model registry](https://docs.microsoft.com/en-us/azure/databricks/applications/machine-learning/manage-model-lifecycle/) should be deployed as part of the API. All three models and their respective versions will be used within the API.

Once a new model version has been developed edit the `service/configuration.json` file to specify the model’s name and version to deploy. If you have changed the model names or versions edit this file. If you have retained the defaults leave you can leave this file unedited.

![2-3](.github/../images/implementation/2-3.png)

After editing the `service/configuration.json` file commit your changes to the GitHub Repo. This will trigger the CI/CD pipeline implemented using GitHub Actions. To make a commit (assuming you have changed this file) select `Repos` from the sidebar click the branch next to the repo name in the flyout menu. This will open a window that shows the changes you have made. If you have made changes add a summary in the `Summary` text field and an optional description then click the `Commit and Push`  button to commit the changes and push to the remote Git repo.

![2-4](.github/../images/implementation/2-4.png)

Please note if you retained the default values you do not need to commit any changes. You can manually trigger the CI/CD pipeline workflow in this case.

## 3. Model Deployment

From your GitHub repo select `Actions` from the menu. From here you will be able to view the GitHub Action implementing the CI/CD pipeline for this proof-of-concept. By default, the workflow in this proof-of-concept is triggered when changes are pushed, or a pull request is made to either the `main` or `development` branch.

The following files play a key role in packaging and deploying the model API service:

- `.github/workflows/main.yaml`: the continuous integration and continuous delivery pipeline.

- `manifests/api.yaml`: the Kubernetes manifest specifying the desired state of the Kubernetes cluster.

- `service/configuration.json`: a file specifying the model versions to be used as part of the API service.

- `service/environment.yaml`: a conda file specifying the dependencies of the API service.

- `service/model_service.py`: a file required by [BentoML](https://github.com/bentoml/BentoML) to define logic for the `/predict` endpoint of the API to make model predictions.

- `service/package_model_service.py`: a file that consumes the model artifacts from the ML Flow Model Registry and `service/model_service.py` file to generate a package of the API service. Using this package we can build a Docker container.

- `service/setup.sh`: a script used during the build of the docker container. This file is consumed as part of [BentoML](https://github.com/bentoml/BentoML).

### 3.1. Execute workflow

If you made changes to the default values when executing the training notebook and successfully committed those changes the CI/CD pipeline should have executed automatically. If you retained the default changes you can trigger this manually.

By default, when you created your repo the workflow was triggered and failed since no secrets had been set. You can select the workflow from the menu which will show a diagram with three jobs. From here you can click on the `re-run all jobs button` to re-run the workflow.

![3-1](.github/../images/implementation/3-1.png)

This workflow comprises of three jobs:

- **Build:** this job will create a Docker container and register it in ACR. This Docker container will be the API which end-users will consume. This container has been developed using [BentoML](https://github.com/bentoml/BentoML) and the three machine learning models created in `2.1`.

- **Staging:** this job will deploy the Docker container to the AKS  cluster specified in the GitHub environment called `Staging`. Once deployed, the models’ state will transition to the `Staging` state in the ML Flow model registry.

- **Production:** this job will deploy the Docker container to the AKS  cluster specified in the GitHub environment called `Production`. Once deployed, the models’ state will transition to the `Production` state in the ML Flow model registry.

Note that manual approval is required to deploy the Docker container to the `Production` environment. Once the Staging job is complete you will be prompted to review the deployment. Click the `Review Deployment` button to give approval and commence the Production job. The approver(s) was specified in `1.4`.

![3-2](.github/../images/implementation/3-2.png)

### 3.2. Consume model service

To consume your model service, navigate to the AKS cluster service and select the `Services and Ingress` tab in the sidebar. From here select `Ingress` from the menu. Navigate to the IP address for the `wine-quality-service` in the `Address` column. You can do this by clicking the hyperlink or pasting the IP address into your browser.

![3-3](.github/../images/implementation/3-3.png)

This will open the Swagger UI for the [BentoML](https://github.com/bentoml/BentoML) service. This page displays the API endpoints you can consume as part of the [BentoML](https://github.com/bentoml/BentoML) service. To test the model, select the `/predict` box to open a dropdown.

![3-4](.github/../images/implementation/3-4.png)

In the dropdown, there will be a textbox called `Request Body`. Paste the following JSON snippet below and click the `Execute` button. This will call the API passing the JSON snippet which contains 2 observations. The API response will be displayed and will indicate predictions and information which can be used to monitor for outliers and data drift. This information might be useful to the consumer of the API depending on the use case.

```json
[{"fixed_acidity": 7.9,
 "volatile_acidity": 0.545,
 "citric_acid": 0.06,
 "residual_sugar": 4.0,
 "chlorides": 0.087,
 "free_sulfur_dioxide": 27.0,
 "total_sulfur_dioxide": 61.0,
 "density": 0.997,
 "pH": 3.36,
 "sulphates": 0.67,
 "alcohol": 10.7,
 "is_red": 1
},
{"fixed_acidity": 8.8,
 "volatile_acidity": 0.253,
 "citric_acid": 0.438,
 "residual_sugar": 15.01,
 "chlorides": 0.052,
 "free_sulfur_dioxide": 60.43,
 "total_sulfur_dioxide": 184.1,
 "density": 1.002,
 "pH": 3.278,
 "sulphates": 0.785,
 "alcohol": 8.085,
 "is_red": 0
}]
```

## 4. Model Monitoring

This solution uses [Container insights](https://docs.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-overview) as part of AKS. This will monitor the performance of container workloads deployed to the Kubernetes cluster.

### 4.1. View model service metrics and logs

Container insights will collect performance metrics such as memory and CPU and container logs. Performance metrics can be used to gain insights into the operational health of the API to determine how the service is performing from the perspective of the end-user.

![4-1](.github/../images/implementation/4-1.png)

When developing the API service using [BentoML](https://github.com/bentoml/BentoML) (see `service/model_service.py`) logs containing inference data, predictions, outliers, and drift have been collected. These container logs are collected with container insights and can be analysed in Log Analytics. These logs can be used to gauge the degree of model drift to determine if it’s necessary to retain your machine learning model.

Navigate to the AKS service and select the `Logs` tab in the sidebar to query the container logs. To query the services model drift metrics, paste the below query in the textbox.

```kql
ContainerLog
| where TimeGenerated > ago (30d)
| where LogEntry has 'WineQualityService' and LogEntry has 'monitoring_metrics'
| project TimeGenerated, ResponsePayload=split(LogEntry, 'INFO -')
| project timestamp=TimeGenerated, drift_magnitude=parse_json(tostring(ResponsePayload[1])).monitoring.drift.p_value
| evaluate bag_unpack(drift_magnitude)
| render timechart
```

Click the `Run` button to execute the query. This query produces a chart of the drift metrics obtained each time data was passed to the API.

![4-2](.github/../images/implementation/4-2.png)

Lower values for a feature indicate a greater likelihood of drift and values below 0.05 indicate the presence of a drifted feature. For reference, the drift metrics are p-values from the statistical tests the model uses and 0.05 is the threshold to determine statistical significance.
