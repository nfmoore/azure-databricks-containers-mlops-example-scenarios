import json
import logging
import uuid

import alibi_detect
import numpy as np
import pandas as pd
from bentoml import BentoService, api, artifacts, env
from bentoml.adapters import DataframeInput, JsonOutput
from bentoml.frameworks.sklearn import SklearnModelArtifact
from bentoml.frameworks.xgboost import XgboostModelArtifact
from xgboost import DMatrix

COLUMN_NAMES = [
    "fixed_acidity",
    "volatile_acidity",
    "citric_acid",
    "residual_sugar",
    "chlorides",
    "free_sulfur_dioxide",
    "total_sulfur_dioxide",
    "density",
    "pH",
    "sulphates",
    "alcohol",
    "is_red"
]


@env(
    infer_pip_packages=True,
    setup_sh="./service/setup.sh"
)
@artifacts([
    XgboostModelArtifact("prediction_model"),
    SklearnModelArtifact("drift_model"),
    SklearnModelArtifact("outlier_model")
])
class WineQualityService(BentoService):
    def generate_predictions(self, df: pd.DataFrame):
        # Preprocess data
        data = DMatrix(data=df)

        # Make predictions
        predictions = self.artifacts.prediction_model.predict(data)

        # Transform predictions
        transformed_predictions = (predictions > 0.5).astype(np.int).tolist()

        return transformed_predictions

    def generate_monitoring_results(self, df: pd.DataFrame):
        # Define feature / column names
        column_names = COLUMN_NAMES

        # Define inference / test values
        data = df[column_names].values

        # Generate drift  / outlier predictions
        drift_model_predictions = self.artifacts.drift_model.predict(
            data, drift_type="feature")
        outlier_model_predictions = self.artifacts.outlier_model.predict(data)

        monitoring_payload = {
            "drift": {
                "threshold": drift_model_predictions["data"]["threshold"],
                "is_drift": dict(
                    zip(column_names,
                        drift_model_predictions["data"]["is_drift"].tolist())),
                "p_value": dict(
                    zip(column_names,
                        drift_model_predictions["data"]["p_val"].tolist()))
            },
            "outliers": {
                "is_outlier": dict(
                    zip(column_names,
                        outlier_model_predictions["data"]["is_outlier"].tolist())),
                "instance_score": dict(
                    zip(column_names,
                        outlier_model_predictions["data"]["instance_score"].tolist())),
            }
        }

        return monitoring_payload

    @api(input=DataframeInput(
        orient="records",
        columns=COLUMN_NAMES),
        output=JsonOutput(),
        batch=True
    )
    def predict(self, df: pd.DataFrame):
        """
        An inference API to generate predictions and monitoring results.

        Parameters:
            df (pd.DataFrame): A pandas dataframe containing inference data.

        Returns:
            response_payload (str): JSON string containing model predictions
            and drift / outlier monitoring results.
        """
        # Setup bentoml logger
        logger = logging.getLogger('bentoml')

        # Define UUID for the request
        request_id = uuid.uuid4().hex

        # Log input data
        logger.info(json.dumps({
            "service_name": type(self).__name__,
            "type": "input_data",
            "value": df.to_json(orient='records'),
            "request_id": request_id
        }))

        # Generate predictions
        prediction_results = self.generate_predictions(df)
        monitoring_payload = self.generate_monitoring_results(df)

        # Log monitoring metrics
        logger.info(json.dumps({
            "service_name": type(self).__name__,
            "type": "monitoring_metrics",
            "monitoring": monitoring_payload,
            "request_id": request_id
        }))

        # Log output data
        logger.info(json.dumps({
            "service_name": type(self).__name__,
            "type": "output_data",
            "predictions": prediction_results,
            "monitoring": monitoring_payload,
            "request_id": request_id
        }))

        # Format response payload
        response_payload = [{
            "predictions": prediction_results,
            "monitoring": monitoring_payload,
        }]

        return response_payload
