from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class VitalCreate(BaseModel):
    patient_id: str
    heart_rate: int
    spo2: int
    temperature: float
    systolic_bp: int
    diastolic_bp: int
    activity_level: str = "moderate"
    steps: int = 0
    source: str = "wearable"


class VitalResponse(VitalCreate):
    id: str
    timestamp: str


class SymptomCreate(BaseModel):
    patient_id: str
    symptom_type: str
    severity: int
    description: str = ""


class SymptomResponse(SymptomCreate):
    id: str
    timestamp: str
    ai_flagged: bool = False


class ReminderCreate(BaseModel):
    patient_id: str
    title: str
    message: str
    reminder_type: str
    time: str
    recurring: bool = False


class ReminderResponse(ReminderCreate):
    id: str
    completed: bool = False
