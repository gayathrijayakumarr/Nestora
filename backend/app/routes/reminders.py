from fastapi import APIRouter
from app.services.mock_data import MOCK_REMINDERS

router = APIRouter()


@router.get("/{patient_id}")
def get_reminders(patient_id: str):
    return [r for r in MOCK_REMINDERS if r["patient_id"] == patient_id]


@router.post("/")
def add_reminder(data: dict):
    entry = {
        "id": f"R{len(MOCK_REMINDERS) + 1}",
        "patient_id": data.get("patient_id", "P001"),
        "title": data.get("title", "Reminder"),
        "message": data.get("message", ""),
        "reminder_type": data.get("reminder_type", "general"),
        "time": data.get("time", "09:00"),
        "recurring": bool(data.get("recurring", False)),
        "completed": False,
    }
    MOCK_REMINDERS.append(entry)
    return entry


@router.put("/{reminder_id}")
def update_reminder(reminder_id: str, data: dict):
    for r in MOCK_REMINDERS:
        if r["id"] == reminder_id:
            if "completed" in data:
                r["completed"] = bool(data["completed"])
            return r
    return {"error": "Reminder not found"}
