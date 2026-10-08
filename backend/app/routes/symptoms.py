from fastapi import APIRouter
from datetime import datetime
from app.services.mock_data import MOCK_SYMPTOMS

router = APIRouter()


@router.get("/{patient_id}")
def get_symptoms(patient_id: str):
    return MOCK_SYMPTOMS.get(patient_id, [])


@router.post("/")
def add_symptom(data: dict):
    patient_id = data.get("patient_id", "P001")
    entry = {
        "id": f"S{patient_id}_{len(MOCK_SYMPTOMS.get(patient_id, [])) + 1}",
        "patient_id": patient_id,
        "symptom_type": data.get("symptom_type", "Other"),
        "severity": int(data.get("severity", 1)),
        "description": data.get("description", ""),
        "timestamp": datetime.now().isoformat(),
        "ai_flagged": bool(data.get("ai_flagged", False)),
    }
    MOCK_SYMPTOMS.setdefault(patient_id, []).insert(0, entry)
    return entry
