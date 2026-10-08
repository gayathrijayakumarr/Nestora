"""Manual blood-pressure log (prototype).

The wearable cannot measure BP, so the mother records it herself from a
home BP monitor (or a clinic reading). Each entry keeps its timestamp so
the app and dashboard can say "lastly logged at ...".
"""

from datetime import datetime

# patient_id -> list of entries (newest first)
bp_records: dict[str, list[dict]] = {}


def add_bp(patient_id: str, systolic: int, diastolic: int,
           source: str = "manual", note: str = "") -> dict:
    entry = {
        "id": f"BP{len(bp_records.get(patient_id, [])) + 1}",
        "patient_id": patient_id,
        "systolic_bp": int(systolic),
        "diastolic_bp": int(diastolic),
        "source": source,  # manual | external_monitor
        "note": note,
        "logged_at": datetime.now().isoformat(),
    }
    bp_records.setdefault(patient_id, []).insert(0, entry)
    return entry


def get_bp(patient_id: str) -> list[dict]:
    return bp_records.get(patient_id, [])


def latest_bp(patient_id: str) -> dict | None:
    recs = bp_records.get(patient_id, [])
    return recs[0] if recs else None