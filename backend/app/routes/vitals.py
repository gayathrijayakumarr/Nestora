from fastapi import APIRouter
from app.services.mock_data import MOCK_VITALS
from app.services.bp_store import add_bp, get_bp, latest_bp
from app.services.live_store import save_live, get_live, merge_into_vitals

router = APIRouter()


@router.get("/{patient_id}")
def get_vitals(patient_id: str):
    return MOCK_VITALS.get(patient_id, [])


@router.get("/{patient_id}/latest")
def get_latest_vital(patient_id: str):
    """Latest reading. Wearable fields overlay the record when a fresh
    live reading exists; BP comes from the manual log, never the band."""
    vitals = MOCK_VITALS.get(patient_id, [])
    base = dict(vitals[0]) if vitals else {
        "id": f"V{patient_id}_0",
        "patient_id": patient_id,
        "spo2": 97,
        "systolic_bp": 120,
        "diastolic_bp": 80,
        "steps": 0,
        "source": "none",
    }
    # manual BP (mother-entered) takes precedence over mock BP
    bp = latest_bp(patient_id)
    if bp:
        base["systolic_bp"] = bp["systolic_bp"]
        base["diastolic_bp"] = bp["diastolic_bp"]
        base["bp_source"] = bp["source"]
        base["bp_logged_at"] = bp["logged_at"]
    else:
        base["bp_source"] = None
        base["bp_logged_at"] = None

    live = get_live(patient_id)
    if live:
        base = merge_into_vitals(live, base)
    # No temperature in this prototype: the wearable cannot measure it.
    base.pop("temperature", None)
    return base


@router.post("/live")
def ingest_live_vitals(data: dict):
    """Wearable gateway ingestion (Flutter POSTs BLE readings here)."""
    return save_live(data)


@router.post("/ingest")
def ingest_live_vitals_alias(data: dict):
    return save_live(data)


@router.get("/{patient_id}/bp")
def list_bp(patient_id: str):
    return get_bp(patient_id)


@router.post("/{patient_id}/bp")
def log_bp(patient_id: str, data: dict):
    """Mother records BP from a home/external monitor."""
    try:
        sys_v = int(data.get("systolic_bp", 0))
        dia_v = int(data.get("diastolic_bp", 0))
    except (TypeError, ValueError):
        return {"error": "Invalid blood pressure values"}
    if not (60 <= sys_v <= 250 and 30 <= dia_v <= 160):
        return {"error": "Blood pressure out of possible range"}
    return add_bp(patient_id, sys_v, dia_v,
                  source=data.get("source", "manual"),
                  note=data.get("note", ""))