from datetime import datetime, timedelta
import random

MOCK_PATIENTS = [
    {
        "id": "P001",
        "name": "Priya Sharma",
        "age": 27,
        "gestational_week": 28,
        "due_date": "2026-09-15",
        "phone": "+91-9876543210",
        "risk_level": "medium",
        "assigned_doctor": "D001",
    },
    {
        "id": "P002",
        "name": "Anitha Kumari",
        "age": 31,
        "gestational_week": 34,
        "due_date": "2026-08-20",
        "phone": "+91-9876543211",
        "risk_level": "low",
        "assigned_doctor": "D001",
    },
    {
        "id": "P003",
        "name": "Lakshmi Devi",
        "age": 24,
        "gestational_week": 20,
        "due_date": "2026-11-10",
        "phone": "+91-9876543212",
        "risk_level": "high",
        "assigned_doctor": "D001",
    },
    {
        "id": "P004",
        "name": "Meena Rajan",
        "age": 29,
        "gestational_week": 36,
        "due_date": "2026-08-05",
        "phone": "+91-9876543213",
        "risk_level": "low",
        "assigned_doctor": "D001",
    },
    {
        "id": "P005",
        "name": "Divya Nair",
        "age": 33,
        "gestational_week": 30,
        "due_date": "2026-09-28",
        "phone": "+91-9876543214",
        "risk_level": "medium",
        "assigned_doctor": "D001",
    },
]

MOCK_VITALS = {}
for patient in MOCK_PATIENTS:
    pid = patient["id"]
    vitals_list = []
    for i in range(10):
        t = datetime.now() - timedelta(hours=i * 3)
        hr = random.randint(72, 95)
        spo2 = random.randint(94, 99)
        temp = round(random.uniform(36.2, 37.1), 1)
        sys_bp = random.randint(110, 135)
        dia_bp = random.randint(70, 88)

        if patient["risk_level"] == "high":
            sys_bp = random.randint(135, 155)
            dia_bp = random.randint(88, 100)
            hr = random.randint(90, 110)
        elif patient["risk_level"] == "medium":
            sys_bp = random.randint(125, 142)
            dia_bp = random.randint(82, 92)

        # P001 is the demo patient: keep BP normal so the visible risk
        # comes from logged symptoms, not a random mock reading.
        if pid == "P001":
            sys_bp, dia_bp = 118, 76

        vitals_list.append(
            {
                "id": f"V{pid}_{i}",
                "patient_id": pid,
                "heart_rate": hr,
                "spo2": spo2,
                "temperature": temp,
                "systolic_bp": sys_bp,
                "diastolic_bp": dia_bp,
                "activity_level": random.choice(["light", "moderate", "active"]),
                "steps": random.randint(1000, 8000),
                "source": "wearable",
                "timestamp": t.isoformat(),
            }
        )
    MOCK_VITALS[pid] = vitals_list

MOCK_SYMPTOMS = {
    # P001 = demo patient (Gayathri). Mild headache only -> MEDIUM risk
    # with one clear reason; the doctor can log more symptoms to escalate.
    "P001": [
        {
            "id": "S1",
            "patient_id": "P001",
            "symptom_type": "Headache",
            "severity": 3,
            "description": "Mild headache since morning",
            "timestamp": (datetime.now() - timedelta(hours=5)).isoformat(),
            "ai_flagged": False,
        },
    ],
    "P003": [
        {
            "id": "S3",
            "patient_id": "P003",
            "symptom_type": "Headache",
            "severity": 4,
            "description": "Severe headache with blurred vision",
            "timestamp": (datetime.now() - timedelta(hours=2)).isoformat(),
            "ai_flagged": True,
        },
        {
            "id": "S4",
            "patient_id": "P003",
            "symptom_type": "Nausea",
            "severity": 3,
            "description": "Feeling nauseous after meals",
            "timestamp": (datetime.now() - timedelta(hours=8)).isoformat(),
            "ai_flagged": False,
        },
    ],
}

MOCK_NUTRITION = {
    "P001": {
        "patient_id": "P001",
        "daily_calories": {"target": 2200, "consumed": 1850},
        "nutrients": [
            {"name": "Protein", "current": 68, "target": 75, "unit": "g"},
            {"name": "Iron", "current": 18, "target": 27, "unit": "mg"},
            {"name": "Calcium", "current": 900, "target": 1000, "unit": "mg"},
            {"name": "Folate", "current": 550, "target": 600, "unit": "mcg"},
            {"name": "Fiber", "current": 22, "target": 28, "unit": "g"},
        ],
        "water_glasses": 6,
        "water_target": 8,
        "meals": [
            {
                "name": "Breakfast",
                "icon": "🌅",
                "calories": 450,
                "items": ["Oatmeal with berries", "Glass of milk", "Almonds"],
            },
            {
                "name": "Lunch",
                "icon": "☀️",
                "calories": 620,
                "items": ["Rice", "Dal", "Vegetable curry", "Curd"],
            },
            {
                "name": "Snack",
                "icon": "🍎",
                "calories": 280,
                "items": ["Banana", "Handful of walnuts", "Apple juice"],
            },
            {
                "name": "Dinner",
                "icon": "🌙",
                "calories": 500,
                "items": ["Chapati", "Paneer tikka", "Salad", "Soup"],
            },
        ],
        "alerts": ["Low iron intake - consider iron-rich foods or supplement"],
    },
}


MOCK_REMINDERS = [
    {
        "id": "R1",
        "patient_id": "P001",
        "title": "Iron Tablet",
        "message": "Take your iron supplement with water",
        "reminder_type": "medication",
        "time": "09:00",
        "recurring": True,
        "completed": False,
    },
    {
        "id": "R2",
        "patient_id": "P001",
        "title": "Drink Water",
        "message": "Stay hydrated - drink a glass of water",
        "reminder_type": "hydration",
        "time": "10:00",
        "recurring": True,
        "completed": True,
    },
    {
        "id": "R3",
        "patient_id": "P001",
        "title": "Prenatal Checkup",
        "message": "Monthly checkup at City Hospital",
        "reminder_type": "appointment",
        "time": "14:00",
        "recurring": False,
        "completed": False,
    },
    {
        "id": "R4",
        "patient_id": "P001",
        "title": "Evening Snack",
        "message": "Have a protein-rich snack - banana with milk",
        "reminder_type": "nutrition",
        "time": "16:00",
        "recurring": True,
        "completed": False,
    },
]
