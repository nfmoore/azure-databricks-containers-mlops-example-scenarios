# Implementation Guide

## Prerequisites

- Azure subscription (contributor or owner)
- GitHub account

## 1. Infrastructure Setup

### 1.1. Create repository

Log in to your GitHub account, navigate to the [databricks-kubernetes-online-inference-poc](https://github.com/nfmoore/databricks-kubernetes-online-inference-poc) repository and click `use this template` to create a new repository from this template. Rename the template and leave it public. Use [these](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/creating-a-repository-from-a-template) instructions for more details about creating a repository from a template.

### 1.2. Deploy resources

The Azure resources required to implement this proof-of-concept include an [Azure Databricks](https://docs.microsoft.com/en-us/azure/databricks/scenarios/what-is-azure-databricks) workspace, an [Azure Log Analytics](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/data-platform-logs) workspace, an [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-intro) (ACR), and 2 [Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/intro-kubernetes) (AKS) instances (for a staging and production environments respectively).

To deploy the resources for this proof-of-concept in your Azure environment click the `Deploy to Azure` button below. The resources can be deployed into an existing Resource Group or you can choose to create a new Resource Group.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fnfmoore%2Fdatabricks-kubernetes-mlops-poc%2Fmain%2Finfrastructure%2Fmain.json)

![1-1](.github/../images/implementation/1-1.png)

### 1.3. Configure resources

After the resources have been successfully deployed some services need to be configured before you can train, register, deploy and monitor the machine learning models.

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
- `Advanced Options - Environment Variables`: add environment variables to the cluster that specify details for your Kaggle account (more information below).

![1-6](.github/../images/implementation/1-6.png)

For this proof-of-concept, a dataset from Kaggle is used to develop a machine learning model. The notebook will use the Kaggle API to download the dataset onto your Databricks cluster. For this to work you must export your Kaggle username and token to the Databricks cluster environment. Details for finding your Kaggle API credentials can be found [here](https://github.com/Kaggle/kaggle-api#api-credentials).

> Note: you will need to create a Kaggle account if you don't already have one.

![1-6-1](.github/../images/implementation/1-6-1.png)

Click the `Create Cluster` button to create the cluster.

Once the cluster has been created select the cluster from the table on the `Compute` section and navigate to the `Libraries` section shown on the menu. Click the `Install Now` button, select `PyPI` as the library source and enter `kaggle==1.5.12` as the `Package` then click `Install`. Repeat this process for the `alibi-detect==0.8.1` package.

[Alibi Detect](https://github.com/SeldonIO/alibi-detect) is an open-source Python library focused on outlier, adversarial, and drift detection. In this proof-of-concept detectors from this package will be used to monitor for outliers and data drift.

![1-7](.github/../images/implementation/1-7.png)

### 1.4. Configure GitHub environments

For this proof-of-concept, one Kubernetes cluster will be used as part of a staging environment and the second will be used as part of a production environment. To enable these different deployment targets with custom secrets and protection rules [GitHub environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) will be used.

To set up these environments, from your GitHub repository you created in `1.1` click the `Settings` tab in the menu bar. On the new page select `Environments` from the sidebar. Click the `New Environment` button and create an environment with the `Name` of `Staging` and click the `Configure Environment` button. Click the `Add Secret` button and create the following secrets with values from your deployments from `1.2`.

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
| AZURE_CREDENTIALS | A JSON object with details of your Azure Service Principal. [This](https://github.com/marketplace/actions/azure-login#configure-deployment-credentials) document will help you configure a service principal with a secret. The value will look something like: `{ "clientId": "<GUID>", "clientSecret": "<GUID>", "subscriptionId": "<GUID>", "tenantId": "<GUID>", ... }`|
| DATABRICKS_HOST | This is the `instance name` or `per-workspace URL` of your Azure Databricks service. Its value can be found from the Databricks service page on the Azure Portal under the `URL` parameter. For more information [this]( https://docs.microsoft.com/en-us/azure/databricks/workspace/workspace-details#per-workspace-url) resource can be used. The value will look something like `https://adb-5555555555555555.19.azuredatabricks.net`|
| DATABRICKS_TOKEN | This is the value of the `Access Token` you created in `1.3`. The value should look something like `dapi55555555555555555555555555555555-2`. |
| CONTAINER_REGISTRY_NAME | The name of the ACR service deployed in template two. |
| CONTAINER_REGISTRY_PASSWORD | This can be found in the access keys section of the ACR service page. The Admin Account section of [this]( https://docs.microsoft.com/en-us/azure/container-registry/container-registry-authentication?tabs=azure-cli#admin-account) document contains more information. |
| CONTAINER_REGISTRY_IMAGE_PULL_SECRET | A image pull secret you create. |

![1-10](.github/../images/implementation/1-10.png)

## 2. Model Development

The model development process has been encapsulated in a single notebook called `develop_model`. This notebook will develop and register an MLFlow Model for deployment consisting of:

- A machine learning model to predict the likelihood of employee attrition.
- A statistical model to determine data drift in features.
- A statistical model to determine outliers in features.

In practice, the model development process requires more effort than illustrated in this notebook. This notebook does incorporate experiment tracking and model registration and versioning which are critical elements of a well-developed MLOps process.

This example uses the `IBM HR Analytics Employee Attrition & Performance` [dataset](https://www.kaggle.com/pavansubhasht/ibm-hr-analytics-attrition-dataset) available from Kaggle.

### 2.1. Train models

To execute the notebook to develop the models required by the machine learning service select the `Repos` section from the sidebar and navigate to `notebooks/develop_model` (click the file to open it).

![2-1](.github/../images/implementation/2-1.png)

When the notebook is open click the `Run All` button to execute the notebook. If prompted to select a cluster, select the cluster you created in `1.3`.

Once the notebook has been successfully executed, navigate to the `Models` section from the sidebar. Ensure you have set the `Machine Learning` persona for your Databricks workspace. This option is available from the sidebar as the first option. You should see a single model called `employee_attrition`.

![2-2](.github/../images/implementation/2-2.png)

### 2.2. Commit model configuration

After developing the model, a JSON configuration file is used to define the model name and model version of the model you want to deploy from the [MLFLow model registry](https://docs.microsoft.com/en-us/azure/databricks/applications/machine-learning/manage-model-lifecycle/) as part of the API. Each of the 3 individual machine learning or statistical models created within this notebook has been encapsulated into this single MLFlow `python_function` model. This ensures that the API won't have to directly perform any data science-related actions.

Once a new model version has been developed you can edit the `service/configuration.json` file to specify the specific model to deploy. In a workflow based on this proof-of-concept, data science team members can use this file to control which model should be deployed as part of the API.

If you did not edit the default model name or version from this notebook you will not need to edit this file for the proof-of-concept implementation. However, if you edited the model name or version you will need to edit this file to reflect the changes you made.

![2-3](.github/../images/implementation/2-3.png)

If you edit the `service/configuration.json` file you will need to commit your changes to the GitHub Repo. To make a commit (assuming you have changed this file) select `Repos` from the sidebar click the branch next to the repo name in the flyout menu. This will open a window that shows the changes you have made. If you have made changes add a summary in the `Summary` text field and an optional description then click the `Commit and Push` button to commit the changes and push to the remote Git repo.

![2-4](.github/../images/implementation/2-4.png)

Please note if you retained the default values you do not need to commit any changes. You can manually trigger the CI/CD pipeline workflow in this case.

## 3. Model Deployment

From your GitHub repo select `Actions` from the menu. From here you will be able to view the GitHub Action implementing the CI/CD pipeline for this proof-of-concept. By default, the workflow in this proof-of-concept is triggered manually within GitHub.

The following files play a key role in packaging and deploying the model API service:

- `.github/workflows/main.yaml`: the continuous integration and continuous delivery pipeline.
- `manifests/api.yaml`: the Kubernetes manifest specifying the desired state of the Kubernetes cluster.
- `service/app`: a directory containing a [FastAPI](https://fastapi.tiangolo.com) web service that consumes the MLFlow model.
- `service/configuration.json`: a file specifying the model versions to be used as part of the API service.
- `service/Dockerfile`: a Dockerfile used to containerize the service.
- `service/requirements.txt`: a file specifying the Python dependencies of the API service.

### 3.1. Execute workflow

To execute the CI/CD pipeline you can manually trigger the workflow in GitHub. Under the `Actions` tab select the `Build-Deploy` workflow then select `Run workflow` and click `Run workflow`.

![3-1](.github/../images/implementation/3-1.png)

This workflow comprises of three jobs:

- **Build:** this job will create a Docker container and register it in ACR. This Docker container will be the API that end-users will consume.
- **Staging:** this job will deploy the Docker container to the AKS cluster specified in the GitHub environment called `Staging`. Once deployed, the model's state will transition to the `Staging` state in the MLFLow model registry.
- **Production:** this job will deploy the Docker container to the AKS cluster specified in the GitHub environment called `Production`. Once deployed, the model's state will transition to the `Production` state in the MLFLow model registry.

Note that manual approval is required to deploy the Docker container to the `Production` environment. Once the Staging job is complete you will be prompted to review the deployment. Click the `Review Deployment` button to give approval and commence the Production job. The approver(s) was specified in `1.4`.

![3-2](.github/../images/implementation/3-2.png)

### 3.2. Consume model service

To consume your model service, navigate to the AKS cluster service and select the `Services and Ingress` tab in the sidebar. From here select `Ingress` from the menu. Navigate to the IP address for the `employee-attrition-api` in the `Address` column. You can do this by clicking the hyperlink or pasting the IP address into your browser.

![3-3](.github/../images/implementation/3-3.png)

This will open the Swagger UI for [FastAPI](https://fastapi.tiangolo.com). This page displays the API endpoints you can consume as part of the service. To test the model, select the `/predict` box to open a dropdown.

![3-4](.github/../images/implementation/3-4.png)

In the dropdown, there will be a textbox called `Request Body`. Paste the following JSON snippet below and click the `Execute` button. This will call the API passing the JSON snippet that contains a single record (alternatively the API is also pre-populated with a default value that can be used). The API response will be displayed and will indicate predictions and information which can be used to monitor for outliers and data drift. This information might be useful to the consumer of the API depending on the use case.

```json
[
 {
 "BusinessTravel": "Travel_Rarely",
 "Department": "Research & Development",
 "EducationField": "Medical",
 "Gender": "Male",
 "JobRole": "Manager",
 "MaritalStatus": "Married",
 "Over18": "Yes",
 "OverTime": "No",
 "Age": 36,
 "DailyRate": 989,
 "DistanceFromHome": 8,
 "Education": 1,
 "EmployeeCount": 1,
 "EmployeeNumber": 253,
 "EnvironmentSatisfaction": 4,
 "HourlyRate": 46,
 "JobInvolvement": 3,
 "JobLevel": 5,
 "JobSatisfaction": 3,
 "MonthlyIncome": 19033,
 "MonthlyRate": 6499,
 "NumCompaniesWorked": 1,
 "PercentSalaryHike": 14,
 "PerformanceRating": 3,
 "RelationshipSatisfaction": 2,
 "StandardHours": 65,
 "StockOptionLevel": 1,
 "TotalWorkingYears": 14,
 "TrainingTimesLastYear": 3,
 "WorkLifeBalance": 2,
 "YearsAtCompany": 3,
 "YearsInCurrentRole": 3,
 "YearsSinceLastPromotion": 3,
 "YearsWithCurrManager": 1
 }
]
```

## 4. Model Monitoring

This solution uses [Container insights](https://docs.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-overview) as part of AKS. This will monitor the performance of container workloads deployed to the Kubernetes cluster.

### 4.1. View model service metrics and logs

Container insights will collect performance metrics such as memory and CPU and container logs. Performance metrics can be used to gain insights into the operational health of the API to determine how the service is performing from the perspective of the end-user.

![4-1](.github/../images/implementation/4-1.png)

From the API logs containing inference data, predictions, outliers, and drift have been collected. These container logs are collected with container insights and can be analyzed in Log Analytics. These logs can be used to gauge the degree of model drift to determine if it’s necessary to retain your machine learning model.

Navigate to the AKS service and select the `Logs` tab in the sidebar to query the container logs. To query the services model drift metrics, paste the below query in the textbox.

```kql
ContainerLog
| where TimeGenerated > ago (30d)
| where LogEntry has 'Employee Attrition API' and LogEntry has 'OutputData'
| project TimeGenerated, ResponsePayload=split(LogEntry, 'INFO:')
| project TimeGenerated, DriftMagnitude=parse_json(tostring(ResponsePayload[1])).data.drift__magnitude
| evaluate bag_unpack(DriftMagnitude)
```

Click the `Run` button to execute the query. This query produces a list of the drift metrics for each feature obtained each time data was passed to the API.

![4-2](.github/../images/implementation/4-2.png)

Lower values for a feature indicate a greater likelihood of drift and values below 0.05 indicate the presence of a drifted feature. For reference, the drift metrics are p-values from the statistical tests the model uses and 0.05 is the threshold to determine statistical significance.

Custom charts can also be developed using this data by selecting the `Chart` tab and changing the values in the `Chart formatting` section.

![4-3](.github/../images/implementation/4-3.png)
