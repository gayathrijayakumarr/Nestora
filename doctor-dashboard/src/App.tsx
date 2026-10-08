import { useState, useEffect, useRef } from 'react';
import { fetchPatients, fetchPatient, fetchVitals, fetchLatestVital, fetchSymptoms, fetchRisk, enrollPatient } from './services/api';
import type { Patient, Vital, Symptom, RiskAssessment } from './types';
import './App.css';

const gradients = ['gradient-1', 'gradient-2', 'gradient-3', 'gradient-4', 'gradient-5'];

function formatWhen(iso?: string | null) {
  if (!iso) return '-';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString();
}

// [normalLow, normalHigh, warningLow, dangerLow]
// A value is "Elevated" when it is outside the normal band but not
// critically so, and "Critical" when it passes the danger threshold.
function getVitalTrend(type: string, value: number): { label: string; status: string } {
  const ranges: Record<string, [number, number, number, number]> = {
    heart_rate: [60, 90, 50, 40],
    spo2: [95, 100, 93, 90],
    temperature: [36.1, 37.2, 35.8, 35.0],
    bp_systolic: [90, 130, 140, 160],
  };
  const r = ranges[type];
  if (!r || !Number.isFinite(value)) return { label: 'Normal', status: 'normal' };
  if (value >= r[0] && value <= r[1]) return { label: 'Normal', status: 'normal' };
  if (value <= r[3] || value >= r[2]) return { label: 'Critical', status: 'danger' };
  return { label: 'Elevated', status: 'warning' };
}


function EnrollModal({ onClose, onSubmit }: {
  onClose: () => void;
  onSubmit: (p: { name: string; phone: string; age: number; gestational_week: number; blood_group: string }) => void;
}) {
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [age, setAge] = useState('25');
  const [week, setWeek] = useState('12');
  const [blood, setBlood] = useState('');
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2 className="section-title">Enrol a new patient</h2>
        <p className="page-subtitle" style={{ marginBottom: 16 }}>
          Creating the patient record that lets her sign in to the app.
        </p>
        <div className="form-grid">
          <label className="field">
            <span>Full name</span>
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Ananya" />
          </label>
          <label className="field">
            <span>Phone (10 digits)</span>
            <input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="9000001234" />
          </label>
          <label className="field">
            <span>Age</span>
            <input value={age} onChange={(e) => setAge(e.target.value)} inputMode="numeric" />
          </label>
          <label className="field">
            <span>Pregnancy week</span>
            <input value={week} onChange={(e) => setWeek(e.target.value)} inputMode="numeric" />
          </label>
          <label className="field">
            <span>Blood group</span>
            <input value={blood} onChange={(e) => setBlood(e.target.value)} placeholder="B+" />
          </label>
        </div>
        <div className="modal-actions">
          <button className="btn-secondary" onClick={onClose}>Cancel</button>
          <button
            className="btn-primary"
            onClick={() => onSubmit({ name, phone, age: Number(age) || 25, gestational_week: Number(week) || 0, blood_group: blood })}
          >
            Register patient
          </button>
        </div>
      </div>
    </div>
  );
}

function App() {
  const [view, setView] = useState<'overview' | 'patients' | 'detail'>('overview');
  const [patients, setPatients] = useState<Patient[]>([]);
  const [selectedPatient, setSelectedPatient] = useState<Patient | null>(null);
  const [vitals, setVitals] = useState<Vital[]>([]);
  const [symptoms, setSymptoms] = useState<Symptom[]>([]);
  const [risk, setRisk] = useState<RiskAssessment | null>(null);
  const [showEnroll, setShowEnroll] = useState(false);
  const [enrollMsg, setEnrollMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const cancelledRef = useRef(false);

  const load = async () => {
    try {
      const data = await fetchPatients();
      const list: Patient[] = Array.isArray(data) ? data : [];
      const checks = await Promise.all(
        list.map(async (p: Patient) => {
          try {
            const latest = await fetchLatestVital(p.id);
            return { ...p, live: latest?.live === true } as Patient & { live: boolean };
          } catch {
            // A failed lookup must not hide the patient.
            return { ...p, live: false } as Patient & { live: boolean };
          }
        })
      );
      if (cancelledRef.current) return;
      // Live-connected patients first, then alphabetical, so the band
      // that is actually reporting is always at the top of the list.
      checks.sort((a, b) => {
        if (a.live !== b.live) return a.live ? -1 : 1;
        return a.name.localeCompare(b.name);
      });
      setPatients(checks as Patient[]);
      setError(null);
    } catch (e) {
      if (!cancelledRef.current) {
        setError(
          'Could not reach the backend. Start it with "uvicorn app.main:app" ' +
            'in the backend folder, then reload.'
        );
      }
    } finally {
      if (!cancelledRef.current) setLoading(false);
    }
  };

  // Loads every enrolled patient. A wearable reading marks a patient as
  // "live" for display only - it must never remove a patient from the
  // list, otherwise the dashboard is empty whenever the band is off.
  useEffect(() => {
    cancelledRef.current = false;
    load();
    // Poll so a band that connects later appears without a manual reload.
    const timer = setInterval(() => load(), 5000);
    return () => {
      cancelledRef.current = true;
      clearInterval(timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [refreshKey]);

  const openPatient = async (id: string) => {
    const [p, v, s, r] = await Promise.all([
      fetchPatient(id),
      fetchVitals(id),
      fetchSymptoms(id),
      fetchRisk(id).catch(() => null),
    ]);
    setSelectedPatient(p);
    setVitals(v);
    setSymptoms(s);
    setRisk(r);
    setView('detail');
  };

  const reloadAll = () => setRefreshKey((k) => k + 1);

  const handleEnroll = async (payload: {
    name: string; phone: string; age: number; gestational_week: number; blood_group: string;
  }) => {
    try {
      const res = await enrollPatient(payload);
      if (res.error) {
        setEnrollMsg({ ok: false, text: res.error });
        return;
      }
      setEnrollMsg({ ok: true, text: `Registered ${res.name} (${res.id}). They can now sign in with ${res.phone}.` });
      reloadAll();
    } catch {
      setEnrollMsg({ ok: false, text: 'Could not reach the backend' });
    }
  };

  const liveCount = patients.filter((p) => p.live).length;
  const highRisk = patients.filter((p) => p.risk_level === 'high').length;
  const medRisk = patients.filter((p) => p.risk_level === 'medium').length;
  const lowRisk = patients.filter((p) => p.risk_level === 'low').length;

  const latestVital = vitals[0];

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="sidebar-header">
          <div className="logo">
            <div className="logo-icon">N</div>
            <div className="logo-text">NEST<span>ORA</span></div>
          </div>
        </div>

        <nav className="sidebar-nav">
          <button
            className={`nav-item ${view === 'overview' ? 'active' : ''}`}
            onClick={() => setView('overview')}
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>
            Overview
          </button>
          <button
            className={`nav-item ${view === 'patients' ? 'active' : ''}`}
            onClick={() => setView('patients')}
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
            Patients
          </button>
          <button
            className="nav-item"
            onClick={() => { setEnrollMsg(null); setShowEnroll(true); }}
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="19" y1="8" x2="19" y2="14"/><line x1="22" y1="11" x2="16" y2="11"/></svg>
            Enroll Patient
          </button>

          <button
            className={`nav-item ${view === 'detail' ? 'active' : ''}`}
            disabled={!selectedPatient}
            style={{ opacity: selectedPatient ? 1 : 0.4 }}
            onClick={() => setView('detail')}
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg>
            Vitals Detail
          </button>
        </nav>

        <div className="sidebar-footer">
          <div className="doctor-info">
            <div className="doctor-avatar">RK</div>
            <div>
              <div className="doctor-name">Dr. Rajesh Kumar</div>
              <div className="doctor-role">OB-GYN Specialist</div>
            </div>
          </div>
        </div>
      </aside>

      <main className="main">
        {error && (
          <div className="alert-banner">
            <strong>Backend not reachable.</strong> {error}
          </div>
        )}

        {view === 'overview' && (
          <>
            <div className="page-header">
              <div>
                <h1 className="page-title">Dashboard Overview</h1>
                <p className="page-subtitle">All enrolled patients. Those with a connected band are marked LIVE.</p>
              </div>
            </div>

            <div className="summary-grid">
              <div className="summary-card">
                <div className="summary-card-header">
                  <span className="summary-card-label">Total Patients</span>
                  <div className="summary-card-icon pink">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                  </div>
                </div>
                <div className="summary-card-value">{patients.length}</div>
                <div className="summary-card-change">Active pregnancies</div>
              </div>
              <div className="summary-card">
                <div className="summary-card-header">
                  <span className="summary-card-label">High Risk</span>
                  <div className="summary-card-icon red">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                  </div>
                </div>
                <div className="summary-card-value text-red">{highRisk}</div>
                <div className="summary-card-change">Requires attention</div>
              </div>
              <div className="summary-card">
                <div className="summary-card-header">
                  <span className="summary-card-label">Medium Risk</span>
                  <div className="summary-card-icon orange">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                  </div>
                </div>
                <div className="summary-card-value text-orange">{medRisk}</div>
                <div className="summary-card-change">Monitor closely</div>
              </div>
              <div className="summary-card">
                <div className="summary-card-header">
                  <span className="summary-card-label">Low Risk</span>
                  <div className="summary-card-icon green">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
                  </div>
                </div>
                <div className="summary-card-value text-green">{lowRisk}</div>
                <div className="summary-card-change">On track</div>
              </div>
            </div>

            <div className="patient-table-wrap">
              <div className="patient-table-header">
                <span className="patient-table-title">Patients Needing Attention</span>
                <span className="patient-count">{highRisk + medRisk} flagged</span>
              </div>
              <table className="patient-table">
                <thead>
                  <tr>
                    <th>Patient</th>
                    <th>Week</th>
                    <th>Due Date</th>
                    <th>Risk Level</th>
                  </tr>
                </thead>
                <tbody>
                  {patients.filter((p) => p.risk_level !== 'low').length === 0 && (
                    <tr>
                      <td colSpan={4}>
                        <div className="empty-state">
                          {patients.length === 0
                            ? 'No patients to show yet.'
                            : 'All patients are currently low risk.'}
                        </div>
                      </td>
                    </tr>
                  )}
                  {patients
                    .filter((p) => p.risk_level !== 'low')
                    .map((p, i) => (
                      <tr key={p.id} onClick={() => openPatient(p.id)}>
                        <td>
                          <div className="patient-cell">
                            <div className={`patient-avatar ${gradients[i % gradients.length]}`}>
                              {p.name[0]}
                            </div>
                            <div>
                              <div className="patient-name">
                                {p.name}
                                {p.live && <span className="live-chip">LIVE</span>}
                              </div>
                              <div className="patient-id">ID: {p.id.slice(0, 8)}</div>
                            </div>
                          </div>
                        </td>
                        <td className="patient-meta">Week {p.gestational_week}</td>
                        <td className="patient-meta">{p.due_date}</td>
                        <td><span className={`risk-badge ${p.risk_level}`}>{p.risk_level}</span></td>
                      </tr>
                    ))}
                </tbody>
              </table>
            </div>
          </>
        )}

        {view === 'patients' && (
          <>
            <div className="page-header">
              <div>
                <h1 className="page-title">All Patients</h1>
                <p className="page-subtitle">
                  {patients.length} enrolled &middot; {liveCount} with a connected band
                </p>
              </div>
            </div>

            <div className="patient-table-wrap">
              <table className="patient-table">
                <thead>
                  <tr>
                    <th>Patient</th>
                    <th>Age</th>
                    <th>Week</th>
                    <th>Due Date</th>
                    <th>Phone</th>
                    <th>Risk Level</th>
                  </tr>
                </thead>
                <tbody>
                  {patients.length === 0 && !loading && (
                    <tr>
                      <td colSpan={6}>
                        <div className="empty-state">
                          {error
                            ? 'No data - the backend is not reachable.'
                            : 'No patients enrolled yet. Use "Enroll Patient" to add one.'}
                        </div>
                      </td>
                    </tr>
                  )}
                  {loading && patients.length === 0 && (
                    <tr>
                      <td colSpan={6}>
                        <div className="empty-state">Loading patients...</div>
                      </td>
                    </tr>
                  )}
                  {patients.map((p, i) => (
                    <tr key={p.id} onClick={() => openPatient(p.id)}>
                      <td>
                        <div className="patient-cell">
                          <div className={`patient-avatar ${gradients[i % gradients.length]}`}>
                            {p.name[0]}
                          </div>
                          <div>
                            <div className="patient-name">
                              {p.name}
                              {p.live && <span className="live-chip">LIVE</span>}
                            </div>
                            <div className="patient-id">ID: {p.id.slice(0, 8)}</div>
                          </div>
                        </div>
                      </td>
                      <td className="patient-meta">{p.age} yrs</td>
                      <td className="patient-meta">Week {p.gestational_week}</td>
                      <td className="patient-meta">{p.due_date}</td>
                      <td className="patient-meta">{p.phone}</td>
                      <td><span className={`risk-badge ${p.risk_level}`}>{p.risk_level}</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}

        {view === 'detail' && selectedPatient && (
          <>
            <div className="detail-top-bar">
              <button className="back-btn" onClick={() => setView('patients')}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
                Back
              </button>
              <h1 className="detail-patient-name">{selectedPatient.name}</h1>
              <span className={`risk-badge ${selectedPatient.risk_level}`}>{selectedPatient.risk_level} risk</span>
              {latestVital?.live && (
                <span className="risk-badge live-device" title={`Wearable sync: ${latestVital.live_at ?? 'just now'}`}>
                  ● LIVE DEVICE
                </span>
              )}
            </div>
            {latestVital?.live && (
              <p className="live-sync-note">
                Last wearable sync: {latestVital.live_at ? new Date(latestVital.live_at).toLocaleTimeString() : 'just now'}
                {latestVital.signal_quality != null && ` · signal ${latestVital.signal_quality}/100`}
                {latestVital.fall_candidate && ' · possible sudden movement detected'}
              </p>
            )}

            {risk && (
              <div className={`risk-panel ${risk.risk_level}`}>
                <div className="risk-panel-head">
                  <span className="risk-panel-title">
                    Risk: {risk.risk_level.toUpperCase()}
                  </span>
                  <span className="risk-panel-score">score {risk.score} · week {risk.gestational_week ?? '-'}</span>
                </div>
                <ul className="risk-factor-list">
                  {risk.factors.map((f, i) => (
                    <li key={i}>{f}</li>
                  ))}
                </ul>
                <div className="risk-panel-rec">{risk.recommendation}</div>
              </div>
            )}

            <div className="info-grid">
              <div className="info-card">
                <h3>Patient Info</h3>
                <div className="info-row">
                  <span className="info-label">Age</span>
                  <span className="info-value">{selectedPatient.age} years</span>
                </div>
                <div className="info-row">
                  <span className="info-label">Gestational Week</span>
                  <span className="info-value">{selectedPatient.gestational_week} weeks</span>
                </div>
                <div className="info-row">
                  <span className="info-label">Due Date</span>
                  <span className="info-value">{selectedPatient.due_date}</span>
                </div>
                <div className="info-row">
                  <span className="info-label">Phone</span>
                  <span className="info-value">{selectedPatient.phone}</span>
                </div>
                <div className="info-row">
                  <span className="info-label">Doctor</span>
                  <span className="info-value">{selectedPatient.assigned_doctor}</span>
                </div>
              </div>

              {latestVital && (
                <div className="vitals-grid">
                  <div className="vital-card heart">
                    <div className="vital-icon heart">
                      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>
                    </div>
                    <div className="vital-value">{latestVital.heart_rate}</div>
                    <div className="vital-label">Heart Rate (bpm) · wearable</div>
                    <div className={`vital-trend ${getVitalTrend('heart_rate', latestVital.heart_rate).status}`}>
                      {getVitalTrend('heart_rate', latestVital.heart_rate).label}
                    </div>
                  </div>
                  <div className="vital-card spo2">
                    <div className="vital-icon spo2">
                      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"/></svg>
                    </div>
                    <div className="vital-value">{latestVital.spo2}%</div>
                    <div className="vital-label">SpO2 · wearable</div>
                    <div className={`vital-trend ${getVitalTrend('spo2', latestVital.spo2).status}`}>
                      {getVitalTrend('spo2', latestVital.spo2).label}
                    </div>
                  </div>
                  <div className="vital-card bp">
                    <div className="vital-icon bp">
                      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
                    </div>
                    <div className="vital-value">{latestVital.systolic_bp}/{latestVital.diastolic_bp}</div>
                    <div className="vital-label">BP (manual entry)</div>
                    <div className={`vital-trend ${getVitalTrend('bp_systolic', latestVital.systolic_bp).status}`}>
                      {latestVital.bp_logged_at
                        ? `Logged ${formatWhen(latestVital.bp_logged_at)}`
                        : 'Not recorded by patient'}
                    </div>
                  </div>
                </div>
              )}
            </div>

            <div className="section-card">
              <div className="section-header">
                <h2 className="section-title">Vital History</h2>
                <span className="patient-count">{vitals.length} records</span>
              </div>
              <div className="section-body" style={{ padding: 0 }}>
                <table className="vitals-table">
                  <thead>
                    <tr>
                      <th>Timestamp</th>
                      <th>Heart Rate</th>
                      <th>SpO2</th>
                      <th>Blood Pressure</th>
                      <th>Steps</th>
                    </tr>
                  </thead>
                  <tbody>
                    {vitals.map((v) => {
                      const hrTrend = getVitalTrend('heart_rate', v.heart_rate);
                      return (
                        <tr key={v.id}>
                          <td>{new Date(v.timestamp).toLocaleString()}</td>
                          <td>
                            <span style={{ fontWeight: 600 }}>{v.heart_rate} bpm</span>
                            <span className={`vital-trend ${hrTrend.status}`} style={{ marginLeft: 8 }}>
                              {hrTrend.label}
                            </span>
                          </td>
                          <td>{v.spo2}%</td>
                          <td>
                            {v.systolic_bp}/{v.diastolic_bp}
                            <div className="cell-note">manual entry</div>
                          </td>
                          <td>{v.steps?.toLocaleString() || '—'}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>

            <div className="section-card">
              <div className="section-header">
                <h2 className="section-title">Symptoms</h2>
                <span className="patient-count">
                  {symptoms.filter((s) => s.ai_flagged).length} AI flagged
                </span>
              </div>
              <div className="section-body">
                {symptoms.length === 0 ? (
                  <div className="empty-state">
                    <div className="empty-state-icon">📋</div>
                    <div className="empty-state-text">No symptoms logged yet</div>
                  </div>
                ) : (
                  symptoms.map((s) => (
                    <div key={s.id} className={`symptom-card ${s.ai_flagged ? 'flagged' : ''}`}>
                      <div className="symptom-dot" />
                      <div className="symptom-content">
                        <div className="symptom-top">
                          <span className="symptom-type">{s.symptom_type}</span>
                          <div className="symptom-severity">
                            {Array.from({ length: 5 }, (_, i) => (
                              <span key={i} className={`severity-dot ${i < s.severity ? 'filled' : ''}`} />
                            ))}
                          </div>
                          {s.ai_flagged && <span className="symptom-flag">AI Flagged</span>}
                        </div>
                        <p className="symptom-desc">{s.description}</p>
                        <span className="symptom-time">{new Date(s.timestamp).toLocaleString()}</span>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </>
        )}
      </main>

      {showEnroll && (
        <EnrollModal
          onClose={() => setShowEnroll(false)}
          onSubmit={(p) => handleEnroll(p)}
        />
      )}
      {enrollMsg && !showEnroll && (
        <div className="toast" onClick={() => setEnrollMsg(null)}>
          <strong>{enrollMsg.ok ? 'Registered' : 'Could not register'}</strong>
          <span>{enrollMsg.text}</span>
          <span className="toast-hint">tap to close</span>
        </div>
      )}
    </div>
  );
}

export default App;
