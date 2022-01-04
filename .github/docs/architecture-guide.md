# Architecture Guide

This example scenario demonstrates how to use Azure Databricks and Azure Kubernetes Service to develop an [ML Ops](https://docs.microsoft.com/en-us/azure/machine-learning/concept-model-management-and-deployment) platform for real-time model inference. This solution can manage the end-to-end machine learning life cycle and incorporates important [ML Ops](https://docs.microsoft.com/en-us/azure/machine-learning/concept-model-management-and-deployment) principles when developing, deploying and monitoring machine learning models at scale.

## Potential use cases

This approach is best suited for:

- Teams that have standardised on Databricks for data engineering or machine learning applications.
- Teams that have experience deploying and managing Kubernetes workloads with a preference to leverage these skills for operationalising machine learning workloads.
- Workloads that require low latency and interactive model predictions are best suited for real-time model inference.

## Architecture

![design](./images/architecture.png)

At a high-level this solution design addresses each stage of the machine learning lifecycle:

- Data Preparation: this includes sourcing, cleaning and transforming the data for processing and analysis. Data can reside in a data lake or data warehouse and be stored in a feature store after it is curated.
- Model Development: this includes core components of the model development process such as experiment tracking and model registration using [MLflow](https://docs.microsoft.com/en-us/azure/databricks/applications/mlflow/).
- Model Deployment: this includes implementing a CI/CD pipeline to containerize machine learning models as API services. These services will be deployed to Azure Kubernetes clusters for end-users to consume.
- Model Monitoring: this includes using Azure Monitor to monitor the health and performance of the API and monitor data drift and outliers by analysing log telemetry.

> **NOTE:**
>
>- When implementing a [CI/CD pipeline](https://docs.microsoft.com/en-us/azure/architecture/microservices/ci-cd) different tools such as Azure DevOps Pipelines or GitHub Actions can be used.
>- The services covered by this architecture are only a subset of a much larger family of Azure services.
>- Specific business requirements for your analytics use case could require the use of different services or features that are not considered in this design.

## Components

The following components are used as part of this design:

- [Azure Databricks](https://docs.microsoft.com/en-us/azure/databricks/scenarios/what-is-azure-databricks): easy and collaborative Apache Spark-based big data analytics service designed for data science and data engineering.
- [Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/intro-kubernetes): simplified deployment and management of Kubernetes by offloading the operational overhead to Azure.
- [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-intro): managed and private Docker registry service based on the open-source Docker.
- [Azure Data Lake Gen 2](https://docs.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-introduction): scalable solution optimized for storing massive amounts of unstructured data.
- [Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/overview): a comprehensive solution for collecting, analyzing and acting on telemetry from your workloads.
- [MLflow](https://docs.microsoft.com/en-us/azure/databricks/applications/mlflow): open-source solution integrated within Databricks for managing the end-to-end machine learning life cycle.
- [Azure DevOps](https://azure.microsoft.com/solutions/devops/) or [GitHub](https://azure.microsoft.com/products/github/): solutions for implementing DevOps practices to enforce automation and compliance to your workload development and deployment pipelines.

## Considerations

Before implementing this solution some factors you might want to consider include:

- This solution is designed for teams who require a high degree of customisation and have extensive expertise deploying and managing Kubernetes workloads. If your data science team does not have this expertise consider deploying models to another service like [Azure Machine Learning](https://azure.microsoft.com/services/machine-learning).
- The [Machine Learning DevOps Guide](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/ai-machine-learning-mlops#machine-learning-devops-mlops-best-practices-with-azure-machine-learning) presents best practices and learnings on adopting ML operations (ML Ops) in the enterprise with Machine Learning.
- Follow the recommendations and guidelines defined in the [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework) to improve the quality of your Azure solutions.
- When implementing a [CI/CD pipeline](https://docs.microsoft.com/en-us/azure/architecture/microservices/ci-cd) different tools such as Azure DevOps Pipelines or GitHub Actions can be used.
- Specific business requirements for your analytics use case could require the use of different services or features that are not considered in this design.

## Pricing

All services deployed in this solution use a consumption-based pricing model. The [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator) can be used to estimate costs for a specific scenario. For other considerations, see [Cost Optimization](https://docs.microsoft.com/en-us/azure/architecture/framework/#cost-optimization) in the Well-Architected Framework.

## Deploy this scenario

A proof-of-concept implementation of this scenario is available at the [ML Ops Platform using Databricks and Kubernetes](https://github.com/nfmoore/databricks-kubernetes-mlops-poc) repository. This sample illustrates:

- how an ML Flow model can be trained on Databricks.
- how to package models as a web service using open source tools.
- hot to deploy to Kubernetes via CI/CD.
- how to monitor API performance and model data drift.

## Related resources

You may also find these Architecture Center articles useful:

- [Machine Learning Operations maturity model](https://docs.microsoft.com/en-us/azure/architecture/example-scenario/mlops/mlops-maturity-model)
- [Team Data Science Process for data scientists](https://docs.microsoft.com/en-us/azure/architecture/data-science-process/overview)
- [Modern analytics architecture with Azure Databricks](https://docs.microsoft.com/en-us/azure/architecture/solution-ideas/articles/azure-databricks-modern-analytics-architecture)
