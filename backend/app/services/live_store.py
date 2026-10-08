"""In-memory store for live wearable readings.

NESTORA V1 data flow: ESP32-S3 -> Flutter (BLE gateway) -> POST here ->
existing GET endpoints merge the live reading for the dashboard.

Prototype-grade: no database, no auth. Restarting the server clears it,
and every GET falls back to mock data when no live reading exists.
"""

from datetime import datetime, timezone

# patient_id -> latest wearable reading dict
latest_live_vitals: dict = {}

# Live readings older than this are ignored (stale device / app closed).
LIVE_TTL_SECONDS = 120


def save_live(data: dict) -> dict:
    entry = {
        "patient_id": data.get("patient_id", "P001"),
        "device_id": data.get("device_id", "NESTORA-V1-001"),
        "timestamp": data.get("timestamp"),
        "heart_rate": data.get("heart_rate"),
        "heart_rate_avg": data.get("heart_rate_avg"),
        "spo2": data.get("spo2"),
        "steps": data.get("steps"),
        "activity": data.get("activity", "UNKNOWN"),
        "movement": data.get("movement"),
        "rest_seconds": data.get("rest_seconds"),
        "contact": data.get("contact", False),
        "signal_quality": data.get("signal_quality"),
        "fall_candidate": bool(data.get("fall_candidate", False)),
        "received_at": datetime.now(timezone.utc).isoformat(),
    }
    latest_live_vitals[entry["patient_id"]] = entry
    return entry


def get_live(patient_id: str) -> dict | None:
    entry = latest_live_vitals.get(patient_id)
    if not entry:
        return None
    try:
        rx = datetime.fromisoformat(entry["received_at"])
        age = (datetime.now(timezone.utc) - rx).total_seconds()
    except Exception:
        return None
    if age > LIVE_TTL_SECONDS:
        latest_live_vitals.pop(patient_id, None)
        return None
    return entry


def merge_into_vitals(live: dict, base: dict) -> dict:
    """Overlay wearable fields onto a mock vitals record.

    Only fields the hardware actually measures are overridden.
    temperature / systolic_bp / diastolic_bp are NEVER touched
    (null != zero: missing sensors must not fake values).
    """
    merged = dict(base)
    if live.get("heart_rate") is not None:
        merged["heart_rate"] = live["heart_rate"]
    if live.get("spo2") is not None:
        merged["spo2"] = live["spo2"]
    if live.get("steps") is not None:
        merged["steps"] = live["steps"]
    activity = (live.get("activity") or "UNKNOWN").lower()
    merged["activity_level"] = {
        "resting": "sedentary",
        "very_inactive": "sedentary",
        "walking": "light",
        "active": "moderate",
    }.get(activity, "light")
    merged["source"] = "wearable"
    merged["live"] = True
    merged["device_id"] = live.get("device_id")
    merged["signal_quality"] = live.get("signal_quality")
    merged["fall_candidate"] = live.get("fall_candidate", False)
    merged["live_at"] = live.get("received_at")
    return merged
