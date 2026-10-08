from fastapi import APIRouter
from app.services.mock_data import MOCK_NUTRITION
from app.services.nutrition_guide import recommendations
from app.services.patients_store import find_by_id, current_week

router = APIRouter()


@router.get("/{patient_id}")
def get_nutrition(patient_id: str):
    """Week-based food suggestions for the patient's current week."""
    patient = find_by_id(patient_id)
    if not patient:
        return {"error": "Patient not found"}
    week = current_week(patient)
    guide = recommendations(week)
    intake = MOCK_NUTRITION.get(patient_id, {})
    guide["intake"] = intake
    return guide