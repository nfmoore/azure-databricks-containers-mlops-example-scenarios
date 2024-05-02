# Step-by-Step Setup

The purpose of this section is to describe the steps required to setup each example scenario.

## Prerequisites

Before implementing this example scenario the following is needed:

- Azure subscription with Owner permissions.
- GitHub account.

## 1. Common Setup

## 1.1. Configure a federated identity credential on a service principal

1. Create a Microsoft Entra application by executing the following command:

    ```bash
    az ad app create --display-name <your-display-name>
    ```

    Take note of the `appId` value (the Application ID or Client ID) returned by the command as it will be used in the next step.

2. Create a Microsoft Entra service principal by executing the following command:

    ```bash
    az ad sp create --id <your-application-id>
    ```

    Take note of the `id` value (the Object ID or Principal ID) returned by the command as it will be used in the next step.

3. Assign the service principal as a `Contributor` of an Azure subscription by executing the following command:

    ```bash
    az role assignment create \
    --role "Contributor" \
    --assignee-object-id <your-object-id> \
    --assignee-principal-type ServicePrincipal \
    --scope /subscriptions/<your-subscription-id>
    ```

## 1.2. Create and configure a GitHub repository

### Method 1: GitHub CLI

1. Log in to your GitHub account and navigate to the [azure-databricks-containers-mlops-example-scenarios](https://github.com/nfmoore/azure-databricks-containers-mlops-example-scenarios) repository and click `Use this Template` to create a new repository from this template.

    Rename the template and leave it public. Ensure you click `Include all branches` to copy all branches from the repository and not just `main`.

    Use [these](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/creating-a-repository-from-a-template) instructions for more details about creating a repository from a template.

2. Create the following GitHub Actions repository secrets by executing the following command:

    ```bash
    # optional - used to authenticate with your GitHub account
    gh auth login

    # set environment variables for GitHub repository secrets
    export AZURE_CLIENT_ID=<your-client-id>
    export AZURE_TENANT_ID=<your-tenant-id>
    export AZURE_SUBSCRIPTION_ID=<your-subscription-id>

    # set GitHub repository secrets
    gh secret set AZURE_CLIENT_ID --body "$AZURE_CLIENT_ID"
    gh secret set AZURE_TENANT_ID --body "$AZURE_TENANT_ID"
    gh secret set AZURE_SUBSCRIPTION_ID --body "$AZURE_SUBSCRIPTION_ID"
    ```

3. Create the following GitHub Actions repository variables by executing the following command:

    ```bash
    # optional - used to authenticate with your GitHub account
    gh auth login

    # set environment variables for GitHub repository variables

    export DEPLOYMENT_LOCATION=<your-location> # region to deploy resources e.g. australiaeast
    export BASE_NAME=example-scenarios-databricks-containers-mlops # set for convenience
    export DEPLOYMENT_RESOURCE_GROUP_NAME=rg-$BASE_NAME-01
    export DEPLOYMENT_DATARBICKS_MANAGED_RESOURCE_GROUP_NAME=rgm-databricks-$BASE_NAME-01
    export DEPLOYMENT_KUBERNETES_MANAGED_RESOURCE_GROUP_NAME=rgm-kubernetes-$BASE_NAME-01
    export DEPLOY_CONTAINER_APPS=true # requred to deploy Azure Container Apps for the Container Apps scenario
    export DEPLOY_KUBERNETES=true # requred to deploy Azure Kubernetes Service for the Kubernetes Service scenario

    # set GitHub repository variables
    gh variable set  DEPLOYMENT_LOCATION --body "$DEPLOYMENT_LOCATION"
    gh variable set  DEPLOYMENT_RESOURCE_GROUP_NAME --body "$DEPLOYMENT_RESOURCE_GROUP_NAME"
    gh variable set  DEPLOYMENT_DATARBICKS_MANAGED_RESOURCE_GROUP_NAME --body "$DEPLOYMENT_DATARBICKS_MANAGED_RESOURCE_GROUP_NAME"
    gh variable set  DEPLOYMENT_KUBERNETES_MANAGED_RESOURCE_GROUP_NAME --body "$DEPLOYMENT_KUBERNETES_MANAGED_RESOURCE_GROUP_NAME"
    gh variable set  DEPLOY_KUBERNETES --body true
    gh variable set DEPLOY_CONTAINER_APPS  --body true
    ```

4. Create the following GitHub Actions environments by executing the following command:

    ```bash
    # optional - used to authenticate with your GitHub account
    gh auth login

    # set environment variables for GitHub repository environments
    OWNER=<your-username>
    REPO=<your-repository-name>

    # create the staging environment
    gh api -X PUT /repos/$OWNER/$REPO/environments/Staging \ 
    -H "Accept: application/vnd.github+json" \ 
    -H "X-GitHub-Api-Version: 2022-11-28" \
    --silent

    # create the production environment with a reviewer and a wait timer
    gh api -X PUT /repos/$OWNER/$REPO/environments/Production \ 
    -H "Accept: application/vnd.github+json" \ 
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -F "wait_timer=30" -F "prevent_self_review=false" -f "reviewers[][type]=User" -F "reviewers[][id]=$ID"
    --silent
    ```

## 1.3. Deploy Azure resources

Execute the `Deploy Azure resources` workflow to deploy all Azure resources required for the example scenarios.

To workflow can be executed via the following methods:

### Method 1: GitHub CLI

Trigger the workflow via the GitHub CLI by executing the following command:

```bash
# optional - used to authenticate with your GitHub account
gh auth login

# trigger the workflow
gh workflow run "Deploy Azure resources"
```

### Method 2: GitHub Actions UI

Manually trigger the workflow via the GitHub Actions UI by following these steps:

1. Navigate to the GitHub repository.
2. Click on the `Actions` tab.
3. Click on the `Deploy Azure resources` workflow.
4. Click on the `Run workflow` button.
5. Click on the `Run workflow` button again to confirm the action.

> Note:
>
> - The `Deploy Azure resources` workflow is configured with a `workflow_dispatch` trigger (a manual process) for illistration purposes only.
> - The service principal is added as an workspace administrator to the Databricks workspace. This same service principal will be used to authenticate with Azure Databricks to create different artefacts such as clusters, jobs, and notebooks. This is present in all GitHub Actions workflows in this repository.

## 2. Example Sceanrios

## 2.1. Azure Container Apps

Execute the `Deploy to Container Apps` workflow to train a model, create a container image, deploy the image to an Azure Container App, and smoke test the deployed model.

To workflow can be executed via the following methods:

### Method 1: GitHub CLI

Trigger the workflow via the GitHub CLI by executing the following command:

```bash
# optional - used to authenticate with your GitHub account
gh auth login

# trigger the workflow
gh workflow run "Deploy to Container Apps"
```

### Method 2: GitHub Actions UI

Manually trigger the workflow via the GitHub Actions UI by following these steps:

1. Navigate to the GitHub repository.
2. Click on the `Actions` tab.
3. Click on the `Deploy to Container Apps` workflow.
4. Click on the `Run workflow` button.
5. Click on the `Run workflow` button again to confirm the action.

> Note:
>
> - The `Deploy Infrastructure` workflow is a prerequisite for the `Deploy to Container Apps` workflow.
> - The `Deploy to Container Apps` workflow is configured with a `workflow_dispatch` trigger (a manual process) for illistration purposes only.

## 2.2. Azure Kubernetes Service

Execute the `Deploy to Kubernetes Service` workflow to train a model, create a container image, deploy the image to Azure Kubernetes Service, and smoke test the deployed model.

To workflow can be executed via the following methods:

**Method 1**:

Trigger the workflow via the GitHub CLI by executing the following command:

```bash
gh auth # (optional - used to authenticate with your GitHub account)
gh workflow run "Deploy to Kubernetes Service"
```

**Method 2**:

Manually trigger the workflow via the GitHub Actions UI by following these steps:

1. Navigate to the GitHub repository.
2. Click on the `Actions` tab.
3. Click on the `Deploy to Kubernetes Service` workflow.
4. Click on the `Run workflow` button.
5. Click on the `Run workflow` button again to confirm the action.

> Note:
>
> - The `Deploy Infrastructure` workflow is a prerequisite for the `Deploy to Kubernetes Service` workflow.
> - The `Deploy to Kubernetes Service` workflow is configured with a `workflow_dispatch` trigger (a manual process) for illistration purposes only.
