# Architecture Guide

This repository illustrates an end-to-end proof-of-concept scenario that demonstrates how to use Azure Databricks and Azure Kubernetes Service to develop an [MLOps](https://docs.microsoft.com/en-us/azure/machine-learning/concept-model-management-and-deployment) platform for online inference workloads. This solution can manage the end-to-end machine learning life cycle and incorporates important [MLOps](https://docs.microsoft.com/en-us/azure/machine-learning/concept-model-management-and-deployment) principles when developing, deploying, and monitoring machine learning models at scale.

This approach can easily be extended to address batch inference workloads and incorporate other useful services when managing APIs at scale such as [Azure API Management](https://docs.microsoft.com/en-us/azure/api-management/api-management-key-concepts).

## Potential use cases

This approach is best suited for:

- Teams that have standardized on Databricks for data engineering or machine learning applications.
- Teams that have experience deploying and managing Kubernetes workloads with a preference to apply these skills for operationalizing machine learning workloads.
- Workloads that require low latency and interactive model predictions are best suited for real-time model inference.

## Architecture

A holistic high-level architecture for an MLOps Platform based on the approach outlined in this repository is as follows.

![design](./images/architecture.png)

At a high level, this solution design addresses each stage of the machine learning lifecycle:

- **Data Preparation:** this includes sourcing, cleaning, and transforming the data for processing and analysis. Data can live in a data lake or data warehouse and be stored in a feature store after it's curated.
- **Model Development:** this includes core components of the model development process such as experiment tracking and model registration using [MLFlow](https://docs.microsoft.com/en-us/azure/databricks/applications/mlflow/).
- **Model Deployment:** this includes implementing a CI/CD pipeline to containerize machine learning models as API services. These services will be deployed to Azure Kubernetes clusters for end-users to consume.
- **Model Monitoring:** this includes monitoring the API performance and model data drift by analyzing log telemetry with Azure Monitor.

> **NOTE:**
>
> The proof-of-concept that is focused on in this repository and documented in the implementation guide only addresses online (or real-time) inference workloads depicted in the above high-level design. Batch inference workloads are not covered as part of this repository.

## Components

The following components are used as part of this design:

- [Azure Databricks](https://docs.microsoft.com/en-us/azure/databricks/scenarios/what-is-azure-databricks): easy and collaborative Apache Spark-based big data analytics service designed for data science and data engineering.
- [Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/intro-kubernetes): simplified deployment and management of Kubernetes by offloading the operational overhead to Azure.
- [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-intro): managed and private Docker registry service based on the open-source Docker.
- [Azure Data Lake Gen 2](https://docs.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-introduction): scalable solution optimized for storing massive amounts of unstructured data.
- [Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/overview): a comprehensive solution for collecting, analyzing, and acting on telemetry from your workloads.
- [MLflow](https://docs.microsoft.com/en-us/azure/databricks/applications/mlflow): open-source solution integrated within Databricks for managing the end-to-end machine learning life cycle.
- [Azure API Management](https://docs.microsoft.com/en-us/azure/api-management/api-management-key-concepts): a fully managed service that enables customers to publish, secure, transform, maintain, and monitor APIs.
- [Azure Application Gateway](https://docs.microsoft.com/en-us/azure/application-gateway/overview): a web traffic load balancer that enables you to manage traffic to your web applications.
- [Azure DevOps](https://azure.microsoft.com/solutions/devops/) or [GitHub](https://azure.microsoft.com/products/github/): solutions for implementing DevOps practices to enforce automation and compliance with your workload development and deployment pipelines.

> **NOTE:**
>
>- When implementing a [CI/CD pipeline](https://docs.microsoft.com/en-us/azure/architecture/microservices/ci-cd) different tools such as Azure DevOps Pipelines or GitHub Actions can be used.
>- The services covered in this design are only a subset of a much larger family of Azure services.
>- Specific business requirements for your analytics use case could require the use of different services or features that are not considered in this design.

## Considerations

Before implementing this solution some factors you might want to consider, include:

- This solution is designed for teams who require a high degree of customization and have extensive expertise deploying and managing Kubernetes workloads. If your data science team does not have this expertise consider deploying models to another service like [Azure Machine Learning](https://azure.microsoft.com/services/machine-learning).
- The [Machine Learning DevOps Guide](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/ai-machine-learning-mlops#machine-learning-devops-mlops-best-practices-with-azure-machine-learning) presents best practices and learnings on adopting ML operations (MLOps) in the enterprise with Machine Learning.
- Follow the recommendations and guidelines defined in the [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework) to improve the quality of your Azure solutions.
- When implementing a [CI/CD pipeline](/azure/architecture/microservices/ci-cd) different tools such as Azure Pipelines or GitHub Actions can be used.
- Specific business requirements for your analytics use case could require the use of different services or features that are not considered in this design.

## Pricing

All services deployed in this solution use a consumption-based pricing model. The [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator) can be used to estimate costs for a specific scenario. For other considerations, see [Cost Optimization](https://docs.microsoft.com/en-us/azure/architecture/framework/#cost-optimization) in the Well-Architected Framework.

## Related resources

You may also find these Architecture Center articles useful:

- [Machine Learning Operations maturity model](https://docs.microsoft.com/en-us/azure/architecture/example-scenario/mlops/mlops-maturity-model)
- [Team Data Science Process for data scientists](https://docs.microsoft.com/en-us/azure/architecture/data-science-process/overview)
- [Modern analytics architecture with Azure Databricks](https://docs.microsoft.com/en-us/azure/architecture/solution-ideas/articles/azure-databricks-modern-analytics-architecture)
- [Building A Clinical Data Drift Monitoring System With Azure DevOps, Azure Databricks, And MLflow](https://devblogs.microsoft.com/cse/2020/10/29/building-a-clinical-data-drift-monitoring-system-with-azure-devops-azure-databricks-and-mlflow/)
