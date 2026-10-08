export interface Patient {
  id: string;
  name: string;
  age: number;
  gestational_week: number;
  due_date: string;
  phone: string;
  risk_level: 'low' | 'medium' | 'high' | 'critical';
  assigned_doctor: string;
  blood_group?: string;
  // true when the wearable band is currently reporting for this patient
  live?: boolean;
}

export interface Vital {
  id: string;
  patient_id: string;
  heart_rate: number;
  spo2: number;
  systolic_bp: number;
  diastolic_bp: number;
  activity_level: string;
  steps: number;
  source: string;
  timestamp: string;
  // manual BP (wearable cannot measure BP)
  bp_source?: string | null;
  bp_logged_at?: string | null;
  // live wearable overlay
  live?: boolean;
  device_id?: string;
  signal_quality?: number;
  fall_candidate?: boolean;
  live_at?: string;
}

export interface RiskAssessment {
  risk_level: 'low' | 'medium' | 'high' | 'critical';
  score: number;
  factors: string[];
  recommendation: string;
  gestational_week?: number;
}

export interface BpRecord {
  id: string;
  patient_id: string;
  systolic_bp: number;
  diastolic_bp: number;
  source: string;
  logged_at: string;
}

export interface NutritionOption {
  name: string;
  benefit: string;
}

export interface Symptom {
  id: string;
  patient_id: string;
  symptom_type: string;
  severity: number;
  description: string;
  timestamp: string;
  ai_flagged: boolean;
}