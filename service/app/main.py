import json
import logging
import uuid
from typing import List

import pandas as pd
from fastapi import FastAPI
from fastapi.encoders import jsonable_encoder
from mlflow.pyfunc import load_model

from app.core.models.employee_attrition_record import EmployeeAttritionRecord

# Define global variables
SERVICE_NAME = "Employee Attrition API"
MODEL_ARTIFACT_PATH = "./employee_attrition_model"

# Initialize the FastAPI app
app = FastAPI(title=SERVICE_NAME, docs_url="/")

# Configure logger
log = logging.getLogger("uvicorn")
log.setLevel(logging.INFO)


@app.on_event("startup")
async def startup_load_model():
    """
    A startup event handler to load an MLFLow model.
    """
    global MODEL
    MODEL = load_model(MODEL_ARTIFACT_PATH)


@app.post("/predict")
async def predict(data: List[EmployeeAttritionRecord]):
    """
    An inference API to generate predictions and monitoring results.

    Parameters:
        request (List[Record]): Web service request containing inference data.

    Returns:
        response_payload (str): JSON string containing model predictions
        and drift / outlier results for monitoring.
    """

    # Parse data
    input_df = pd.DataFrame(jsonable_encoder(data))

    # Define UUID for the request
    request_id = uuid.uuid4().hex

    # Log input data
    log.info(json.dumps({
        "service_name": SERVICE_NAME,
        "type": "InputData",
        "request_id": request_id,
        "data": input_df.to_json(orient='records'),
    }))

    # Make predictions and log
    model_output = MODEL.predict(input_df)

    # Log output data
    log.info(json.dumps({
        "service_name": SERVICE_NAME,
        "type": "OutputData",
        "request_id": request_id,
        "data": model_output
    }))

    # Make response payload
    response_payload = jsonable_encoder(model_output)

    return response_payload
