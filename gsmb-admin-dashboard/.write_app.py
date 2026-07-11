"""
GSMB App.tsx JSX render section writer
Writes the complete new App.tsx with clean theming
"""

# Read existing logic (lines 1-1161)
with open('/home/dineth_thenuwara/gsmb-admin-dashboard_Temp/src/App.tsx', 'r') as f:
    lines = f.readlines()

# Keep lines 1-1161 (logic section)
logic_section = ''.join(lines[:1161])  # 0-indexed, lines 1-1161

# New render section
render_section = r"""
  // Derived theme class for root element
  const isDark = theme === 'dark';
  const themeClass = isDark ? 'dark-theme' : 'light-theme';

  // ─── Auth Loading Screen ────────────────────────────────────────
  if (authLoading && !authToken) {
    return (
      <div className={`${themeClass} min-h-screen g-bg flex items-center justify-center`}>
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-indigo-600 flex items-center justify-center">
            <ShieldAlert className="w-5 h-5 text-white" />
          </div>
          <Activity className="w-5 h-5 text-indigo-500 animate-pulse" />
          <span style={{ color: 'var(--text-3)', fontSize: 11, letterSpacing: '0.1em', fontFamily: 'monospace' }}>
            VERIFYING CREDENTIALS...
          </span>
        </div>
      </div>
    );
  }

  // ─── Login / Invite Screen ─────────────────────────────────────
  if (!authToken || !authUser) {
    return (
      <div className={`${themeClass} min-h-screen g-bg flex items-center justify-center p-4`}>
        {/* Background gradient */}
        <div style={{
          position: 'fixed', inset: 0, pointerEvents: 'none', zIndex: 0,
          background: isDark
            ? 'radial-gradient(ellipse 80% 50% at 50% -20%, rgba(99,102,241,0.08) 0%, transparent 70%)'
            : 'radial-gradient(ellipse 80% 50% at 50% -20%, rgba(99,102,241,0.05) 0%, transparent 70%)',
        }} />

        <div style={{ position: 'relative', zIndex: 1, width: '100%', maxWidth: 420 }}>
          {/* Logo & brand */}
          <div style={{ textAlign: 'center', marginBottom: 32 }}>
            <div style={{
              width: 48, height: 48, borderRadius: 14,
              background: 'rgb(99,102,241)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              margin: '0 auto 16px',
              boxShadow: '0 8px 24px rgba(99,102,241,0.3)',
            }}>
              <ShieldAlert style={{ width: 24, height: 24, color: '#fff' }} />
            </div>
            <h1 style={{ color: 'var(--text)', fontSize: 22, fontWeight: 800, margin: 0 }}>GSMB GeoTrust</h1>
            <p style={{ color: 'var(--text-3)', fontSize: 12, marginTop: 4, letterSpacing: '0.08em', textTransform: 'uppercase', fontFamily: 'monospace' }}>
              Oversight Portal
            </p>
          </div>

          <div className="card" style={{ padding: '32px' }}>
            {inviteToken ? (
              /* Invite / Password Setup */
              <form onSubmit={handleSetPasswordSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div style={{ textAlign: 'center', marginBottom: 8 }}>
                  <h2 style={{ color: 'var(--text)', fontSize: 18, fontWeight: 700, margin: 0 }}>Create Password</h2>
                  <p style={{ color: 'var(--text-2)', fontSize: 13, marginTop: 6 }}>
                    Set a secure password for your administrator account.
                  </p>
                </div>
                {setPasswordSuccess && (
                  <div style={{
                    padding: '12px 16px', borderRadius: 10,
                    background: 'rgba(16,185,129,0.1)', border: '1px solid rgba(16,185,129,0.2)',
                    color: '#10b981', fontSize: 13, display: 'flex', alignItems: 'center', gap: 8,
                  }}>
                    <CheckCircle2 style={{ width: 16, height: 16, flexShrink: 0 }} />
                    Password set! Please sign in below.
                  </div>
                )}
                {authError && (
                  <div style={{
                    padding: '12px 16px', borderRadius: 10,
                    background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.2)',
                    color: '#ef4444', fontSize: 13,
                  }}>{authError}</div>
                )}
                <div>
                  <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 6 }}>
                    New Password
                  </label>
                  <input
                    className="g-input"
                    type="password"
                    placeholder="Min. 6 characters"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    required
                  />
                </div>
                <div>
                  <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 6 }}>
                    Confirm Password
                  </label>
                  <input
                    className="g-input"
                    type="password"
                    placeholder="Re-enter password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    required
                  />
                </div>
                <button
                  type="submit"
                  className="btn btn-primary btn-md"
                  disabled={authLoading}
                  style={{ width: '100%', marginTop: 4 }}
                >
                  {authLoading ? <RotateCw style={{ width: 14, height: 14, animation: 'spin 1s linear infinite' }} /> : null}
                  {authLoading ? 'Setting Password...' : 'Set Password & Continue'}
                </button>
              </form>
            ) : (
              /* Sign In */
              <form onSubmit={handleLoginSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div style={{ marginBottom: 4 }}>
                  <h2 style={{ color: 'var(--text)', fontSize: 18, fontWeight: 700, margin: 0 }}>Sign in</h2>
                  <p style={{ color: 'var(--text-2)', fontSize: 13, marginTop: 4 }}>
                    Enter your administrator credentials to continue.
                  </p>
                </div>
                {authError && (
                  <div style={{
                    padding: '12px 16px', borderRadius: 10,
                    background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.2)',
                    color: '#ef4444', fontSize: 13, display: 'flex', alignItems: 'center', gap: 8,
                  }}>
                    <XCircle style={{ width: 16, height: 16, flexShrink: 0 }} />
                    {authError}
                  </div>
                )}
                <div>
                  <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 6 }}>
                    Email Address
                  </label>
                  <input
                    className="g-input"
                    type="email"
                    placeholder="admin@gsmb.gov.lk"
                    value={authEmail}
                    onChange={(e) => setAuthEmail(e.target.value)}
                    autoComplete="email"
                    required
                  />
                </div>
                <div>
                  <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 6 }}>
                    Password
                  </label>
                  <input
                    className="g-input"
                    type="password"
                    placeholder="••••••••"
                    value={authPassword}
                    onChange={(e) => setAuthPassword(e.target.value)}
                    autoComplete="current-password"
                    required
                  />
                </div>
                <button
                  type="submit"
                  className="btn btn-primary btn-md"
                  disabled={authLoading}
                  style={{ width: '100%', marginTop: 4 }}
                >
                  {authLoading ? <RotateCw style={{ width: 14, height: 14, animation: 'spin 1s linear infinite' }} /> : null}
                  {authLoading ? 'Authenticating...' : 'Sign In'}
                </button>
              </form>
            )}
          </div>

          {/* Footer note */}
          <p style={{ color: 'var(--text-3)', fontSize: 11, textAlign: 'center', marginTop: 20 }}>
            GSMB GeoTrust · Geological Survey & Mines Bureau, Sri Lanka
          </p>
        </div>
      </div>
    );
  }

  // ─── Main App ──────────────────────────────────────────────────
  const ownerInfo = getRecordOwnerInfo(activeRecord);
  const ITEMS_PER_PAGE = 5;

  const metricConfig = [
    { icon: MapPin,       color: '#6366f1', label: 'Tracked Locations' },
    { icon: AlertTriangle,color: '#ef4444', label: 'Open Overloads' },
    { icon: XCircle,      color: '#f59e0b', label: 'Fraud Flags' },
    { icon: Truck,        color: '#10b981', label: 'Active Permits' },
  ];

  return (
    <div className={`${themeClass} g-bg`} style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>

      {/* ── HEADER ───────────────────────────────────────────────── */}
      <header style={{
        position: 'sticky', top: 0, zIndex: 50,
        backgroundColor: isDark ? 'rgba(9,9,11,0.8)' : 'rgba(244,244,245,0.8)',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
        borderBottom: `1px solid var(--border)`,
      }}>
        <div style={{
          maxWidth: 1400, margin: '0 auto',
          padding: '0 20px',
          height: 60,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16,
        }}>
          {/* Logo */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0 }}>
            <div style={{
              width: 32, height: 32, borderRadius: 9,
              background: 'rgb(99,102,241)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 4px 12px rgba(99,102,241,0.3)',
            }}>
              <ShieldAlert style={{ width: 16, height: 16, color: '#fff' }} />
            </div>
            <div>
              <span style={{ color: 'var(--text)', fontWeight: 800, fontSize: 14, letterSpacing: '-0.02em' }}>
                GSMB GeoTrust
              </span>
              <span style={{ display: 'none' }} className="sm:!inline" >
                <span style={{ color: 'var(--text-3)', fontSize: 11, marginLeft: 8 }}>Oversight v2.0</span>
              </span>
            </div>
          </div>

          {/* Center Nav */}
          <nav style={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            {([
              ['dashboard', 'Dashboard'],
              ['registry', 'Registry'],
              ['register', 'Register'],
              ['about', 'About'],
              ['contact', 'Contact'],
            ] as const).map(([page, label]) => (
              <button
                key={page}
                onClick={() => setActivePage(page)}
                className={`nav-btn${activePage === page ? ' active' : ''}`}
              >
                {label}
              </button>
            ))}
          </nav>

          {/* Right controls */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
            {/* Theme toggle */}
            <button
              onClick={() => setTheme(isDark ? 'light' : 'dark')}
              className="btn btn-ghost btn-sm"
              title="Toggle theme"
            >
              {isDark ? <Sun style={{ width: 14, height: 14 }} /> : <Moon style={{ width: 14, height: 14 }} />}
            </button>

            {/* Export */}
            <button onClick={handleExport} className="btn btn-ghost btn-sm">
              <Download style={{ width: 14, height: 14 }} />
              <span>Export</span>
            </button>

            {/* User / logout */}
            <button onClick={handleLogout} className="btn btn-ghost btn-sm">
              <User style={{ width: 14, height: 14 }} />
              <span style={{ maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {authUser?.email?.split('@')[0] || 'Admin'}
              </span>
            </button>
          </div>
        </div>
      </header>

      {/* ── MAIN ─────────────────────────────────────────────────── */}
      <main style={{ flex: 1, maxWidth: 1400, margin: '0 auto', width: '100%', padding: '28px 20px 48px' }}>

        {/* Live info bar */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          marginBottom: 24, flexWrap: 'wrap', gap: 8,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="dot dot-green" />
            <span style={{ color: 'var(--text-3)', fontSize: 12 }}>
              {loading ? 'Syncing telemetry...' : `${data.records.length} nodes active`}
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Clock style={{ width: 13, height: 13, color: 'var(--text-3)' }} />
            <span style={{ color: 'var(--text-3)', fontSize: 12, fontFamily: 'monospace' }}>
              {liveDateTime.toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' })}
            </span>
            <button
              onClick={loadData}
              title="Refresh data"
              style={{
                background: 'none', border: 'none', cursor: 'pointer',
                color: 'var(--text-3)', padding: '2px 4px', borderRadius: 6,
                display: 'flex', alignItems: 'center',
              }}
            >
              <RotateCw style={{ width: 13, height: 13, ...(loading ? { animation: 'spin 1s linear infinite' } : {}) }} />
            </button>
          </div>
        </div>

        {/* Error banner */}
        {error && (
          <div style={{
            padding: '14px 18px', borderRadius: 12,
            background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.2)',
            color: '#ef4444', fontSize: 13, marginBottom: 24,
            display: 'flex', alignItems: 'center', gap: 8,
          }}>
            <AlertTriangle style={{ width: 16, height: 16, flexShrink: 0 }} />
            <span>Database connection error: {error}</span>
            <button
              onClick={loadData}
              style={{
                marginLeft: 'auto', background: 'rgba(239,68,68,0.15)',
                border: 'none', borderRadius: 8, padding: '5px 12px',
                color: '#ef4444', fontSize: 12, fontWeight: 600, cursor: 'pointer',
              }}
            >
              Retry
            </button>
          </div>
        )}

        <AnimatePresence mode="wait">

          {/* ═══════════════ DASHBOARD VIEW ════════════════════════ */}
          {activePage === 'dashboard' && (
            <motion.div
              key="dashboard"
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -12 }}
              transition={{ duration: 0.2 }}
              style={{ display: 'flex', flexDirection: 'column', gap: 24 }}
            >
              {/* Metrics grid */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 16 }}>
                {data.metrics.map((metric, i) => {
                  const Ic = metricConfig[i]?.icon || Activity;
                  const color = metricConfig[i]?.color || '#6366f1';
                  return (
                    <div
                      key={i}
                      className="metric-card"
                      onClick={() => handleMetricClick(i)}
                    >
                      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 16 }}>
                        <div style={{
                          width: 36, height: 36, borderRadius: 10,
                          background: `${color}1a`, border: `1px solid ${color}33`,
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                        }}>
                          <Ic style={{ width: 16, height: 16, color }} />
                        </div>
                        <ChevronRight style={{ width: 16, height: 16, color: 'var(--text-3)' }} />
                      </div>
                      <div style={{ fontSize: 32, fontWeight: 800, color: 'var(--text)', letterSpacing: '-0.03em', lineHeight: 1 }}>
                        {loading ? '—' : metric.value}
                      </div>
                      <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text)', marginTop: 6 }}>
                        {metric.label}
                      </div>
                      <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 3 }}>
                        {metric.note}
                      </div>
                      <Ic className="icon-bg" style={{ width: 80, height: 80, color }} />
                    </div>
                  );
                })}
              </div>

              {/* Map + Charts row */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 16 }}>
                <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0,1fr) 340px', gap: 16 }}>
                  {/* Map */}
                  <div className="card" style={{ padding: 24 }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
                      <div>
                        <div style={{ fontSize: 11, fontWeight: 700, color: '#6366f1', letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 2 }}>
                          Live Geo-Tracking
                        </div>
                        <h2 style={{ fontSize: 18, fontWeight: 700, color: 'var(--text)', margin: 0 }}>
                          Active Mineral Transit Hotspots
                        </h2>
                      </div>
                      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                        {['high', 'medium', 'low'].map((r) => {
                          const c = r === 'high' ? '#ef4444' : r === 'medium' ? '#f59e0b' : '#10b981';
                          return (
                            <div key={r} style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                              <span style={{ width: 8, height: 8, borderRadius: '50%', background: c, display: 'inline-block' }} />
                              <span style={{ fontSize: 11, color: 'var(--text-3)', textTransform: 'capitalize' }}>{r}</span>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                    <MapComponent
                      records={filteredRecords}
                      activeRecordId={activeRecordId}
                      onSelectRecord={setActiveRecordId}
                      theme={theme}
                    />
                  </div>

                  {/* Chart column */}
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                    <div className="card" style={{ padding: 24, flex: 1 }}>
                      <div style={{ fontSize: 11, fontWeight: 700, color: '#ef4444', letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 2 }}>
                        Incident Trend
                      </div>
                      <h3 style={{ fontSize: 15, fontWeight: 700, color: 'var(--text)', margin: '0 0 16px' }}>
                        Overloads vs Fraud
                      </h3>
                      <IncidentTrendChart data={data.incidentSeries} theme={theme} />
                    </div>
                    <div className="card" style={{ padding: 24, flex: 1 }}>
                      <div style={{ fontSize: 11, fontWeight: 700, color: '#f59e0b', letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 2 }}>
                        Status Distribution
                      </div>
                      <h3 style={{ fontSize: 15, fontWeight: 700, color: 'var(--text)', margin: '0 0 16px' }}>
                        Permit Compliance
                      </h3>
                      <PermitStatusChart data={data.statusCounts} theme={theme} />
                    </div>
                  </div>
                </div>
              </div>

              {/* Filters */}
              <div className="card" style={{ padding: 20 }} id="targeted-registries">
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                  <div>
                    <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 8 }}>
                      Filter by Region
                    </label>
                    <select
                      className="g-input"
                      id="region"
                      value={selectedRegion}
                      onChange={(e) => setSelectedRegion(e.target.value)}
                      style={{ appearance: 'none', cursor: 'pointer' }}
                    >
                      <option value="all">All Districts</option>
                      {regionsList.map((r) => <option key={r} value={r}>{r}</option>)}
                    </select>
                  </div>
                  <div>
                    <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 8 }}>
                      Filter by Risk
                    </label>
                    <select
                      className="g-input"
                      id="risk"
                      value={selectedRisk}
                      onChange={(e) => setSelectedRisk(e.target.value)}
                      style={{ appearance: 'none', cursor: 'pointer' }}
                    >
                      <option value="all">All Risk Levels</option>
                      <option value="high">High Risk</option>
                      <option value="medium">Medium Risk</option>
                      <option value="low">Low Risk</option>
                    </select>
                  </div>
                </div>
              </div>

              {/* Location Tabs + Table */}
              <div className="card" style={{ overflow: 'hidden' }}>
                {/* Tab bar */}
                <div style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                  padding: '16px 20px', borderBottom: '1px solid var(--border)', flexWrap: 'wrap', gap: 12,
                }}>
                  <div className="seg-control" style={{ width: 'auto' }}>
                    {([['all', 'All'], ['mine', 'Mines'], ['hardware', 'Hardware']] as const).map(([tab, label]) => (
                      <button
                        key={tab}
                        onClick={() => setActiveTypeTab(tab)}
                        className={`seg-btn${activeTypeTab === tab ? ' active' : ''}`}
                        style={{ flex: 'none', paddingLeft: 16, paddingRight: 16 }}
                      >
                        {tab === 'mine' && <HardHat style={{ width: 12, height: 12 }} />}
                        {tab === 'hardware' && <Building2 style={{ width: 12, height: 12 }} />}
                        {label}
                      </button>
                    ))}
                  </div>

                  <div style={{ position: 'relative', width: 220 }}>
                    <Search style={{
                      width: 14, height: 14, position: 'absolute', left: 10, top: '50%',
                      transform: 'translateY(-50%)', color: 'var(--text-3)',
                    }} />
                    <input
                      className="g-input"
                      style={{ paddingLeft: 32 }}
                      placeholder="Search locations..."
                      value={activeTypeTab === 'all' ? generalSearch : activeTypeTab === 'mine' ? minesSearch : hardwareSearch}
                      onChange={(e) => {
                        if (activeTypeTab === 'all') setGeneralSearch(e.target.value);
                        else if (activeTypeTab === 'mine') setMinesSearch(e.target.value);
                        else setHardwareSearch(e.target.value);
                      }}
                    />
                  </div>
                </div>

                {/* Table */}
                <div style={{ overflowX: 'auto' }}>
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>Name</th>
                        <th>Type</th>
                        <th>Region</th>
                        <th>Stock</th>
                        <th>Risk</th>
                        <th>Incidents</th>
                        <th>Last Permit</th>
                      </tr>
                    </thead>
                    <tbody>
                      {loading ? (
                        <tr>
                          <td colSpan={7} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-3)' }}>
                            <RotateCw style={{ width: 18, height: 18, display: 'inline-block', animation: 'spin 1s linear infinite' }} />
                          </td>
                        </tr>
                      ) : paginatedRecords.length === 0 ? (
                        <tr>
                          <td colSpan={7} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-3)', fontSize: 13 }}>
                            No locations match the current filters.
                          </td>
                        </tr>
                      ) : paginatedRecords.map((record) => {
                        const isActive = record.id === activeRecordId;
                        const riskColor = record.risk === 'high' ? '#ef4444' : record.risk === 'medium' ? '#f59e0b' : '#10b981';
                        const riskBadge = record.risk === 'high' ? 'badge-rose' : record.risk === 'medium' ? 'badge-amber' : 'badge-emerald';
                        const pct = Math.min(100, Math.round((record.inventory / record.maxCapacity) * 100));
                        return (
                          <tr
                            key={record.id}
                            onClick={() => { setActiveRecordId(record.id); setActivePage('dashboard'); }}
                            style={isActive ? { backgroundColor: 'var(--elevated)' } : {}}
                          >
                            <td>
                              <div style={{ fontWeight: 600, color: 'var(--text)', fontSize: 13 }}>{record.name}</div>
                              <div style={{ fontSize: 11, color: 'var(--text-3)', fontFamily: 'monospace', marginTop: 2 }}>
                                {record.id.slice(0, 12)}...
                              </div>
                            </td>
                            <td>
                              <span className={`badge ${record.type === 'Mine' ? 'badge-indigo' : 'badge-zinc'}`}>
                                {record.type === 'Mine'
                                  ? <HardHat style={{ width: 10, height: 10 }} />
                                  : <Building2 style={{ width: 10, height: 10 }} />}
                                {record.type}
                              </span>
                            </td>
                            <td style={{ color: 'var(--text-2)', fontSize: 13 }}>{record.region}</td>
                            <td style={{ minWidth: 100 }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                <div style={{
                                  flex: 1, height: 4, borderRadius: 2,
                                  background: 'var(--elevated)', overflow: 'hidden',
                                }}>
                                  <div style={{
                                    height: '100%', width: `${pct}%`, borderRadius: 2,
                                    background: record.isOverloaded ? '#ef4444' : pct > 75 ? '#f59e0b' : '#10b981',
                                    transition: 'width 0.3s ease',
                                  }} />
                                </div>
                                <span style={{ fontSize: 12, color: 'var(--text-2)', fontFamily: 'monospace', flexShrink: 0 }}>
                                  {record.inventory}m³
                                </span>
                              </div>
                            </td>
                            <td>
                              <span className={`badge ${riskBadge}`}>
                                <span style={{ width: 5, height: 5, borderRadius: '50%', background: riskColor, flexShrink: 0 }} />
                                {record.risk.charAt(0).toUpperCase() + record.risk.slice(1)}
                              </span>
                            </td>
                            <td style={{ color: record.incidents > 0 ? '#ef4444' : 'var(--text-3)', fontSize: 13, fontWeight: record.incidents > 0 ? 700 : 400 }}>
                              {record.incidents}
                            </td>
                            <td style={{ color: 'var(--text-2)', fontSize: 12, fontFamily: 'monospace' }}>
                              {record.permit !== 'N/A' ? record.permit : <span style={{ color: 'var(--text-3)' }}>—</span>}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>

                {/* Pagination */}
                {totalPages > 1 && (
                  <div style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                    padding: '12px 20px', borderTop: '1px solid var(--border)',
                  }}>
                    <span style={{ fontSize: 12, color: 'var(--text-3)' }}>
                      Page {locationsCurrentPage} of {totalPages} · {filteredRecords.length} results
                    </span>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button
                        onClick={() => setLocationsCurrentPage(p => Math.max(1, p - 1))}
                        disabled={locationsCurrentPage === 1}
                        className="btn btn-ghost btn-sm"
                      >← Prev</button>
                      <button
                        onClick={() => setLocationsCurrentPage(p => Math.min(totalPages, p + 1))}
                        disabled={locationsCurrentPage === totalPages}
                        className="btn btn-ghost btn-sm"
                      >Next →</button>
                    </div>
                  </div>
                )}
              </div>

              {/* Active Record Profile */}
              {activeRecord && (
                <div className="card" style={{ padding: 24 }}>
                  <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12, marginBottom: 20 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                      <div style={{
                        width: 48, height: 48, borderRadius: 14,
                        background: activeRecord.type === 'Mine' ? 'rgba(99,102,241,0.12)' : 'rgba(16,185,129,0.12)',
                        border: `1px solid ${activeRecord.type === 'Mine' ? 'rgba(99,102,241,0.25)' : 'rgba(16,185,129,0.25)'}`,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                      }}>
                        {activeRecord.type === 'Mine'
                          ? <HardHat style={{ width: 22, height: 22, color: '#6366f1' }} />
                          : <Building2 style={{ width: 22, height: 22, color: '#10b981' }} />}
                      </div>
                      <div>
                        <h3 style={{ fontSize: 18, fontWeight: 700, color: 'var(--text)', margin: 0 }}>{activeRecord.name}</h3>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
                          <span className={`badge ${activeRecord.type === 'Mine' ? 'badge-indigo' : 'badge-emerald'}`}>
                            {activeRecord.type}
                          </span>
                          <span style={{ color: 'var(--text-3)', fontSize: 12 }}>{activeRecord.region}</span>
                          {activeRecord.isOverloaded && (
                            <span className="badge badge-rose">Overloaded</span>
                          )}
                        </div>
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: 8 }}>
                      <button
                        onClick={() => { setActivePage('contact'); setFbLocationId(activeRecord.id); }}
                        className="btn btn-ghost btn-sm"
                      >
                        <Send style={{ width: 12, height: 12 }} />
                        File Report
                      </button>
                    </div>
                  </div>

                  {/* Status alert */}
                  {activeRecord.status && (
                    <div style={{
                      padding: '12px 16px', borderRadius: 10, marginBottom: 20,
                      background: activeRecord.isOverloaded ? 'rgba(239,68,68,0.08)' : activeRecord.risk === 'medium' ? 'rgba(245,158,11,0.08)' : 'rgba(16,185,129,0.08)',
                      border: `1px solid ${activeRecord.isOverloaded ? 'rgba(239,68,68,0.2)' : activeRecord.risk === 'medium' ? 'rgba(245,158,11,0.2)' : 'rgba(16,185,129,0.2)'}`,
                      display: 'flex', alignItems: 'center', gap: 8,
                      color: activeRecord.isOverloaded ? '#ef4444' : activeRecord.risk === 'medium' ? '#f59e0b' : '#10b981',
                      fontSize: 13,
                    }}>
                      <AlertTriangle style={{ width: 15, height: 15, flexShrink: 0 }} />
                      {activeRecord.status}
                    </div>
                  )}

                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 16 }}>
                    {[
                      { label: 'Stock Level', value: `${activeRecord.inventory} m³ / ${activeRecord.maxCapacity} m³` },
                      { label: 'Total Incidents', value: String(activeRecord.incidents) },
                      { label: 'Last Permit', value: activeRecord.permit },
                      { label: 'Last Truck', value: activeRecord.truck },
                      { label: 'Owner', value: ownerInfo.name },
                      { label: 'NIC', value: ownerInfo.nic },
                    ].map(({ label, value }) => (
                      <div key={label} style={{ padding: 14, borderRadius: 12, background: 'var(--elevated)', border: '1px solid var(--border)' }}>
                        <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: 6 }}>{label}</div>
                        <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text)', fontFamily: value.startsWith('P-') || value.startsWith('WP') ? 'monospace' : 'inherit' }}>
                          {value || '—'}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </motion.div>
          )}

          {/* ═══════════════ REGISTRY VIEW ═════════════════════════ */}
          {activePage === 'registry' && (
            <motion.div
              key="registry"
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -12 }}
              transition={{ duration: 0.2 }}
              style={{ display: 'flex', flexDirection: 'column', gap: 20 }}
            >
              {/* Header */}
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                  <span className="badge badge-indigo">PERMIT REGISTRY</span>
                </div>
                <h1 style={{ fontSize: 28, fontWeight: 800, color: 'var(--text)', margin: 0 }}>Transport Permit Logs</h1>
                <p style={{ color: 'var(--text-2)', fontSize: 14, marginTop: 6 }}>
                  Complete audit trail of all mineral transport permits issued across registered nodes.
                </p>
              </div>

              {/* Filters */}
              <div className="card" style={{ padding: 18, display: 'flex', gap: 12, flexWrap: 'wrap' }}>
                <div style={{ position: 'relative', flex: 1, minWidth: 200 }}>
                  <Search style={{ width: 14, height: 14, position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-3)' }} />
                  <input
                    className="g-input"
                    style={{ paddingLeft: 32 }}
                    placeholder="Search by permit code, truck, location..."
                    value={registrySearchQuery}
                    onChange={(e) => setRegistrySearchQuery(e.target.value)}
                  />
                </div>
                <select
                  className="g-input"
                  style={{ width: 160, appearance: 'none', cursor: 'pointer' }}
                  value={registryStatusFilter}
                  onChange={(e) => setRegistryStatusFilter(e.target.value)}
                >
                  <option value="all">All Statuses</option>
                  <option value="ACTIVE">Active</option>
                  <option value="COMPLETED">Completed</option>
                  <option value="PENDING">Pending</option>
                  <option value="CANCELLED">Cancelled</option>
                </select>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ fontSize: 12, color: 'var(--text-3)' }}>
                    {filteredRegistryPermits.length} permits
                  </span>
                </div>
              </div>

              {/* Permits Table */}
              <div className="card" style={{ overflow: 'hidden' }}>
                <div style={{ overflowX: 'auto' }}>
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>Permit Code</th>
                        <th>Origin Site</th>
                        <th>Truck</th>
                        <th>Volume</th>
                        <th>Status</th>
                        <th>Date</th>
                        <th>GPS Destination</th>
                      </tr>
                    </thead>
                    <tbody>
                      {loading ? (
                        <tr>
                          <td colSpan={7} style={{ textAlign: 'center', padding: 32, color: 'var(--text-3)' }}>
                            <RotateCw style={{ width: 18, height: 18, display: 'inline-block', animation: 'spin 1s linear infinite' }} />
                          </td>
                        </tr>
                      ) : filteredRegistryPermits.length === 0 ? (
                        <tr>
                          <td colSpan={7} style={{ textAlign: 'center', padding: 32, color: 'var(--text-3)', fontSize: 13 }}>
                            No permits found matching the search criteria.
                          </td>
                        </tr>
                      ) : filteredRegistryPermits.map((permit) => {
                        const isCancelled = permit.status === 'CANCELLED';
                        const isOverload = permit.volumeCubes > 5;
                        const statusColors: Record<string, string> = {
                          ACTIVE: 'badge-indigo',
                          COMPLETED: 'badge-emerald',
                          CANCELLED: 'badge-rose',
                          PENDING: 'badge-amber',
                        };
                        return (
                          <tr key={permit.id}>
                            <td>
                              <div style={{ fontFamily: 'monospace', fontWeight: 700, color: 'var(--text)', fontSize: 12 }}>
                                {permit.permitCode}
                              </div>
                            </td>
                            <td style={{ color: 'var(--text-2)', fontSize: 13 }}>
                              {permit.originLocationName || '—'}
                            </td>
                            <td style={{ fontFamily: 'monospace', color: 'var(--text-2)', fontSize: 12 }}>
                              {permit.truckNumber}
                            </td>
                            <td>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                                <span style={{ color: isOverload ? '#ef4444' : 'var(--text)', fontWeight: isOverload ? 700 : 500, fontSize: 13, fontFamily: 'monospace' }}>
                                  {permit.volumeCubes.toFixed(1)} m³
                                </span>
                                {isOverload && (
                                  <span className="badge badge-rose" style={{ fontSize: 10 }}>OVR</span>
                                )}
                              </div>
                            </td>
                            <td>
                              <span className={`badge ${statusColors[permit.status] || 'badge-zinc'}`}>
                                {permit.status}
                              </span>
                            </td>
                            <td style={{ color: 'var(--text-2)', fontSize: 12 }}>
                              {permit.transportDate.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: '2-digit' })}
                            </td>
                            <td>
                              {permit.unloadLatitude && permit.unloadLongitude ? (
                                <span style={{ color: '#10b981', fontSize: 12, fontFamily: 'monospace', display: 'flex', alignItems: 'center', gap: 4 }}>
                                  <Check style={{ width: 12, height: 12 }} />
                                  {Number(permit.unloadLatitude).toFixed(3)}°N, {Number(permit.unloadLongitude).toFixed(3)}°E
                                </span>
                              ) : isCancelled ? (
                                <span style={{ color: 'var(--text-3)', fontSize: 12 }}>N/A</span>
                              ) : (
                                <span style={{ color: '#ef4444', fontSize: 12, display: 'flex', alignItems: 'center', gap: 4 }}>
                                  <XCircle style={{ width: 12, height: 12 }} />
                                  GPS Missing
                                </span>
                              )}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            </motion.div>
          )}

          {/* ═══════════════ REGISTER VIEW ══════════════════════════ */}
          {activePage === 'register' && (
            <motion.div
              key="register"
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -12 }}
              transition={{ duration: 0.2 }}
              style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 2fr) 320px', gap: 24, alignItems: 'start' }}
            >
              {/* Form */}
              <div className="card" style={{ padding: 32 }}>
                <div style={{ marginBottom: 28 }}>
                  <span className="badge badge-indigo" style={{ marginBottom: 12 }}>REGULATION REGISTRY</span>
                  <h1 style={{ fontSize: 26, fontWeight: 800, color: 'var(--text)', margin: '12px 0 8px' }}>
                    Register New Site
                  </h1>
                  <p style={{ color: 'var(--text-2)', fontSize: 14 }}>
                    Add sand quarries, aggregate mines, or hardware distribution hubs to the GSMB telemetry database.
                  </p>
                </div>

                {regSuccess && (
                  <div style={{
                    padding: '14px 16px', borderRadius: 12, marginBottom: 20,
                    background: 'rgba(16,185,129,0.1)', border: '1px solid rgba(16,185,129,0.2)',
                    display: 'flex', alignItems: 'center', gap: 8,
                  }}>
                    <CheckCircle2 style={{ width: 16, height: 16, color: '#10b981', flexShrink: 0 }} />
                    <div>
                      <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text)' }}>Site registered successfully!</div>
                      <div style={{ fontSize: 12, color: '#10b981', marginTop: 2 }}>
                        Node written to GSMB database and now live on the dashboard.
                      </div>
                    </div>
                  </div>
                )}

                {regError && (
                  <div style={{
                    padding: '14px 16px', borderRadius: 12, marginBottom: 20,
                    background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.2)',
                    display: 'flex', alignItems: 'center', gap: 8,
                  }}>
                    <XCircle style={{ width: 16, height: 16, color: '#ef4444', flexShrink: 0 }} />
                    <div style={{ fontSize: 13, color: '#ef4444' }}>{regError}</div>
                  </div>
                )}

                <form onSubmit={handleRegisterSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                    <div>
                      <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 6 }}>
                        Node / Location ID
                      </label>
                      <input
                        className="g-input"
                        required
                        type="text"
                        placeholder="UUID identifier"
                        value={regId}
                        onChange={(e) => setRegId(e.target.value.toUpperCase())}
                        style={{ fontFamily: 'monospace', fontSize: 12 }}
                      />
                      <div style={{ fontSize: 11, color: 'var(--text-3)', marginTop: 4 }}>Unique UUID for database lookups</div>
                    </div>
                    <div>
                      <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 6 }}>
                        Node Type
                      </label>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                        {(['MINE', 'HARDWARE'] as const).map((t) => (
                          <button
                            key={t}
                            type="button"
                            onClick={() => { setRegType(t); setRegMaxCapacity(t === 'MINE' ? '100' : '20'); }}
                            className={`btn btn-sm ${regType === t ? 'btn-primary' : 'btn-ghost'}`}
                          >
                            {t === 'MINE' ? <HardHat style={{ width: 13, height: 13 }} /> : <Building2 style={{ width: 13, height: 13 }} />}
                            {t === 'MINE' ? 'Mine/Quarry' : 'Hardware'}
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 6 }}>
                      Site Name
                    </label>
                    <input
                      className="g-input"
                      required
                      type="text"
                      placeholder="e.g. Anuradhapura Aggregate Quarry"
                      value={regName}
                      onChange={(e) => setRegName(e.target.value)}
                    />
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                    <div>
                      <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 6 }}>
                        Current Stock (m³)
                      </label>
                      <input
                        className="g-input"
                        required
                        type="number"
                        min="0"
                        value={regInventory}
                        onChange={(e) => setRegInventory(e.target.value)}
                        style={{ fontFamily: 'monospace' }}
                      />
                    </div>
                    <div>
                      <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 6 }}>
                        Max Capacity (m³)
                      </label>
                      <input
                        className="g-input"
                        required
                        type="number"
                        min="1"
                        value={regMaxCapacity}
                        onChange={(e) => setRegMaxCapacity(e.target.value)}
                        style={{ fontFamily: 'monospace' }}
                      />
                      <div style={{ fontSize: 11, color: 'var(--text-3)', marginTop: 4 }}>
                        Default: {regType === 'MINE' ? '100 m³ (mine)' : '20 m³ (hardware)'}
                      </div>
                    </div>
                  </div>

                  {/* Coordinates */}
                  <div style={{ border: '1px solid var(--border)', borderRadius: 12, padding: 16, background: 'var(--elevated)' }}>
                    <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: 12 }}>
                      District Presets & GPS Coordinates
                    </div>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 12 }}>
                      {[
                        { name: 'Colombo', lat: '6.9271', lng: '79.8612' },
                        { name: 'Puttalam', lat: '8.0362', lng: '79.8283' },
                        { name: 'Kurunegala', lat: '7.4863', lng: '80.3647' },
                        { name: 'Kandy', lat: '7.2906', lng: '80.6337' },
                        { name: 'Gampaha', lat: '7.0873', lng: '79.9918' },
                        { name: 'Anuradhapura', lat: '8.3114', lng: '80.4037' },
                      ].map((preset) => (
                        <button
                          key={preset.name}
                          type="button"
                          onClick={() => { setRegLat(preset.lat); setRegLng(preset.lng); }}
                          className={`btn btn-sm ${regLat === preset.lat && regLng === preset.lng ? 'btn-primary' : 'btn-ghost'}`}
                        >
                          {preset.name}
                        </button>
                      ))}
                    </div>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                      <div>
                        <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: 5 }}>Latitude</label>
                        <input className="g-input" required type="text" value={regLat} onChange={(e) => setRegLat(e.target.value)} style={{ fontFamily: 'monospace' }} />
                      </div>
                      <div>
                        <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: 5 }}>Longitude</label>
                        <input className="g-input" required type="text" value={regLng} onChange={(e) => setRegLng(e.target.value)} style={{ fontFamily: 'monospace' }} />
                      </div>
                    </div>
                  </div>

                  {Number(regInventory) > Number(regMaxCapacity) && (
                    <div style={{
                      padding: '12px 16px', borderRadius: 10,
                      background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.2)',
                      display: 'flex', alignItems: 'center', gap: 8, color: '#ef4444', fontSize: 13,
                    }}>
                      <AlertTriangle style={{ width: 15, height: 15, flexShrink: 0 }} />
                      Stock ({regInventory} m³) exceeds capacity ({regMaxCapacity} m³). Site will be flagged as overloaded.
                    </div>
                  )}

                  <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 4 }}>
                    <button type="button" onClick={() => setActivePage('dashboard')} className="btn btn-ghost btn-md">
                      Cancel
                    </button>
                    <button type="submit" disabled={regSubmitting} className="btn btn-primary btn-md">
                      {regSubmitting ? <RotateCw style={{ width: 14, height: 14, animation: 'spin 1s linear infinite' }} /> : <Send style={{ width: 14, height: 14 }} />}
                      {regSubmitting ? 'Registering...' : 'Complete Registration'}
                    </button>
                  </div>
                </form>
              </div>

              {/* Info sidebar */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div className="card" style={{ padding: 20 }}>
                  <div style={{ fontSize: 11, fontWeight: 700, color: '#6366f1', letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 12 }}>
                    Regulatory Compliance
                  </div>
                  <h2 style={{ fontSize: 17, fontWeight: 700, color: 'var(--text)', margin: '0 0 10px' }}>Capacity Standards</h2>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                    <div style={{ padding: 14, borderRadius: 10, background: 'var(--elevated)', border: '1px solid var(--border)' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
                        <HardHat style={{ width: 14, height: 14, color: '#6366f1' }} />
                        <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--text)' }}>Mine / Quarry</span>
                      </div>
                      <p style={{ fontSize: 12, color: 'var(--text-2)', margin: 0, lineHeight: 1.5 }}>
                        Default capacity 100 m³. Mines are flagged when near-empty or overloaded.
                      </p>
                    </div>
                    <div style={{ padding: 14, borderRadius: 10, background: 'var(--elevated)', border: '1px solid var(--border)' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
                        <Building2 style={{ width: 14, height: 14, color: '#10b981' }} />
                        <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--text)' }}>Hardware Store</span>
                      </div>
                      <p style={{ fontSize: 12, color: 'var(--text-2)', margin: 0, lineHeight: 1.5 }}>
                        Strict limit of 20 m³. Exceeding capacity triggers environmental violation flags.
                      </p>
                    </div>
                  </div>
                </div>
                <div className="card" style={{ padding: 20 }}>
                  <h3 style={{ fontSize: 14, fontWeight: 700, color: 'var(--text)', margin: '0 0 8px' }}>Need Inspector Dispatch?</h3>
                  <p style={{ fontSize: 12, color: 'var(--text-2)', margin: '0 0 14px', lineHeight: 1.5 }}>
                    If a node is spoofing GPS data or operating with a revoked license, file an official report immediately.
                  </p>
                  <button onClick={() => setActivePage('contact')} className="btn btn-ghost btn-md" style={{ width: '100%' }}>
                    <Send style={{ width: 13, height: 13 }} />
                    File Regulatory Report
                  </button>
                </div>
              </div>
            </motion.div>
          )}

          {/* ═══════════════ ABOUT VIEW ═════════════════════════════ */}
          {activePage === 'about' && (
            <motion.div
              key="about"
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -12 }}
              transition={{ duration: 0.2 }}
              style={{ display: 'flex', flexDirection: 'column', gap: 20 }}
            >
              <div className="card" style={{ padding: '36px 32px', position: 'relative', overflow: 'hidden' }}>
                <div style={{
                  position: 'absolute', top: -60, right: -60,
                  width: 200, height: 200, borderRadius: '50%',
                  background: 'radial-gradient(circle, rgba(99,102,241,0.08) 0%, transparent 70%)',
                  pointerEvents: 'none',
                }} />
                <span className="badge badge-indigo" style={{ marginBottom: 16 }}>STATUTORY FRAMEWORK</span>
                <h1 style={{ fontSize: 28, fontWeight: 800, color: 'var(--text)', margin: '12px 0 10px' }}>
                  Geological Survey & Mines Bureau (GSMB)
                </h1>
                <p style={{ color: 'var(--text-2)', fontSize: 14, lineHeight: 1.7, maxWidth: 700 }}>
                  Established under the Mines and Minerals Act No. 33 of 1992, the GSMB is the prime authority responsible
                  for regulating mining exploration, license issuance, and safe transit protocols in Sri Lanka.
                </p>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
                {[
                  {
                    icon: HardHat, color: '#6366f1',
                    title: 'License Issuance Guidelines',
                    body: 'The Bureau issues mining licenses for industrial minerals, sand, gravel, and construction aggregates. Each licensed quarry undergoes strict environmental assessment audits.',
                    items: ['Category A: Large industrial mining operations', 'Category B: Semi-mechanized aggregate locations', 'Category C: Artisanal family quarries and sand miners'],
                    itemColor: '#6366f1',
                  },
                  {
                    icon: ShieldCheck, color: '#10b981',
                    title: 'Preventing Transit Exploitation',
                    body: 'Overloading aggregates damages provincial road networks and leads to ecological degradation. GSMB enforces standard cargo weight limitations.',
                    items: ['Max transport volume capped at 5.0 m³', 'Digital permits must detail destination coordinates', 'Repeated violations trigger operational blacklisting'],
                    itemColor: '#ef4444',
                  },
                ].map(({ icon: Ic, color, title, body, items, itemColor }) => (
                  <article key={title} className="card" style={{ padding: 24 }}>
                    <div style={{
                      width: 40, height: 40, borderRadius: 12,
                      background: `${color}18`, border: `1px solid ${color}30`,
                      display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 14,
                    }}>
                      <Ic style={{ width: 18, height: 18, color }} />
                    </div>
                    <h3 style={{ fontSize: 17, fontWeight: 700, color: 'var(--text)', margin: '0 0 8px' }}>{title}</h3>
                    <p style={{ fontSize: 13, color: 'var(--text-2)', margin: '0 0 14px', lineHeight: 1.6 }}>{body}</p>
                    <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 8 }}>
                      {items.map((item) => (
                        <li key={item} style={{ display: 'flex', alignItems: 'flex-start', gap: 8, fontSize: 13, color: 'var(--text-2)' }}>
                          <Check style={{ width: 14, height: 14, color: itemColor, flexShrink: 0, marginTop: 2 }} />
                          {item}
                        </li>
                      ))}
                    </ul>
                  </article>
                ))}
              </div>

              <article className="card" style={{ padding: 24 }}>
                <h3 style={{ fontSize: 17, fontWeight: 700, color: 'var(--text)', margin: '0 0 8px', display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Activity style={{ width: 18, height: 18, color: '#6366f1' }} />
                  GeoTrust Telemetry Implementation
                </h3>
                <p style={{ fontSize: 13, color: 'var(--text-2)', margin: 0, lineHeight: 1.7 }}>
                  This GeoTrust digital dashboard represents a critical national security leap, connecting Sri Lanka's central mineral
                  registry directly with satellite telemetry. Every transit truck is monitored from origin mine check-outs to authorized
                  hardware store destinations. Mismatched unloading zones or cancelled permits automatically trigger inspector dispatches.
                </p>
              </article>
            </motion.div>
          )}

          {/* ═══════════════ CONTACT VIEW ═══════════════════════════ */}
          {activePage === 'contact' && (
            <motion.div
              key="contact"
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -12 }}
              transition={{ duration: 0.2 }}
              style={{ display: 'grid', gridTemplateColumns: '300px minmax(0, 1fr)', gap: 24, alignItems: 'start' }}
            >
              {/* Left: offices */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div className="card" style={{ padding: 20 }}>
                  <span className="badge badge-indigo" style={{ marginBottom: 10 }}>REGIONAL SUPPORT</span>
                  <h2 style={{ fontSize: 18, fontWeight: 700, color: 'var(--text)', margin: '10px 0 6px' }}>Regional Offices</h2>
                  <p style={{ fontSize: 13, color: 'var(--text-2)', margin: 0, lineHeight: 1.5 }}>
                    Contact central headquarters or district offices.
                  </p>
                </div>
                {[
                  { name: 'Central Head Office', addr: 'No. 569, Epitamulla Road, Pitakotte', phone: '+94 11 2886289', email: 'info@gsmb.gov.lk' },
                  { name: 'Kandy District Office', addr: 'No. 12, William Gopallawa Mawatha, Kandy', phone: '+94 81 2235901', email: 'kandy@gsmb.gov.lk' },
                ].map(({ name, addr, phone, email }) => (
                  <div key={name} className="card" style={{ padding: 18 }}>
                    <h3 style={{ fontSize: 14, fontWeight: 700, color: 'var(--text)', margin: '0 0 6px' }}>{name}</h3>
                    <p style={{ fontSize: 12, color: 'var(--text-2)', margin: '0 0 10px' }}>{addr}</p>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                      <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: 'var(--text-2)', fontFamily: 'monospace' }}>
                        <Phone style={{ width: 11, height: 11, color: 'var(--text-3)' }} /> {phone}
                      </span>
                      <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: 'var(--text-2)', fontFamily: 'monospace' }}>
                        <Mail style={{ width: 11, height: 11, color: 'var(--text-3)' }} /> {email}
                      </span>
                    </div>
                  </div>
                ))}
              </div>

              {/* Right: report form */}
              <div className="card" style={{ padding: 28 }}>
                <div style={{ marginBottom: 22 }}>
                  <span className="badge badge-indigo" style={{ marginBottom: 10 }}>COMPLIANCE REPORTING</span>
                  <h2 style={{ fontSize: 22, fontWeight: 800, color: 'var(--text)', margin: '10px 0 6px' }}>Submit Incident Report</h2>
                  <p style={{ fontSize: 13, color: 'var(--text-2)', margin: 0 }}>
                    Submit violations, overloading logs, or registry feedback. Processed by district inspectors.
                  </p>
                </div>

                <form onSubmit={handleFeedbackSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
                    <div>
                      <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 5 }}>Your Name</label>
                      <input className="g-input" required type="text" placeholder="Officer Name" value={fbName} onChange={(e) => setFbName(e.target.value)} />
                    </div>
                    <div>
                      <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 5 }}>Official Email</label>
                      <input className="g-input" required type="email" placeholder="username@gsmb.gov.lk" value={fbEmail} onChange={(e) => setFbEmail(e.target.value)} />
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 5 }}>Incident Topic</label>
                    <select className="g-input" value={fbSubject} onChange={(e) => setFbSubject(e.target.value)} style={{ appearance: 'none', cursor: 'pointer' }}>
                      <option value="Overloading Report">Overloading Volume Violation (&gt; 5 cubes)</option>
                      <option value="Coordinate Mismatch Alert">Unloading Location GPS Mismatch</option>
                      <option value="Illegal Mining Site">Unlicensed Extraction Quarry Identified</option>
                      <option value="General Query">General Administration Query</option>
                    </select>
                  </div>

                  <div>
                    <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 5 }}>Associated Node</label>
                    <select className="g-input" value={fbLocationId} onChange={(e) => setFbLocationId(e.target.value)} style={{ appearance: 'none', cursor: 'pointer' }}>
                      <option value="">-- Auto-assigned if empty --</option>
                      {data.records.map((rec) => (
                        <option key={rec.id} value={rec.id}>[{rec.type.toUpperCase()}] {rec.name} ({rec.region})</option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label style={{ display: 'block', color: 'var(--text-3)', fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', marginBottom: 5 }}>Incident Details</label>
                    <textarea
                      className="g-input"
                      required
                      rows={4}
                      placeholder="Specify licence coordinates, truck plate numbers, and volume load observations..."
                      value={fbMessage}
                      onChange={(e) => setFbMessage(e.target.value)}
                    />
                  </div>

                  {fbSubmitted ? (
                    <div style={{
                      padding: '14px 16px', borderRadius: 10,
                      background: 'rgba(16,185,129,0.1)', border: '1px solid rgba(16,185,129,0.2)',
                      display: 'flex', alignItems: 'center', gap: 8, color: '#10b981', fontSize: 13, fontWeight: 600,
                    }}>
                      <CheckCircle2 style={{ width: 16, height: 16 }} />
                      Report submitted. Registry dispatched to Regional Office.
                    </div>
                  ) : (
                    <button type="submit" className="btn btn-primary btn-lg" style={{ alignSelf: 'flex-start' }}>
                      <Send style={{ width: 14, height: 14 }} />
                      Send Incident Report
                    </button>
                  )}
                </form>

                {/* Active tickets */}
                {supportTickets.length > 0 && (
                  <div style={{ marginTop: 28, paddingTop: 22, borderTop: '1px solid var(--border)' }}>
                    <h3 style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-2)', margin: '0 0 14px', display: 'flex', alignItems: 'center', gap: 6 }}>
                      <MessageSquare style={{ width: 15, height: 15, color: '#6366f1' }} />
                      Active Dispatches
                    </h3>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                      {supportTickets.map((ticket, i) => (
                        <div key={i} style={{
                          padding: '14px 16px', borderRadius: 12,
                          background: 'var(--elevated)', border: '1px solid var(--border)',
                          display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12,
                        }}>
                          <div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                              <span style={{ fontFamily: 'monospace', fontSize: 10, color: 'var(--text-3)', fontWeight: 700 }}>{ticket.id}</span>
                              <span className={`badge ${ticket.status === 'RESOLVED' ? 'badge-emerald' : 'badge-rose'}`} style={{ fontSize: 9 }}>
                                {ticket.status}
                              </span>
                            </div>
                            <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text)', marginBottom: 3 }}>{ticket.subject}</div>
                            <div style={{ fontSize: 12, color: 'var(--text-2)' }}>{ticket.message}</div>
                          </div>
                          <span style={{ fontSize: 11, color: 'var(--text-3)', fontFamily: 'monospace', flexShrink: 0 }}>{ticket.date}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </motion.div>
          )}

        </AnimatePresence>
      </main>

      {/* ── FOOTER ───────────────────────────────────────────────── */}
      <footer style={{
        borderTop: '1px solid var(--border)',
        padding: '20px',
        marginTop: 'auto',
      }}>
        <div style={{
          maxWidth: 1400, margin: '0 auto',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12,
        }}>
          <p style={{ fontSize: 12, color: 'var(--text-3)', margin: 0 }}>
            © 2026 Geological Survey & Mines Bureau (GSMB), Sri Lanka. All Rights Reserved.
          </p>
          <span style={{
            fontSize: 10, fontFamily: 'monospace', fontWeight: 700,
            padding: '4px 10px', borderRadius: 99,
            background: 'var(--elevated)', border: '1px solid var(--border)',
            color: 'var(--text-3)', letterSpacing: '0.08em', textTransform: 'uppercase',
          }}>
            OVERSIGHT VERSION 2.0.4-STABLE
          </span>
        </div>
      </footer>

      <style>{`
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        @media (max-width: 1024px) {
          .map-charts-row { grid-template-columns: 1fr !important; }
        }
        @media (max-width: 768px) {
          .register-grid { grid-template-columns: 1fr !important; }
          .contact-grid { grid-template-columns: 1fr !important; }
        }
      `}</style>
    </div>
  );
}
"""

new_file = logic_section + render_section

with open('/home/dineth_thenuwara/gsmb-admin-dashboard_Temp/src/App.tsx', 'w') as f:
    f.write(new_file)

print(f"Written App.tsx: {len(new_file)} chars, {new_file.count(chr(10))} lines")
