"""Main module for the FastAPI application."""

import json
import logging
import os
import uuid
from contextlib import asynccontextmanager
from typing import AsyncGenerator, List

import mlflow
import pandas as pd
import uvicorn
from fastapi import FastAPI
from fastapi.encoders import jsonable_encoder
from model import LoanApplicant

# Initialize the ML models
ml_models = {}


@asynccontextmanager
async def lifespan() -> AsyncGenerator[None, None]:
    """
    A context manager to initialize and clean up the ML models.
    """
    # Load the ML model
    ml_models["credit_default"] = mlflow.pyfunc.load_model("./model")
    yield
    # Clean up the ML models and release the resources
    ml_models.clear()


# Initialize the FastAPI app
app = FastAPI(
    title=os.environ.get("SERVICE_NAME", "credit-default-api"),
    docs_url="/",
    lifespan=lifespan,
)


@app.post("/predict")
async def predict(data: List[LoanApplicant]) -> str:
    """
    An endpoint to make predictions on the input data.

    Parameters:
        request (List[LoanApplicant]): A list of loan applicant data.

    Returns:
        response (str): A JSON response containing the model predictions.
    """

    # Parse data
    input_df = pd.DataFrame(jsonable_encoder(data))

    # Define UUID for the request
    request_id = uuid.uuid4().hex

    # Log input data
    logging.info(
        json.dumps(
            {
                "service_name": os.environ.get("SERVICE_NAME", "credit-default-api"),
                "type": "InputData",
                "request_id": request_id,
                "data": input_df.to_json(orient="records"),
            }
        )
    )

    # Make predictions and log
    model_output = ml_models["credit_default"].predict(input_df)

    # Log output data
    logging.info(
        json.dumps(
            {
                "service_name": os.environ.get("SERVICE_NAME", "credit-default-api"),
                "type": "OutputData",
                "request_id": request_id,
                "data": model_output,
            }
        )
    )

    # Make response payload
    response_payload = jsonable_encoder(model_output)

    return response_payload


# Configure logging
logging.basicConfig(level=logging.INFO)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
