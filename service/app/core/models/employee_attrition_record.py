from pydantic import BaseModel


class EmployeeAttritionRecord(BaseModel):
    BusinessTravel: str = "Travel_Rarely"
    Department: str = "Research & Development"
    EducationField: str = "Medical"
    Gender: str = "Female"
    JobRole: str = "Manager"
    MaritalStatus: str = "Married"
    Over18: str = "Yes"
    OverTime: str = "No"
    Age: float = 40.0
    DailyRate: float = 989.0
    DistanceFromHome: float = 4.0
    Education: float = 1.0
    EmployeeCount: float = 1.0
    EmployeeNumber: float = 253.0
    EnvironmentSatisfaction: float = 4.0
    HourlyRate: float = 46.0
    JobInvolvement: float = 3.0
    JobLevel: float = 5.0
    JobSatisfaction: float = 3.0
    MonthlyIncome: float = 19033.0
    MonthlyRate: float = 6499.0
    NumCompaniesWorked: float = 1.0
    PercentSalaryHike: float = 14.0
    PerformanceRating: float = 3.0
    RelationshipSatisfaction: float = 2.0
    StandardHours: float = 80.0
    StockOptionLevel: float = 1.0
    TotalWorkingYears: float = 21.0
    TrainingTimesLastYear: float = 2.0
    WorkLifeBalance: float = 3.0
    YearsAtCompany: float = 3.0
    YearsInCurrentRole: float = 8.0
    YearsSinceLastPromotion: float = 9.0
    YearsWithCurrManager: float = 9.0
