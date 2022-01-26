# Proof-of-Concept: MLOps Platform using Databricks and Kubernetes

## Overview

This repository contains resources for an end-to-end proof of concept which illustrates how an MLFlow model can be trained on Databricks, packaged as a web service, deployed to Kubernetes via CI/CD, and monitored within Microsoft Azure. A high-level solution design is shown below:

![workflow](.github/docs/images/workflow.png)

For more information on a generic solution design see the [Architecture Guide](.github/docs/architecture-guide.md)

> For additional insights into applying this approach to operationalize your machine learning workloads refer to this article — [Machine Learning at Scale with Databricks and Kubernetes](https://medium.com/@nfmoore/machine-learning-at-scale-with-databricks-and-kubernetes-9fa59232bfa6)

## Getting Started

This repository contains detailed step-by-step instructions on how to implement this solution in your Microsoft Azure subscription. At a high-level an implementation contains four main stages:

- **Infrastructure Setup:** this includes an Azure Databricks workspace, an Azure Log Analytics workspace, an Azure Container Registry, and 2 Azure Kubernetes clusters (for a staging and production environment respectively).

- **Model Development:** this includes core components of the model development process such as experiment tracking and model registration. An Azure Databricks Workspace will be used to develop three MLFlow models to generate predictions, access data drift and determine outliers.

- **Model Deployment:** this includes implementing a CI/CD pipeline with GitHub Actions to package a MLFlow model as an API for model serving. [FastAPI](https://fastapi.tiangolo.com) will be used to develop the web API for deployment. This will be containerized and deployed on separate Azure Kubernetes clusters for Staging and Production respectively.

- **Model Monitoring:** this includes using Azure Monitor for containers to monitor the health and performance of the API. In addition, Log Analytics will be used to monitor data drift and outliers by analysing log telemetry.

For detailed step-by-step instructions see the [Implementation Guide](.github/docs/implementation-guide.md).

## Scenario

This proof-of-concept will be based on a common problem in HR analytics - employee attrition. Employee Attrition refers to the process by which employees leave an organization – for example, through resignation for personal reasons or retirement – and are not immediately replaced.

Within this proof-of-concept, a machine learning model will be developed to predict the likelihood of attrition for an employee along with metrics capturing data drift and outliers to access the model's validity. This implementation uses the `IBM HR Analytics Employee Attrition & Performance` [dataset](https://www.kaggle.com/pavansubhasht/ibm-hr-analytics-attrition-dataset) available from Kaggle.

The scenario in this repository will first develop a machine learning model which will then be deployed as an API for online inference. This API can be integrated with external applications used by HR teams to provide additional insights into the likelihood of attrition for a given employee within the organization. 

The scenario in this repository will first develop a machine learning model which will then be deployed as an API for online inference. This API can be integrated with external applications used by HR teams to provide additional insights into the likelihood of attrition for a given employee within the organization. This information can be used to determine if a high-impact employee is likely to leave the organization and hence provide HR with the ability to proactively incentivize the employee to stay.

## License

Details on licensing for the project can be found in the [LICENSE](./LICENSE) file.
