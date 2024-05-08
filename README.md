# Example Scenarios: MLOps with Azure Databricks using Containers for Online Inference

## :books: Overview

This repository provides prescriptive guidance when building, deploying, and monitoring machine learning models with [Azure Databricks](https://learn.microsoft.com/azure/databricks/introduction/) for online inference scenarios in line with MLOps principles and practices.

MLOps is a set of repeatable, automated, and collaborative workflows with best practices that empower teams of ML professionals to quickly and easily get their machine learning models deployed into production.

## :computer: Getting Started

This repository will focus on online inference scenarios that integrate Azure Databricks with other Azure services to deploy machine learning models as web services. Out-of-the-box capabilities of Azure Databricks will be used to build machine learning models, but the deployment and monitoring of these models will be done using Azure Container Apps or Azure Kubernetes Service.

All example scenarios will focus on classical machine learning problems. An adapted version of the `UCI Credit Card Client Default` [dataset](https://archive.ics.uci.edu/dataset/350/default+of+credit+card+clients) will be used to illustrate each example scenario. The data is available in the `core/data` directory of this repository.

### Setup

Detailed instructions for deploying this proof-of-concept are outlined in the [Step-by-Step Setup](.github/docs/step-by-step-setup.md) section of this repository. This proof-of-concept will illustrate how to:

- Build a machine learning model on Azure Databricks.
- Containerize the machine learning model.
- Deploy the machine learning model as a web service using Azure Container Apps or Azure Kubernetes Service.
- Develop automated workflows to build and deploy models.
- Monitor the machine learning model for usage, performance, and data drift.

### Example Scenarios

This proof-of-concept will cover the following example scenarios:

| Example Scenario | Description |
| ---------------- | ----------- |
| Azure Container Apps | Build a machine learning model on Azure Databricks, containerize it, and deploy it as a web service using Azure Container Apps. |
| Azure Kubernetes Service | Build a machine learning model on Azure Databricks, containerize it, and deploy it as a web service using Azure Kubernetes Service. |

For more information on the example scenarios are outlined in the [Getting Started](.github/docs/getting-started.md) section of this repository.

## :balance_scale: License

Details on licensing for the project can be found in the [LICENSE](./LICENSE) file.
