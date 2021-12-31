import sys
from argparse import ArgumentParser

import mlflow
from bentoml import save_to_dir

from model_service import WineQualityService


def parse_args(argv):
    ap = ArgumentParser("package_model_service")
    ap.add_argument("--mlflow-prediction-model-artifiact-path", required=True)
    ap.add_argument("--mlflow-drift-model-artifiact-path", required=True)
    ap.add_argument("--mlflow-outlier-model-artifiact-path", required=True)
    ap.add_argument("--package-path", required=True)

    args, _ = ap.parse_known_args(argv)
    return args


def main():
    # Parse command line arguments
    args = parse_args(sys.argv[1:])

    # Load MLFlow models
    mlflow_loaded_prediction_model = mlflow.xgboost.load_model(
        args.mlflow_prediction_model_artifiact_path)
    mlflow_loaded_drift_model = mlflow.sklearn.load_model(
        args.mlflow_drift_model_artifiact_path)
    mlflow_loaded_outlier_model = mlflow.sklearn.load_model(
        args.mlflow_outlier_model_artifiact_path)

    # Create service instance
    model_service = WineQualityService()

    # Package model artifact
    model_service.pack("prediction_model", mlflow_loaded_prediction_model)
    model_service.pack("drift_model", mlflow_loaded_drift_model)
    model_service.pack("outlier_model", mlflow_loaded_outlier_model)

    # Save the service to disk for model serving
    save_to_dir(
        model_service, path=args.package_path, silent=True)


if __name__ == "__main__":
    main()
