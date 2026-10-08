"""Pregnancy-week food suggestions (prototype, wellness guidance).

Grouped by trimester so the recommendations follow the mother's current
gestational week. Phrasing stays advisory - "suggested options" - never a
prescribed diet. Values are illustrative nutritional benefits, not
clinical nutrition therapy.
"""

TRIMESTERS = {
    1: ("First trimester (weeks 1-13)",
        ["Nausea and fatigue are common",
         "Focus on folate, iron and hydration",
         "Small frequent meals help"]),
    2: ("Second trimester (weeks 14-27)",
        ["Energy usually improves",
         "Extra calcium and protein for growth",
         "Steady hydration supports blood volume"]),
    3: ("Third trimester (weeks 28-40)",
        ["Smaller frequent meals ease pressure",
         "Iron and fibre to reduce constipation",
         "Monitor swelling and hydration closely"]),
}


def _trimester(week: int) -> tuple[int, str, list[str]]:
    key = 1 if week <= 13 else (2 if week <= 27 else 3)
    label, notes = TRIMESTERS[key]
    return key, label, notes


OPTIONS = {
    1: {
        "Breakfast": [
            ("Oats with banana", "Folate + slow-release energy"),
            ("Idli / dosa with sambar", "Easy to digest, adds iron"),
            ("Milk or curd with fruit", "Calcium + vitamin C for iron uptake"),
        ],
        "Lunch": [
            ("Rice / roti with dal", "Protein + complex carbs"),
            ("Vegetable poriyal with rice", "Fibre, vitamins, antioxidants"),
            ("Lemon rice with sprouts", "Light, vitamin C rich"),
        ],
        "Snack": [
            ("Buttermilk / tender coconut", "Hydrating, gentle on the stomach"),
            ("Biscuits with curd", "Settles nausea"),
            ("Roasted chana", "Protein + iron (in small portions)"),
        ],
        "Dinner": [
            ("Moong dal khichdi", "Easy on digestion, protein"),
            ("Vegetable soup + toast", "Fluids + light carbs"),
            ("Paneer bhurji with roti", "Protein + calcium"),
        ],
    },
    2: {
        "Breakfast": [
            ("Besan chilla with milk", "Protein, calcium, iron"),
            ("Oats porridge with nuts", "Fibre + healthy fats"),
            ("Egg bhurji / paneer paratha", "Complete protein for growth"),
        ],
        "Lunch": [
            ("Dal, rice, salad, curd", "Balanced protein + calcium"),
            ("Chicken / paneer curry with roti", "High protein for foetal growth"),
            ("Mixed vegetable pulao", "Variety of vitamins"),
        ],
        "Snack": [
            ("Fruits with yoghurt", "Calcium + antioxidants"),
            ("Sprouts chaat", "Iron, protein, low calorie"),
            ("Dry fruits (5-6)", "Healthy fats, vitamin E"),
        ],
        "Dinner": [
            ("Khichdi with ghee + vegetables", "Comforting, easy to digest"),
            ("Grilled fish / tofu with salad", "Omega-3 and protein"),
            ("Roti, dal, sabzi", "Balanced evening meal"),
        ],
    },
    3: {
        "Breakfast": [
            ("Oats upma with milk", "Fibre, calcium, steady energy"),
            ("Multigrain paratha with curd", "Iron + calcium + fibre"),
            ("Fruit salad with nuts", "Vitamins, hydration, healthy fats"),
        ],
        "Lunch": [
            ("Dal, rice, 2 sabzi, salad", "Protein, fibre, micronutrients"),
            ("Chicken / paneer with roti", "Protein to support growth"),
            ("Fish curry with rice", "Omega-3 for brain development"),
        ],
        "Snack": [
            ("Vegetable soup + boiled corn", "Light, fibre, hydration"),
            ("Yogurt with berries", "Calcium and antioxidants"),
            ("Whole fruit + a few almonds", "Natural sugars, healthy fats"),
        ],
        "Dinner": [
            ("Light khichdi + vegetables", "Easy on a full stomach"),
            ("Roti, dal, cooked vegetables", "Balanced, low fat"),
            ("Soup with brown rice", "Hydration + gentle carbs"),
        ],
    },
}

HYDRATION_TIP = ("Aim for about 8 glasses of water a day; spread them "
                 "through the day rather than in one go.")


def recommendations(week: int) -> dict:
    key, label, notes = _trimester(week)
    meals = []
    for meal in ("Breakfast", "Lunch", "Snack", "Dinner"):
        meals.append({
            "meal": meal,
            "options": [
                {"name": n, "benefit": b} for n, b in OPTIONS[key][meal]
            ],
        })
    return {
        "gestational_week": week,
        "trimester": label,
        "focus": notes,
        "meals": meals,
        "hydration": HYDRATION_TIP,
        "disclaimer": "Suggested options only - not a prescribed diet. "
                      "Ask your doctor or a dietitian for personal advice.",
    }