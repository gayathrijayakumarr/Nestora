from fastapi import APIRouter
from app.services.patients_store import (
    MOCK_PATIENTS, authenticate, enroll, find_by_id, current_week,
    DEMO_PATIENT_ID,
)

router = APIRouter()


@router.get("/")
def get_all_patients():
    out = []
    for p in MOCK_PATIENTS:
        item = dict(p)
        item["gestational_week"] = current_week(p)
        out.append(item)
    return out


@router.get("/{patient_id}")
def get_patient(patient_id: str):
    p = find_by_id(patient_id)
    if not p:
        return {"error": "Patient not found"}
    item = dict(p)
    item["gestational_week"] = current_week(p)
    return item


@router.post("/")
def enroll_patient(data: dict):
    """Doctor-side enrolment. Creates the patient id used for app login."""
    patient, err = enroll(
        name=data.get("name", ""),
        phone=data.get("phone", ""),
        age=data.get("age", 25),
        gestational_week=data.get("gestational_week", 0),
        due_date=data.get("due_date"),
        blood_group=data.get("blood_group", ""),
        height_cm=data.get("height_cm"),
        weight_kg=data.get("weight_kg"),
        assigned_doctor=data.get("assigned_doctor", "D001"),
    )
    if err:
        return {"error": err}
    item = dict(patient)
    item["gestational_week"] = current_week(patient)
    return item


@router.get("/{patient_id}/summary")
def patient_summary(patient_id: str):
    """Single call the app uses on login: profile + current week."""
    p = find_by_id(patient_id)
    if not p:
        return {"error": "Patient not found"}
    item = dict(p)
    item["gestational_week"] = current_week(p)
    return item