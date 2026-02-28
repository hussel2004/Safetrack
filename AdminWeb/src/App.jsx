import { useState, useEffect, useCallback, useRef } from 'react'

const API_BASE = '/api/v1'

// ── API helpers ───────────────────────────────────────────
async function apiLogin(email, password) {
    const form = new URLSearchParams()
    form.append('username', email)
    form.append('password', password)
    const res = await fetch(`${API_BASE}/auth/login/access-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: form,
    })
    if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.detail || `Erreur ${res.status}`)
    }
    return res.json()
}

async function apiFetch(path, token, options = {}) {
    const res = await fetch(`${API_BASE}${path}`, {
        ...options,
        headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
            ...(options.headers || {}),
        },
    })
    if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.detail || `Erreur ${res.status}`)
    }
    return res.json()
}

// ── Toast hook ────────────────────────────────────────────
function useToasts() {
    const [toasts, setToasts] = useState([])
    const add = useCallback((message, type = 'success') => {
        const id = Date.now()
        setToasts(t => [...t, { id, message, type }])
        setTimeout(() => setToasts(t => t.filter(x => x.id !== id)), 4000)
    }, [])
    return { toasts, add }
}

// ── Login Page ────────────────────────────────────────────
function LoginPage({ onLogin }) {
    const [email, setEmail] = useState('')
    const [password, setPassword] = useState('')
    const [loading, setLoading] = useState(false)
    const [error, setError] = useState('')

    const handleSubmit = async (e) => {
        e.preventDefault()
        setError('')
        setLoading(true)
        try {
            const data = await apiLogin(email, password)
            onLogin(data.access_token)
        } catch (err) {
            setError(err.message)
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className="login-page">
            <div className="login-card">
                <div className="login-logo">
                    <div className="login-logo-icon">📡</div>
                    <h1 className="login-title">SafeTrack Admin</h1>
                    <p className="login-subtitle">Panneau de gestion technique des boîtiers LoRaWAN</p>
                </div>

                <form className="login-form" onSubmit={handleSubmit}>
                    {error && <div className="alert alert-error">⚠️ {error}</div>}
                    <div className="form-group">
                        <label className="form-label">Email administrateur</label>
                        <input
                            className="form-input"
                            type="email"
                            placeholder="admin@safetrack.cm"
                            value={email}
                            onChange={e => setEmail(e.target.value)}
                            required
                            autoFocus
                        />
                    </div>
                    <div className="form-group">
                        <label className="form-label">Mot de passe</label>
                        <input
                            className="form-input"
                            type="password"
                            placeholder="••••••••"
                            value={password}
                            onChange={e => setPassword(e.target.value)}
                            required
                        />
                    </div>
                    <button className="btn btn-primary login-btn" type="submit" disabled={loading}>
                        {loading ? <><span className="spinner" /> Connexion…</> : '🔐 Se connecter'}
                    </button>
                </form>
            </div>
        </div>
    )
}

// ── Status Badge ──────────────────────────────────────────
function StatusBadge({ status }) {
    const map = {
        DISPONIBLE: { cls: 'badge-disponible', label: 'DISPONIBLE' },
        ACTIF: { cls: 'badge-actif', label: 'ACTIF' },
    }
    const { cls, label } = map[status] || { cls: 'badge-default', label: status }
    return <span className={`badge ${cls}`}>{label}</span>
}

// ── Provision Form ────────────────────────────────────────
function ProvisionForm({ token, onProvisioned }) {
    const [deveui, setDeveui] = useState('')
    const [deviceName, setDeviceName] = useState('')
    const [deviceDescription, setDeviceDescription] = useState('')
    const [loading, setLoading] = useState(false)
    const [error, setError] = useState('')

    const isValidHex = (v) => v.length === 16 && /^[0-9A-Fa-f]{16}$/.test(v)

    const handleSubmit = async (e) => {
        e.preventDefault()
        setError('')
        const val = deveui.trim().toUpperCase()
        if (!isValidHex(val)) {
            setError('DevEUI invalide. Doit contenir exactement 16 caractères hexadécimaux.')
            return
        }
        if (!deviceName.trim()) {
            setError('Le nom du device est requis.')
            return
        }
        setLoading(true)
        try {
            await apiFetch('/vehicles/provision', token, {
                method: 'POST',
                body: JSON.stringify({
                    deveui: val,
                    device_name: deviceName.trim(),
                    device_description: deviceDescription.trim(),
                }),
            })
            setDeveui('')
            setDeviceName('')
            setDeviceDescription('')
            onProvisioned(val)
        } catch (err) {
            setError(err.message)
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className="card">
            <div className="card-header">
                <div>
                    <p className="card-title"><span className="card-title-icon">➕</span> Enregistrer un nouveau boîtier</p>
                    <p className="card-subtitle">Saisir le DevEUI et les informations du device LoRaWAN</p>
                </div>
            </div>
            <form onSubmit={handleSubmit}>
                {error && <div className="alert alert-error" style={{ marginBottom: '16px' }}>⚠️ {error}</div>}
                <div className="provision-form">
                    <div className="form-group">
                        <label className="form-label">DevEUI du boîtier</label>
                        <input
                            className="form-input"
                            type="text"
                            placeholder="A1B2C3D4E5F60001"
                            value={deveui}
                            onChange={e => setDeveui(e.target.value.toUpperCase())}
                            maxLength={16}
                            spellCheck={false}
                            autoComplete="off"
                        />
                        <span className="form-hint">{deveui.length}/16 caractères · Hexadécimal uniquement</span>
                    </div>
                    <div className="form-group">
                        <label className="form-label">Nom du device <span style={{ color: 'var(--accent)' }}>*</span></label>
                        <input
                            className="form-input"
                            type="text"
                            placeholder="ex. Tracker-Camion-001"
                            value={deviceName}
                            onChange={e => setDeviceName(e.target.value)}
                            maxLength={128}
                            autoComplete="off"
                        />
                        <span className="form-hint">Nom affiché dans ChirpStack (obligatoire)</span>
                    </div>
                    <div className="form-group">
                        <label className="form-label">Description du device</label>
                        <input
                            className="form-input"
                            type="text"
                            placeholder="ex. Boîtier installé sur Hilux immat CM-001"
                            value={deviceDescription}
                            onChange={e => setDeviceDescription(e.target.value)}
                            maxLength={256}
                            autoComplete="off"
                        />
                        <span className="form-hint">Description optionnelle transmise à ChirpStack</span>
                    </div>
                    <button
                        className="btn btn-primary"
                        type="submit"
                        disabled={loading || deveui.length !== 16 || !deviceName.trim()}
                        style={{ marginBottom: '20px' }}
                    >
                        {loading ? <><span className="spinner" /> Enregistrement…</> : '📥 Enregistrer dans SafeTrack & ChirpStack'}
                    </button>
                </div>
            </form>
        </div>
    )
}


// ── Confirm Modal ─────────────────────────────────────────
function ConfirmModal({ isOpen, title, message, onConfirm, onCancel, confirmLabel = 'Confirmer', danger = false }) {
    if (!isOpen) return null
    return (
        <div style={{
            position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)',
            zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center'
        }}>
            <div style={{
                background: 'var(--surface)', borderRadius: 16, padding: 32, width: 400,
                border: '1px solid var(--border)', boxShadow: '0 24px 64px rgba(0,0,0,0.5)'
            }}>
                <h3 style={{ margin: '0 0 12px', fontSize: '1.1rem' }}>{title}</h3>
                <p style={{ color: 'var(--text-secondary)', margin: '0 0 28px', lineHeight: 1.5 }}>{message}</p>
                <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end' }}>
                    <button className="btn" onClick={onCancel} style={{ color: 'var(--text-secondary)' }}>Annuler</button>
                    <button
                        className={`btn ${danger ? 'btn-danger' : 'btn-primary'}`}
                        onClick={onConfirm}
                    >{confirmLabel}</button>
                </div>
            </div>
        </div>
    )
}

// ── Device Table ──────────────────────────────────────────
function DeviceTable({ devices, loading, token, onUpdated }) {
    const [actionId, setActionId] = useState(null)
    const [modal, setModal] = useState(null) // { type: 'release'|'delete', vehicle }

    const performAction = async () => {
        if (!modal) return
        const { type, vehicle } = modal
        setModal(null)
        setActionId(vehicle.id_vehicule)
        try {
            if (type === 'release') {
                await apiFetch(`/vehicles/${vehicle.id_vehicule}/release`, token, { method: 'POST' })
                onUpdated({ type: 'release', id: vehicle.id_vehicule, deveui: vehicle.deveui })
            } else {
                await apiFetch(`/vehicles/${vehicle.id_vehicule}`, token, { method: 'DELETE' })
                onUpdated({ type: 'delete', id: vehicle.id_vehicule, deveui: vehicle.deveui })
            }
        } catch (err) {
            alert(`Erreur : ${err.message}`)
        } finally {
            setActionId(null)
        }
    }

    const fmt = (dt) => dt
        ? new Date(dt).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })
        : '—'

    return (
        <div className="card">
            <ConfirmModal
                isOpen={!!modal}
                title={modal?.type === 'release' ? '🔄 Libérer le boîtier' : '🗑️ Supprimer définitivement'}
                message={
                    modal?.type === 'release'
                        ? `Le boîtier ${modal?.vehicle?.deveui} sera dissocié du véhicule "${modal?.vehicle?.nom || 'N/A'}" et repassera en statut DISPONIBLE. Il reste dans ChirpStack et peut être re-appairé immédiatement.`
                        : `La suppression du boîtier ${modal?.vehicle?.deveui} est irréversible. Il sera retiré de SafeTrack et de ChirpStack.`
                }
                onConfirm={performAction}
                onCancel={() => setModal(null)}
                confirmLabel={modal?.type === 'release' ? 'Libérer le boîtier' : 'Supprimer'}
                danger={modal?.type === 'delete'}
            />

            <div className="card-header">
                <div>
                    <p className="card-title"><span className="card-title-icon">📋</span> Boîtiers enregistrés</p>
                    <p className="card-subtitle">{devices.length} dispositif{devices.length !== 1 ? 's' : ''} dans la base</p>
                </div>
            </div>

            {loading && devices.length === 0 ? (
                <div className="empty-state">
                    <div className="empty-state-icon">⏳</div>
                    Chargement…
                </div>
            ) : devices.length === 0 ? (
                <div className="empty-state">
                    <div className="empty-state-icon">📦</div>
                    Aucun boîtier enregistré. Commencez par en ajouter un ci-dessus.
                </div>
            ) : (
                <div className="table-wrap">
                    <table className="devices-table">
                        <thead>
                            <tr>
                                <th>DevEUI</th>
                                <th>Nom / Véhicule</th>
                                <th>Immatriculation</th>
                                <th>Statut</th>
                                <th>Enregistré le</th>
                                <th>Activé le</th>
                                <th>Propriétaire ID</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {devices.map(v => (
                                <tr key={v.id_vehicule}>
                                    <td className="deveui-cell">{v.deveui}</td>
                                    <td>{v.nom || <span style={{ color: 'var(--text-muted)' }}>—</span>}</td>
                                    <td style={{ color: 'var(--text-secondary)', fontSize: '0.82rem' }}>
                                        {v.immatriculation || <span style={{ color: 'var(--text-muted)' }}>—</span>}
                                    </td>
                                    <td><StatusBadge status={v.statut} /></td>
                                    <td style={{ color: 'var(--text-secondary)', fontSize: '0.82rem' }}>{fmt(v.created_at)}</td>
                                    <td style={{ color: 'var(--text-secondary)', fontSize: '0.82rem' }}>{fmt(v.activated_at)}</td>
                                    <td style={{ color: 'var(--text-secondary)', fontSize: '0.82rem' }}>
                                        {v.id_utilisateur_proprietaire ?? <span style={{ color: 'var(--text-muted)' }}>—</span>}
                                    </td>
                                    <td>
                                        <div style={{ display: 'flex', gap: 6 }}>
                                            {v.statut === 'ACTIF' && (
                                                <button
                                                    className="btn"
                                                    onClick={() => setModal({ type: 'release', vehicle: v })}
                                                    disabled={actionId === v.id_vehicule}
                                                    title="Libérer ce boîtier pour transfert sur un autre véhicule"
                                                    style={{
                                                        fontSize: '0.78rem', padding: '4px 10px',
                                                        background: 'rgba(245,158,11,0.1)',
                                                        border: '1px solid rgba(245,158,11,0.4)',
                                                        color: '#f59e0b'
                                                    }}
                                                >
                                                    {actionId === v.id_vehicule ? <span className="spinner" style={{ width: 12, height: 12 }} /> : '🔄 Libérer'}
                                                </button>
                                            )}
                                            {v.statut === 'DISPONIBLE' && (
                                                <button
                                                    className="btn btn-danger"
                                                    onClick={() => setModal({ type: 'delete', vehicle: v })}
                                                    disabled={actionId === v.id_vehicule}
                                                    title="Supprimer définitivement ce boîtier non appairé"
                                                    style={{ fontSize: '0.78rem', padding: '4px 10px' }}
                                                >
                                                    {actionId === v.id_vehicule ? <span className="spinner" style={{ width: 12, height: 12 }} /> : '🗑️ Supprimer'}
                                                </button>
                                            )}
                                        </div>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    )
}

// ── Dashboard ─────────────────────────────────────────────
function Dashboard({ token, userEmail, onLogout }) {
    const [devices, setDevices] = useState([])
    const [fetching, setFetching] = useState(false)
    const [lastRefresh, setLastRefresh] = useState(null)
    const { toasts, add: addToast } = useToasts()
    const intervalRef = useRef(null)

    const fetchDevices = useCallback(async () => {
        setFetching(true)
        try {
            const data = await apiFetch('/vehicles/', token)
            setDevices(data)
            setLastRefresh(new Date())
        } catch (err) {
            addToast(`Erreur de chargement : ${err.message}`, 'error')
        } finally {
            setFetching(false)
        }
    }, [token, addToast])

    useEffect(() => {
        fetchDevices()
        intervalRef.current = setInterval(fetchDevices, 30000)
        return () => clearInterval(intervalRef.current)
    }, [fetchDevices])

    const handleProvisioned = (deveui) => {
        addToast(`✅ Boîtier ${deveui} enregistré avec succès`, 'success')
        fetchDevices()
    }

    const handleUpdated = ({ type, id, deveui }) => {
        if (type === 'delete') {
            setDevices(prev => prev.filter(d => d.id_vehicule !== id))
            addToast(`🗑️ Boîtier ${deveui} supprimé définitivement`, 'success')
        } else if (type === 'release') {
            // Refresh full list so the row shows updated DISPONIBLE status
            fetchDevices()
            addToast(`🔄 Boîtier ${deveui} libéré — prêt pour re-appairage`, 'success')
        }
    }

    const total = devices.length
    const disponibles = devices.filter(d => d.statut === 'DISPONIBLE').length
    const actifs = devices.filter(d => d.statut === 'ACTIF').length

    return (
        <div className="admin-layout">
            <nav className="navbar">
                <div className="navbar-brand">
                    <div className="navbar-brand-dot" />
                    SafeTrack · Tech Admin
                </div>
                <div className="navbar-meta">
                    <div className="refresh-badge">
                        <div className="refresh-dot" />
                        Actualisation auto · {lastRefresh ? lastRefresh.toLocaleTimeString('fr-FR', { timeStyle: 'short' }) : '…'}
                    </div>
                    <span className="navbar-user">🔑 {userEmail}</span>
                    <button className="btn-logout" onClick={onLogout}>Déconnexion</button>
                </div>
            </nav>

            <main className="main-content">
                {/* Stats */}
                <div className="stats-bar">
                    <div className="stat-item">
                        <span className="stat-label">Total boîtiers</span>
                        <span className="stat-value accent">{total}</span>
                    </div>
                    <div className="stat-item">
                        <span className="stat-label">Disponibles</span>
                        <span className="stat-value warning">{disponibles}</span>
                    </div>
                    <div className="stat-item">
                        <span className="stat-label">Actifs (appairés)</span>
                        <span className="stat-value success">{actifs}</span>
                    </div>
                </div>

                {/* Provision form */}
                <ProvisionForm token={token} onProvisioned={handleProvisioned} />

                {/* Device table */}
                <DeviceTable
                    devices={devices}
                    loading={fetching}
                    token={token}
                    onUpdated={handleUpdated}
                />
            </main>

            {/* Toast notifications */}
            <div className="toast-container">
                {toasts.map(t => (
                    <div key={t.id} className={`toast toast-${t.type}`}>{t.message}</div>
                ))}
            </div>
        </div>
    )
}

// ── App root ──────────────────────────────────────────────
export default function App() {
    const [token, setToken] = useState(() => sessionStorage.getItem('st_admin_token'))
    const [email, setEmail] = useState(() => sessionStorage.getItem('st_admin_email') || '')

    const handleLogin = (newToken, userEmail) => {
        // We don't get email from login, store the form email separately
        sessionStorage.setItem('st_admin_token', newToken)
        setToken(newToken)
    }

    const handleLoginWithEmail = async (newToken) => {
        sessionStorage.setItem('st_admin_token', newToken)
        // Fetch own profile to get email for display
        try {
            const me = await fetch('/api/v1/users/me', {
                headers: { Authorization: `Bearer ${newToken}` },
            }).then(r => r.json())
            const e = me.email || ''
            sessionStorage.setItem('st_admin_email', e)
            setEmail(e)
        } catch (_) { }
        setToken(newToken)
    }

    const handleLogout = () => {
        sessionStorage.removeItem('st_admin_token')
        sessionStorage.removeItem('st_admin_email')
        setToken(null)
        setEmail('')
    }

    if (!token) {
        return <LoginPage onLogin={handleLoginWithEmail} />
    }

    return (
        <Dashboard
            token={token}
            userEmail={email}
            onLogout={handleLogout}
        />
    )
}
