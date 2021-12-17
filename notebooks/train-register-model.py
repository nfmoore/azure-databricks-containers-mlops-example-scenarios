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

import requests
import pandas as pd
from io import StringIO

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
df = pd.concat([df_red_wine, df_white_wine], axis=0)\
    .rename(columns=lambda x: x.replace(' ', '_'))

# Preprocess data
df["quality"] = (df.quality >= 7).astype(int)

# COMMAND ----------

from sklearn.model_selection import train_test_split
 
# Split into train and test datasets
train, test = train_test_split(df, random_state=1)
X_train = train.drop(["quality"], axis=1)
X_test = test.drop(["quality"], axis=1)
y_train = train.quality
y_test = test.quality

# COMMAND ----------

# MAGIC %md
# MAGIC 
# MAGIC ## Build model

# COMMAND ----------

from hyperopt import fmin, tpe, hp, SparkTrials, Trials, STATUS_OK
from hyperopt.pyll import scope
import mlflow.xgboost
from mlflow.models.signature import infer_signature
import numpy as np
import xgboost as xgb
from sklearn.metrics import roc_auc_score

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
            early_stopping_rounds=50
        )
        
        # Evaluate model
        predictions_test = booster.predict(test)
        auc_score = roc_auc_score(y_test, predictions_test)
        mlflow.log_metric("auc", auc_score)

        # Log model artifact
        signature = infer_signature(X_train, booster.predict(train))
        mlflow.xgboost.log_model(booster, "model", signature=signature)

        return {"status": STATUS_OK, "loss": -1*auc_score, "booster": booster.attributes()}

# Start run
with mlflow.start_run(run_name="wine-quality-classifier"):
        best_params = fmin(
        fn=train_model, 
        space=search_space, 
        algo=tpe.suggest, 
        max_evals=32,
        rstate=np.random.RandomState(1)
    )

# COMMAND ----------

# MAGIC %md
# MAGIC 
# MAGIC ## Register and test model

# COMMAND ----------

# Register model to MLFlow model registry
model_name = "wine_quality"
best_run = mlflow.search_runs(order_by=['metrics.auc DESC']).iloc[0]
best_model = mlflow.register_model(f"runs:/{best_run.run_id}/model", model_name)

print(f'AUC of best model: {best_run["metrics.auc"]}')

# COMMAND ----------

from pprint import pprint

# Load model from MLFlow model registry
model = mlflow.pyfunc.load_model(f"models:/{best_model.name}/{best_model.version}")

# Display model input data
pprint({"data": X_test.head(5).values.tolist()}, width=120, compact=True)

# Make model predictions
predictions = model.predict(X_test.head(5))

# Display model predictions
pprint({"predictions": (predictions > 0.5).astype(np.int).tolist()}, width=120, compact=True)

# COMMAND ----------


