"""Main module for the FastAPI application."""

import json
import logging
import os
import uuid
from typing import AsyncGenerator

import mlflow
import pandas as pd
import uvicorn
from fastapi import FastAPI
from fastapi.concurrency import asynccontextmanager
from model import LoanApplicant, ModelOutput

# Initialize the ML models
ml_models = {}


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """
    A context manager to initialize and clean up the ML models.
    """
    # Load the ML model
    ml_models["credit_default"] = mlflow.pyfunc.load_model(
        os.getenv("MODEL_DIRECTORY", "./app/model")
    )
    yield
    # Clean up the ML models and release the resources
    ml_models.clear()


# Initialize the FastAPI app
app = FastAPI(
    title=os.environ.get("SERVICE_NAME", "credit-default-api"),
    docs_url="/",
    lifespan=lifespan,
)


@app.post("/predict", response_model=ModelOutput)
async def predict(data: list[LoanApplicant]) -> str:
    """
    An endpoint to make predictions on the input data.

    Parameters:
        request (List[LoanApplicant]): A list of loan applicant data.

    Returns:
        response (str): A JSON response containing the model predictions.
    """
    # Parse data
    input_df = pd.DataFrame(data)

    # Define UUID for the request
    request_id = uuid.uuid4().hex

    # Log inference data
    logging.info(
        json.dumps(
            {
                "service_name": os.environ.get("SERVICE_NAME", "credit-default-api"),
                "type": "InferenceData",
                "request_id": request_id,
                "data": input_df.to_json(orient="records"),
            }
        )
    )

    # Generate predictions
    model_output = ml_models["credit_default"].predict(input_df)

    # Log model outputs
    logging.info(
        json.dumps(
            {
                "service_name": os.environ.get("SERVICE_NAME", "credit-default-api"),
                "type": "ModelOutput",
                "request_id": request_id,
                "data": model_output,
            }
        )
    )

    return model_output


# Configure logging
logging.basicConfig(level=logging.INFO)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
