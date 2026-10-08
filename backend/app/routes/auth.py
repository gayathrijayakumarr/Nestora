from fastapi import APIRouter
from app.services.patients_store import authenticate, current_week, find_by_id

router = APIRouter()


@router.post("/login")
def login(data: dict):
    """Enrolment-gated login.

    Mothers do not self-register: a doctor enrols them on the dashboard
    first. Unknown numbers are rejected with a clear message.
    """
    patient, err = authenticate(data.get("name", ""), data.get("phone", ""))
    if err:
        return {"ok": False, "error": err}
    profile = dict(patient)
    profile["gestational_week"] = current_week(patient)
    return {
        "ok": True,
        "patient_id": patient["id"],
        "name": patient["name"],
        "age": patient["age"],
        "phone": patient["phone"],
        "gestational_week": profile["gestational_week"],
        "due_date": patient["due_date"],
        "blood_group": patient.get("blood_group", ""),
        "risk_level": patient.get("risk_level", "low"),
    }