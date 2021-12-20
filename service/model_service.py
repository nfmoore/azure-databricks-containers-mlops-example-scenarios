import logging
import uuid

import numpy as np
import pandas as pd
from bentoml import BentoService, api, artifacts, env
from bentoml.adapters import DataframeInput
from bentoml.frameworks.xgboost import XgboostModelArtifact
from xgboost import DMatrix


@env(infer_pip_packages=True)
@artifacts([XgboostModelArtifact('model')])
class WineQualityService(BentoService):

    def generate_predictions(self, df: pd.DataFrame):
        # Pre-process data
        data = DMatrix(data=df)

        # Make predictions
        predictions = self.artifacts.model.predict(data)
        # Transform predictions
        transformed_predictions = (predictions > 0.5).astype(np.int).tolist()

        return transformed_predictions

    @api(input=DataframeInput(
        orient="records",
        columns=["fixed_acidity", "volatile_acidity", "citric_acid",
                 "residual_sugar", "chlorides", "free_sulfur_dioxide",
                 "total_sulfur_dioxide", "density", "pH", "sulphates",
                 "alcohol", "is_red"]),
         batch=True
         )
    def predict(self, df: pd.DataFrame):
        """
        An inference API named `predict` with Dataframe input adapter,
        which codifies how HTTP requests or CSV files are converted to a
        pandas Dataframe object as the inference API function input
        """
        # Setup bentoml logger
        logger = logging.getLogger('bentoml')

        # Define UUID for the request
        request_id = uuid.uuid4().hex

        # Log input data
        logger.info({
            "service_name": type(self).__name__,
            "type": "input_data",
            "value": df.to_json(orient='records'),
            "request_id": request_id
        })

        # Generate predictions
        result = self.generate_predictions(df)

        # Log output data
        logger.info({
            "service_name": type(self).__name__,
            "type": "output_data",
            "value": result,
            "request_id": request_id
        })

        return result
