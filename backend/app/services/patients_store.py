"""Patient registry for NESTORA (prototype, in-memory).

Key rule: mothers do NOT self-register. A doctor enrols a patient from
the dashboard (name + phone + pregnancy details), which creates the
patient id. The patient can then log in to the mobile app using that
name and phone; anything unknown is rejected with "User not found".

Seeded with the demo cohort so the flow can be shown immediately.
"""

from datetime import datetime, timedelta

# ── Enrolled patients (mutable: doctor can add at runtime) ────────────────
MOCK_PATIENTS: list[dict] = [
    {
        "id": "P001",
        "name": "Gayathri",
        "age": 27,
        "phone": "9489675377",
        "gestational_week": 28,
        "lmp_date": "2026-03-20",
        "due_date": "2026-12-25",
        "risk_level": "medium",
        "assigned_doctor": "D001",
        "blood_group": "B+",
        "height_cm": 158,
        "weight_kg": 62,
        "created_at": datetime.now().isoformat(),
    },
    {
        "id": "P002",
        "name": "Anitha Kumari",
        "age": 31,
        "phone": "9876543211",
        "gestational_week": 34,
        "lmp_date": "2026-01-15",
        "due_date": "2026-10-22",
        "risk_level": "low",
        "assigned_doctor": "D001",
        "blood_group": "O+",
        "height_cm": 160,
        "weight_kg": 66,
        "created_at": datetime.now().isoformat(),
    },
    {
        "id": "P003",
        "name": "Lakshmi Devi",
        "age": 24,
        "phone": "9876543212",
        "gestational_week": 20,
        "lmp_date": "2026-05-02",
        "due_date": "2027-02-06",
        "risk_level": "high",
        "assigned_doctor": "D001",
        "blood_group": "A+",
        "height_cm": 155,
        "weight_kg": 55,
        "created_at": datetime.now().isoformat(),
    },
    {
        "id": "P004",
        "name": "Meena Rajan",
        "age": 29,
        "phone": "9876543213",
        "gestational_week": 36,
        "lmp_date": "2025-12-10",
        "due_date": "2026-09-16",
        "risk_level": "low",
        "assigned_doctor": "D001",
        "blood_group": "AB+",
        "height_cm": 162,
        "weight_kg": 68,
        "created_at": datetime.now().isoformat(),
    },
    {
        "id": "P005",
        "name": "Divya Nair",
        "age": 33,
        "phone": "9876543214",
        "gestational_week": 30,
        "lmp_date": "2026-02-28",
        "due_date": "2026-12-05",
        "risk_level": "medium",
        "assigned_doctor": "D001",
        "blood_group": "O-",
        "height_cm": 157,
        "weight_kg": 64,
        "created_at": datetime.now().isoformat(),
    },
]

# P001 is the demo patient the wearable is mapped to.
DEMO_PATIENT_ID = "P001"
WEARABLE_DEVICE_ID = "NESTORA-V1-001"


def _digits(value: str) -> str:
    return "".join(ch for ch in str(value) if ch.isdigit())


def find_by_phone(phone: str) -> dict | None:
    """Phone match ignores formatting (spaces, +91, dashes)."""
    target = _digits(phone)
    if len(target) > 10:  # strip +91 / 0 prefix
        target = target[-10:]
    for p in MOCK_PATIENTS:
        if _digits(p["phone"])[-10:] == target:
            return p
    return None


def find_by_id(patient_id: str) -> dict | None:
    for p in MOCK_PATIENTS:
        if p["id"] == patient_id:
            return p
    return None


def authenticate(name: str, phone: str) -> tuple[dict | None, str]:
    """Login is enrolment-gated: only enrolled patients may sign in.

    Returns (patient, error_message). Phone is the primary key; the name
    must match too so a mistyped number cannot leak someone else's data.
    """
    if not name.strip() or not phone.strip():
        return None, "Please enter your name and phone number."
    patient = find_by_phone(phone)
    if not patient:
        return None, "User not found. Please contact your doctor to register."
    entered = name.strip().lower().split()[0] if name.strip() else ""
    stored = patient["name"].strip().lower().split()[0]
    if entered != stored:
        return None, "Name does not match our records for this number."
    return patient, ""


def _next_id() -> str:
    nums = [int(p["id"][1:]) for p in MOCK_PATIENTS if p["id"][1:].isdigit()]
    return f"P{max(nums) + 1:03d}"


def enroll(name: str, phone: str, age: int, gestational_week: int,
           due_date: str | None = None, blood_group: str = "",
           height_cm: int | None = None, weight_kg: float | None = None,
           assigned_doctor: str = "D001") -> tuple[dict | None, str]:
    """Doctor-side enrolment. Returns (patient, error)."""
    if not name.strip():
        return None, "Patient name is required."
    if not phone.strip() or len(_digits(phone)) < 10:
        return None, "A valid 10-digit phone number is required."
    if find_by_phone(phone):
        return None, "A patient with this phone number already exists."
    if not gestational_week or not (1 <= int(gestational_week) <= 42):
        return None, "Pregnancy week must be between 1 and 42."

    week = int(gestational_week)
    if due_date:
        due = due_date
    else:
        due = (datetime.now() + timedelta(weeks=40 - week)).strftime("%Y-%m-%d")

    patient = {
        "id": _next_id(),
        "name": name.strip(),
        "age": int(age) if age else 25,
        "phone": phone.strip(),
        "gestational_week": week,
        "lmp_date": (datetime.now() - timedelta(weeks=week)).strftime("%Y-%m-%d"),
        "due_date": due,
        "risk_level": "low",
        "assigned_doctor": assigned_doctor,
        "blood_group": blood_group,
        "height_cm": height_cm,
        "weight_kg": weight_kg,
        "created_at": datetime.now().isoformat(),
    }
    MOCK_PATIENTS.append(patient)
    return patient, ""


def current_week(patient: dict) -> int:
    """Gestational week derived from the due date (280 days)."""
    try:
        due = datetime.fromisoformat(str(patient.get("due_date"))).date()
        weeks = (due - datetime.now().date()).days / 7.0
        if weeks <= 0:
            return 40
        return max(1, min(42, 41 - int(round(weeks))))
    except (TypeError, ValueError):
        return int(patient.get("gestational_week") or 28)