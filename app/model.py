"""Data model for loan applicant"""

import dataclasses

from pydantic import BaseModel


@dataclasses.dataclass
class LoanApplicant(BaseModel):
    """Load applicant data model"""

    sex: str = "male"
    education: str = "university"
    marriage: str = "married"
    repayment_status_1: str = "duly_paid"
    repayment_status_2: str = "duly_paid"
    repayment_status_3: str = "duly_paid"
    repayment_status_4: str = "duly_paid"
    repayment_status_5: str = "no_delay"
    repayment_status_6: str = "no_delay"
    credit_limit: float = 18000.0
    age: float = 18000.0
    bill_amount_1: float = 764.95
    bill_amount_2: float = 2221.95
    bill_amount_3: float = 1131.85
    bill_amount_4: float = 5074.85
    bill_amount_5: float = 18000.0
    bill_amount_6: float = 1419.95
    payment_amount_1: float = 2236.5
    payment_amount_2: float = 1137.55
    payment_amount_3: float = 5084.55
    payment_amount_4: float = 111.65
    payment_amount_5: float = 306.9
    payment_amount_6: float = 805.65


@dataclasses.dataclass
class FeatureBatchDrift(BaseModel):
    sex: float
    education: float
    marriage: float
    repayment_status_1: float
    repayment_status_2: float
    repayment_status_3: float
    repayment_status_4: float
    repayment_status_5: float
    repayment_status_6: float
    credit_limit: float
    age: float
    bill_amount_1: float
    bill_amount_2: float
    bill_amount_3: float
    bill_amount_4: float
    bill_amount_5: float
    bill_amount_6: float
    payment_amount_1: float
    payment_amount_2: float
    payment_amount_3: float
    payment_amount_4: float
    payment_amount_5: float
    payment_amount_6: float


@dataclasses.dataclass
class ModelOutput(BaseModel):
    """Model output data model"""

    predictions: list[float]
    outliers: list[float]
    feature_drift_batch: FeatureBatchDrift
