from fastapi import APIRouter
from app.services.mock_data import MOCK_VITALS, MOCK_SYMPTOMS
from app.services.patients_store import MOCK_PATIENTS, current_week
from app.services.bp_store import latest_bp
from app.services.risk_engine import calculate_risk
from app.services.live_store import get_live, merge_into_vitals

router = APIRouter()


def _patient_week(patient_id: str):
    for p in MOCK_PATIENTS:
        if p["id"] == patient_id:
            return current_week(p)
    return None


def _effective_vitals(patient_id: str) -> dict:
    """Single source of truth for what the engine scores.

    Order of precedence: live wearable reading > manual BP log >
    mock record. Temperature is never included (no sensor).
    """
    vitals_list = MOCK_VITALS.get(patient_id, [])
    base = dict(vitals_list[0]) if vitals_list else {
        "id": f"V{patient_id}_0",
        "patient_id": patient_id,
        "spo2": 97,
        "systolic_bp": 120,
        "diastolic_bp": 80,
        "steps": 0,
        "source": "none",
    }
    bp = latest_bp(patient_id)
    if bp:
        base["systolic_bp"] = bp["systolic_bp"]
        base["diastolic_bp"] = bp["diastolic_bp"]
        base["bp_source"] = bp["source"]
        base["bp_logged_at"] = bp["logged_at"]
    live = get_live(patient_id)
    if live:
        base = merge_into_vitals(live, base)
    base.pop("temperature", None)
    return base


@router.get("/{patient_id}")
def get_risk(patient_id: str):
    symptoms_list = MOCK_SYMPTOMS.get(patient_id, [])
    latest = _effective_vitals(patient_id)
    if not latest.get("heart_rate") and not latest.get("spo2"):
        return {
            "risk_level": "low",
            "score": 0,
            "factors": ["No data available"],
            "recommendation": "Start monitoring to get risk assessment.",
            "gestational_week": _patient_week(patient_id),
        }
    return calculate_risk(latest, symptoms_list, _patient_week(patient_id))


@router.post("/evaluate")
def evaluate_risk(data: dict):
    patient_id = data.get("patient_id", "P001")
    symptoms_list = MOCK_SYMPTOMS.get(patient_id, [])
    latest = _effective_vitals(patient_id)
    if not latest:
        return {"risk_level": "low", "score": 0, "factors": ["No data"],
                "recommendation": "No data available."}
    return calculate_risk(latest, symptoms_list, _patient_week(patient_id))


@router.post("/assess")
def assess_risk(data: dict):
    """Direct assessment from supplied readings.

    Body: {patient_id?, heart_rate?, spo2?, systolic_bp?,
           diastolic_bp?, gestational_week?, symptoms? [...]}.
    Missing fields fall back to the patient's effective record; absent
    sensors score nothing (null != zero).
    """
    patient_id = data.get("patient_id", "P001")
    vitals = dict(_effective_vitals(patient_id))
    for key in ("heart_rate", "spo2", "systolic_bp", "diastolic_bp",
                "gestational_week"):
        if data.get(key) is not None:
            vitals[key] = data[key]

    symptoms = data.get("symptoms")
    if symptoms is None:
        symptoms = MOCK_SYMPTOMS.get(patient_id, [])

    week = data.get("gestational_week", _patient_week(patient_id))
    return calculate_risk(vitals, symptoms, week)