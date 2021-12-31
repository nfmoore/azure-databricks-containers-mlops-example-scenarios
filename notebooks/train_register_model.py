# Databricks notebook source
# MAGIC %md
# MAGIC # Train and Register Model
# MAGIC
# MAGIC The aim of this notebook is to train and register an MLFlow model to be deployed. This example uses a dataset from the UCI Machine Learning Repository available [here](https://archive.ics.uci.edu/ml/machine-learning-databases/wine-quality/). This notebook has been adapted from an tutorial notebook in the Databricks documentation available [here](https://docs.databricks.com/applications/mlflow/end-to-end-example.html). The machine learning model in this notebook (called `wine_quality`) will predict the quality of Portugese "Vinho Verde" wine based on the wine's physicochemical properties.

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Import and process data

# COMMAND ----------

import types
from io import StringIO
from pprint import pprint

import mlflow.xgboost
import numpy as np
import pandas as pd
import requests
import xgboost as xgb
from alibi_detect.cd import TabularDrift
from alibi_detect.od.isolationforest import IForest
from alibi_detect.utils.data import create_outlier_batch
from hyperopt import STATUS_OK, fmin, hp, tpe
from hyperopt.pyll import scope
from mlflow.models.signature import infer_signature
from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.compose import ColumnTransformer
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

# Make http requests for each dataset
base_url = "https://archive.ics.uci.edu/ml/machine-learning-databases/wine-quality/"
red_wine_response = requests.get(f"{base_url}/winequality-red.csv")
white_wine_response = requests.get(f"{base_url}/winequality-white.csv")

# Use StringIO to create object file
red_wine_object = StringIO(red_wine_response.content.decode("utf-8"))
white_wine_object = StringIO(white_wine_response.content.decode("utf-8"))

# Convert to pandas dataframe
df_red_wine = pd.read_csv(red_wine_object, sep=";")
df_white_wine = pd.read_csv(white_wine_object, sep=";")

# COMMAND ----------

# Add wine type column
df_red_wine["is red"] = 1
df_white_wine["is red"] = 0

# Combine datasets
df = pd.concat([df_red_wine, df_white_wine], axis=0).rename(
    columns=lambda x: x.replace(" ", "_")
)

# Preprocess data
df["quality"] = (df.quality >= 7).astype(int)

# COMMAND ----------

# Split into train and test datasets
train, test = train_test_split(df, random_state=1)
X_train = train.drop(["quality"], axis=1)
X_test = test.drop(["quality"], axis=1)
y_train = train.quality
y_test = test.quality

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Build prediction model

# COMMAND ----------

search_space = {
    "max_depth": scope.int(hp.quniform("max_depth", 4, 100, 1)),
    "learning_rate": hp.loguniform("learning_rate", -3, 0),
    "reg_alpha": hp.loguniform("reg_alpha", -5, -1),
    "reg_lambda": hp.loguniform("reg_lambda", -6, -1),
    "min_child_weight": hp.loguniform("min_child_weight", -1, 3),
    "objective": "binary:logistic",
    "seed": 1,
}


def train_model(params):
    # Set MLflow autologging
    mlflow.xgboost.autolog()

    with mlflow.start_run(nested=True):
        # Convert train test data to xgb matrix
        train = xgb.DMatrix(data=X_train, label=y_train)
        test = xgb.DMatrix(data=X_test, label=y_test)

        # Train model
        booster = xgb.train(
            params=params,
            dtrain=train,
            num_boost_round=1000,
            evals=[(test, "test")],
            early_stopping_rounds=50,
        )

        # Evaluate model
        predictions_test = booster.predict(test)
        auc_score = roc_auc_score(y_test, predictions_test)
        mlflow.log_metric("auc", auc_score)

        # Log model artifact
        signature = infer_signature(X_train, booster.predict(train))
        mlflow.xgboost.log_model(booster, "model", signature=signature)

        return {
            "status": STATUS_OK,
            "loss": -1 * auc_score,
            "booster": booster.attributes(),
        }


# Start run
with mlflow.start_run(run_name="wine-quality-classifier"):
    best_params = fmin(
        fn=train_model,
        space=search_space,
        algo=tpe.suggest,
        max_evals=32,
        rstate=np.random.RandomState(1),
    )

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Register and test prediction model

# COMMAND ----------

# Register model to MLFlow model registry
model_name = "wine_quality"
best_run = mlflow.search_runs(order_by=["metrics.auc DESC"]).iloc[0]
best_model = mlflow.register_model(
    f"runs:/{best_run.run_id}/model", model_name)

print(f'AUC of best model: {best_run["metrics.auc"]}')

# COMMAND ----------

# Load model from MLFlow model registry
model = mlflow.pyfunc.load_model(
    f"models:/{best_model.name}/{best_model.version}")

# Display model input data
pprint({"data": X_test.head(5).values.tolist()}, width=120, compact=True)

# Make model predictions
predictions = model.predict(X_test.head(5))

# Display model predictions
pprint(
    {"predictions": (predictions > 0.5).astype(np.int).tolist()},
    width=120,
    compact=True,
)

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Register and test outlier and drift monitoring models

# COMMAND ----------


# Define fit method to add to TabularDrift instance for compatability with sklearn Pipeline object
def fit(self, X, y=None, classes=None, **fit_params):
    self.x_ref = X
    return self


with mlflow.start_run(run_name="wine-quality-classifier") as run:

    # Develop drift model using Kolmogorov-Smirnov (K-S) tests for the continuous numerical features and Chi-Squared tests for the categorical features
    categories_per_feature = {11: 2}
    drift_model = TabularDrift(
        X_train.values, p_val=0.05, categories_per_feature=categories_per_feature)
    drift_model.fit = types.MethodType(fit, drift_model)

    # Develop outlier model using isolation forests
    outlier_model = IForest(threshold=5)

    # Define column names
    column_names = ["fixed_acidity", "volatile_acidity", "citric_acid", "residual_sugar", "chlorides",
                    "free_sulfur_dioxide", "total_sulfur_dioxide", "density", "pH", "sulphates", "alcohol", "is_red"]

    # Develop scaler to remove the mean and scale to unit variance for numeric features
    scaler = StandardScaler()
    column_transformer = ColumnTransformer([("scaler", scaler, slice(
        0, column_names.index("is_red") - 1))], remainder="passthrough")

    # Define drift pipeline
    drift_model_pipeline = Pipeline([
        ("scaler", column_transformer),
        ("drift", drift_model)
    ])

    # Define outlier pipeline
    outlier_model_pipeline = Pipeline([
        ("scaler", column_transformer),
        ("outliers", outlier_model)
    ])

    # Define reference data
    X_ref = X_train[column_names].values

    # Fit drift / outlier model pipelines
    drift_model_pipeline = drift_model_pipeline.fit(X_ref)
    outlier_model_pipeline = outlier_model_pipeline.fit(X_ref)

    # Log model
    mlflow.sklearn.log_model(
        drift_model_pipeline, "drift_model")
    mlflow.sklearn.log_model(
        outlier_model_pipeline, "outlier_model")

    # End run
    mlflow.end_run()

# COMMAND ----------

# Register drift model to MLFlow model registry
drift_model = mlflow.register_model(
    f"runs:/{run.info.run_id}/drift_model",
    f"{model_name}_drift"
)

# Register outlier model to MLFlow model registry
outlier_model = mlflow.register_model(
    f"runs:/{run.info.run_id}/outlier_model",
    f"{model_name}_outlier"
)

# COMMAND ----------

# Load drift model from MLFlow model registry
drift_model_pipeline = mlflow.sklearn.load_model(
    f"models:/{drift_model.name}/{drift_model.version}")

# Load outlier model from MLFlow model registry
outlier_model_pipeline = mlflow.sklearn.load_model(
    f"models:/{outlier_model.name}/{outlier_model.version}")

# COMMAND ----------

# Define and scale inference / test values
X_inf = X_test[column_names].values

# Generate drift  / outlier predictions
drift_model_predictions = drift_model_pipeline.predict(
    X_inf, drift_type="feature")
outlier_model_predictions = outlier_model_pipeline.predict(X_inf)

# Display results
output = {
    "drift": {
        "threshold": drift_model_predictions["data"]["threshold"],
        "is_drift": dict(zip(column_names, drift_model_predictions["data"]["is_drift"])),
        "p_value": dict(zip(column_names, drift_model_predictions["data"]["p_val"]))
    },
    "outliers": {
        "is_outlier": dict(zip(column_names, outlier_model_predictions["data"]["is_outlier"]))
    }
}

pprint(output, width=120, compact=True)

# COMMAND ----------
