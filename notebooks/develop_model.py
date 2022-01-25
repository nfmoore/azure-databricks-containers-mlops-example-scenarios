# Databricks notebook source
# MAGIC %md
# MAGIC # Develop Machine Learning Model
# MAGIC 
# MAGIC This notebook aims to develop and register an MLFlow Model for deployment consisting of:
# MAGIC - a machine learning model to predict the liklihood of employee attrition.
# MAGIC - a statistical model to determine data drift in features
# MAGIC - a statistical model to determine outliers in features
# MAGIC 
# MAGIC This example uses the [`IBM HR Analytics Employee Attrition & Performance` dataset](https://www.kaggle.com/pavansubhasht/ibm-hr-analytics-attrition-dataset) available from Kaggle.
# MAGIC 
# MAGIC > Ensure you have configured your cluster to export your Kaggle username and token to the environment to use the Kaggle API. For reference see [Kaggle API Credentials](https://github.com/Kaggle/kaggle-api#api-credentials).

# COMMAND ----------

# MAGIC %md
# MAGIC 
# MAGIC #### Import dependencies and pre-process data data
# MAGIC 
# MAGIC The dataset will be downloaded from Kaggle and and split into samples for model training and testing.

# COMMAND ----------

import os
from pprint import pprint

import joblib
import kaggle
import mlflow
import mlflow.pyfunc
import numpy as np
import pandas as pd
from alibi_detect.cd import TabularDrift
from alibi_detect.od.isolationforest import IForest
from alibi_detect.utils.saving import load_detector, save_detector
from hyperopt import STATUS_OK, fmin, hp, tpe
from mlflow.models.signature import infer_signature
from mlflow.tracking import MlflowClient
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

# Download dataset
dataset_name = "pavansubhasht/ibm-hr-analytics-attrition-dataset"
kaggle.api.authenticate()
kaggle.api.dataset_download_files(
    dataset_name, path='/tmp', unzip=True)

# COMMAND ----------


# Read dataset
df_attrition = pd.read_csv("/tmp/WA_Fn-UseC_-HR-Employee-Attrition.csv")
df_attrition.head()

# COMMAND ----------


# Define target column
columns_target = ["Attrition"]

# Define categorical feature columns
columns_categorical = ["BusinessTravel", "Department", "EducationField",
                       "Gender", "JobRole", "MaritalStatus", "Over18", "OverTime"]

# Define numeric feature columns
columns_numeric = ["Age", "DailyRate", "DistanceFromHome", "Education", "EmployeeCount", "EmployeeNumber", "EnvironmentSatisfaction", "HourlyRate", "JobInvolvement", "JobLevel", "JobSatisfaction", "MonthlyIncome", "MonthlyRate", "NumCompaniesWorked",
                   "PercentSalaryHike", "PerformanceRating", "RelationshipSatisfaction", "StandardHours", "StockOptionLevel", "TotalWorkingYears", "TrainingTimesLastYear", "WorkLifeBalance", "YearsAtCompany", "YearsInCurrentRole", "YearsSinceLastPromotion", "YearsWithCurrManager"]

# Convert values of `Over18` feature for consistancy
df_attrition["Over18"] = df_attrition["Over18"].replace(
    {"Y": "Yes", "N": "No"})

# Change data types of features
df_attrition[columns_target] = df_attrition[columns_target].replace(
    {"Yes": 1, "No": 0}).astype("str")
df_attrition[columns_categorical] = df_attrition[columns_categorical].astype(
    "str")
df_attrition[columns_numeric] = df_attrition[columns_numeric].astype("float")

# Split into train and test datasets
X_train, X_test, y_train, y_test = train_test_split(
    df_attrition[columns_categorical + columns_numeric], df_attrition[columns_target], test_size=0.20, random_state=2022)

# COMMAND ----------

# MAGIC %md
# MAGIC 
# MAGIC #### Build classifier
# MAGIC 
# MAGIC A machine learning model will be built to predict the liklihood of employee attrition.

# COMMAND ----------


# Define classifer pipeline
def make_classifer_pipeline(params):
    categorical_transformer = Pipeline(steps=[
        ("imputer", SimpleImputer(strategy="constant", fill_value="missing")),
        ("ohe", OneHotEncoder())]
    )

    numeric_transformer = Pipeline(steps=[
        ("imputer", SimpleImputer(strategy="median"))]
    )

    preprocessor = ColumnTransformer(
        transformers=[
            ("numeric", numeric_transformer, columns_numeric),
            ("categorical", categorical_transformer, columns_categorical)
        ]
    )

    classifer_pipeline = Pipeline([
        ("preprocessor", preprocessor),
        ("classifier", RandomForestClassifier(**params, n_jobs=-1))
    ])

    return classifer_pipeline

# COMMAND ----------


# Define objective function
def hyperparameter_tuning(params):
    mlflow.sklearn.autolog(silent=True)

    with mlflow.start_run(nested=True):
        # Train and model
        estimator = make_classifer_pipeline(params)
        estimator = estimator.fit(X_train, y_train.values.ravel())
        y_predict_proba = estimator.predict_proba(X_test)
        auc_score = roc_auc_score(y_test, y_predict_proba[:, 1])

        # Log artifacts
        signature = infer_signature(X_train, y_predict_proba[:, 1])
        mlflow.sklearn.log_model(estimator, "model", signature=signature)
        mlflow.log_metric("testing_auc", auc_score)

        return {"loss": -auc_score, "status": STATUS_OK}

# COMMAND ----------


# Define search space
search_space = {
    "n_estimators": hp.choice("n_estimators", range(100, 1000)),
    "max_depth": hp.choice("max_depth", range(1, 20)),
    "criterion": hp.choice("criterion", ["gini", "entropy"]),
}

# Start model training run
with mlflow.start_run(run_name="employee-attrition-classifier") as run:
    # Hyperparameter tuning
    best_params = fmin(
        fn=hyperparameter_tuning,
        space=search_space,
        algo=tpe.suggest,
        max_evals=10,
    )

    # End run
    mlflow.end_run()

# COMMAND ----------


# Load model from best run and save model artifact
best_run = mlflow.search_runs(filter_string=f"tags.mlflow.parentRunId = '{run.info.run_id}'", order_by=[
                              "metrics.testing_auc DESC"]).iloc[0]
classifier = mlflow.pyfunc.load_model(f"runs:/{best_run.run_id}/model")

# Download model artifact
client = MlflowClient()
local_dir = "/tmp/models/classifier"
os.makedirs(local_dir, exist_ok=True)
client.download_artifacts(best_run.run_id, "model", local_dir)

# COMMAND ----------

# MAGIC %md
# MAGIC 
# MAGIC #### Build data drift model
# MAGIC 
# MAGIC A statistical model will be built to determine data drift in features.

# COMMAND ----------


# Develop drift model using Kolmogorov-Smirnov (K-S) tests for the continuous numerical features and Chi-Squared tests for the categorical features
def make_drift_model(X, categories_per_feature, **params):
    return TabularDrift(X, categories_per_feature=categories_per_feature, **params)

# Preprocess output of drift model
def process_drift_output(output, column_names):
    return {
        "threshold": output["data"]["threshold"],
        "is_drift": dict(zip(column_names, output["data"]["is_drift"].tolist())),
        "p_value": dict(zip(column_names, output["data"]["p_val"].tolist())),
        "magnitude": dict(zip(column_names, (1 - output["data"]["p_val"]).tolist()))
    }


with mlflow.start_run(run_name="employee-attrition-drift") as run:
    # Develop drift model
    drift_column_names = columns_categorical + columns_numeric
    categories_per_feature = {0: None, 1: None, 2: None,
                              3: None, 4: None, 5: None, 6: None, 7: None}
    drift_model = make_drift_model(
        X_train[drift_column_names].values, categories_per_feature)

    # Log model to mlflow run
    drift_model_path = "/tmp/models/drift"
    save_detector(drift_model, drift_model_path)
    mlflow.log_artifact(drift_model_path)

    # Generate drift predictions
    drift_model = load_detector(drift_model_path)
    drift_output = drift_model.predict(
        X_test[drift_column_names].values, drift_type="feature", return_p_val=True, return_distance=True)

    # Display drift output
    pprint(process_drift_output(drift_output,
           drift_column_names), width=120, compact=True)

    # End run
    mlflow.end_run()

# COMMAND ----------

# MAGIC %md
# MAGIC 
# MAGIC #### Build outlier model
# MAGIC 
# MAGIC A statistical model will be built to determine outliers in numeric features.

# COMMAND ----------


# Develop outlier model using isolation forests
def make_outlier_model(X, **params):
    outlier_model = IForest(**params)
    outlier_model.fit(X)
    return outlier_model

# Preprocess output of outlier model
def process_outlier_output(output, column_names):
    return {
        "is_outlier": dict(zip(column_names, output["data"]["is_outlier"].tolist())),
    }


with mlflow.start_run(run_name="employee-attrition-outlier") as run:
    # Develop outlier model
    outlier_model = make_outlier_model(
        X_train[columns_numeric].values, threshold=5)

    # Log model to mlflow run
    outlier_model_path = "/tmp/models/outlier"
    save_detector(outlier_model, outlier_model_path)
    mlflow.log_artifact(outlier_model_path)

    # Generate outlier predictions
    outlier_model = load_detector(outlier_model_path)
    outlier_output = outlier_model.predict(X_test[columns_numeric].values)

    # Display outlier output
    pprint(process_outlier_output(outlier_output,
           columns_numeric), width=120, compact=True)

    # End run
    mlflow.end_run()

# COMMAND ----------

# MAGIC %md
# MAGIC 
# MAGIC #### Register MLFlow Model Artifact
# MAGIC 
# MAGIC Develop a `python_function` model object which references the classifer, drift model, and outlier model. This model artifact will be deployed as a web service.

# COMMAND ----------


class EmployeeAttritionModel(mlflow.pyfunc.PythonModel):
    """
    Class containing attrition use-case models - attrition classifer, drift model, and outlier model.
    """

    def __init__(self, columns_categorical: list, columns_numeric: list):
        self.columns_categorical = columns_categorical
        self.columns_numeric = columns_numeric

    def load_context(self, context):
        self.classifier = joblib.load(os.path.join(
            context.artifacts["artifacts_path"], "classifier/model/model.pkl"))
        self.drift_model = load_detector(os.path.join(
            context.artifacts["artifacts_path"], "drift"))
        self.outier_model = load_detector(os.path.join(
            context.artifacts["artifacts_path"], "outlier"))

    def generate_output(self, model_predictions: np.array, drift_output: dict, outlier_output: dict):
        return {
            "classifier__predictions": model_predictions.tolist(),
            "drift__threshold": drift_output["data"]["threshold"],
            "drift__is_drift": dict(zip(columns_categorical + columns_numeric, drift_output["data"]["is_drift"].tolist())),
            "drift__p_value": dict(zip(columns_categorical + columns_numeric, drift_output["data"]["p_val"].tolist())),
            "drift__magnitude": dict(zip(columns_categorical + columns_numeric, (1 - drift_output["data"]["p_val"]).tolist())),
            "outliers__is_outlier": dict(zip(columns_numeric, outlier_output["data"]["is_outlier"].tolist())),
        }

    def predict(self, context, model_input):
        # Generate predictions, drift results, and  outlier results
        predictions = self.classifier.predict_proba(model_input)[:, 1]
        drift_output = self.drift_model.predict(
            model_input[drift_column_names].values, drift_type="feature", return_p_val=True, return_distance=True)
        outlier_output = self.outier_model.predict(
            model_input[columns_numeric].values)

        return self.generate_output(predictions, drift_output, outlier_output)

# COMMAND ----------


with mlflow.start_run(run_name="employee-attrition-model-artifact") as run:
    # Define conda environment
    mlflow_conda_env = {
        'name': "employee-attrition-env",
        'channels': ["defaults"],
        'dependencies': [
            "python=3.8.10",
            {
                "pip": [
                    "alibi-detect==0.8.1",
                    "mlflow-skinny==1.21.0",
                    "scikit-learn",
                    "numpy==1.19.2",
                    "pandas==1.2.4",
                    "scikit-learn==0.24.1"
                ]
            }
        ]
    }

    # Create instance of model
    model_artifact = EmployeeAttritionModel(
        columns_categorical=columns_categorical,
        columns_numeric=columns_numeric
    )

    # Create model signature
    y_pred_proba = joblib.load(
        "/tmp/models/classifier/model/model.pkl").predict_proba(X_test)
    signature = infer_signature(X_train)
    
    # Log model
    mlflow.pyfunc.log_model(
        artifact_path="employee-attrition-model",
        python_model=model_artifact,
        artifacts={"artifacts_path": "/tmp/models"},
        conda_env=mlflow_conda_env,
        signature=signature
    )

    # End run
    mlflow.end_run()

# COMMAND ----------

# Register drift model to MLFlow model registry
registered_attrition_model = mlflow.register_model(
    f"runs:/{run.info.run_id}/employee-attrition-model",
    "employee_attrition"
)

# COMMAND ----------

# Load model from MLFlow model registry
loaded_attrition_model = mlflow.pyfunc.load_model(
    f"models:/{registered_attrition_model.name}/{registered_attrition_model.version}")

# Display output
model_output = loaded_attrition_model.predict(X_test.head(5))
pprint(model_output, width=120, compact=True)

# COMMAND ----------


