const SUPABASE_URL = 'https://jtumrmelwetgzyiprfol.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0dW1ybWVsd2V0Z3p5aXByZm9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MzY5ODksImV4cCI6MjA4OTMxMjk4OX0.8o99Izp2nVmpSUNn01CeHu0MSIesX6ocvK9sOwDZ0E4';

const FALLBACK_CENTER = [7.8731, 80.7718];

const fallbackData = {
  generatedAt: new Date(),
  metrics: [
    { label: 'Tracked locations', value: 0, note: 'No live data yet' },
    { label: 'Open overloads', value: 0, note: 'No live incidents' },
    { label: 'Fraud flags', value: 0, note: 'No live incidents' },
    { label: 'Active permits', value: 0, note: 'No active permits' },
  ],
  records: [],
  incidentSeries: {
    labels: [],
    overloads: [],
    frauds: [],
  },
  statusCounts: {
    Pending: 0,
    Active: 0,
    Completed: 0,
    Cancelled: 0,
  },
};

function cloneFallbackData() {
  return JSON.parse(JSON.stringify(fallbackData));
}

let dashboardData = cloneFallbackData();

const els = {
  metricGrid: document.getElementById('metricGrid'),
  searchInput: document.getElementById('searchInput'),
  regionSelect: document.getElementById('regionSelect'),
  riskSelect: document.getElementById('riskSelect'),
  locationTable: document.getElementById('locationTable'),
  detailPanel: document.getElementById('detailPanel'),
  refreshBtn: document.getElementById('refreshBtn'),
  exportBtn: document.getElementById('exportBtn'),
  dataStatus: document.getElementById('dataStatus'),
};

let map;
let mapMarkers = [];
let incidentChart;
let statusChart;
let activeRecordId = null;

function setStatus(message, isError = false) {
  els.dataStatus.textContent = message;
  els.dataStatus.classList.toggle('error', isError);
}

function formatNumber(value) {
  return Number.isInteger(value) ? `${value}` : value.toFixed(1);
}

function getRiskLabel(risk) {
  return risk.charAt(0).toUpperCase() + risk.slice(1);
}

function getRegionFromLocation(location) {
  const profileParts = [location.name, location.address, location.district]
    .filter(Boolean)
    .join(' | ');
  return profileParts ? profileParts : 'Unknown';
}

function clampRisk(score) {
  if (score >= 4) return 'high';
  if (score >= 2) return 'medium';
  return 'low';
}

function buildMonthlyIncidentSeries(permits) {
  const now = new Date();
  const labels = [];
  const overloads = [];
  const frauds = [];

  for (let i = 5; i >= 0; i -= 1) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const label = d.toLocaleDateString('en-US', { month: 'short' });
    labels.push(label);

    const monthPermits = permits.filter((permit) => {
      const td = permit.transportDate;
      return td.getFullYear() === d.getFullYear() && td.getMonth() === d.getMonth();
    });

    const overloadCount = monthPermits.filter((permit) => Number(permit.volumeCubes) > 5).length;
    const fraudCount = monthPermits.filter(
      (permit) =>
        (permit.status === 'CANCELLED' && permit.unloadedAt) ||
        (permit.unloadLatitude == null && permit.status === 'COMPLETED') ||
        permit.gpsMismatch,
    ).length;

    overloads.push(overloadCount);
    frauds.push(fraudCount);
  }

  return { labels, overloads, frauds };
}

function toPermit(raw) {
  return {
    id: raw.id,
    permitCode: raw.permit_code,
    truckNumber: raw.truck_number ?? 'Unknown',
    volumeCubes: Number(raw.volume_cubes ?? 0),
    transportDate: new Date(raw.transport_date),
    expirationDate: raw.expiration_date ? new Date(raw.expiration_date) : null,
    status: String(raw.status ?? 'PENDING').toUpperCase(),
    originLocationId: raw.origin_location_id,
    unloadLatitude: raw.unload_latitude,
    unloadLongitude: raw.unload_longitude,
    unloadedAt: raw.unloaded_at,
    gpsMismatch: false,
  };
}

async function fetchSupabase(path) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(`Supabase request failed (${response.status})`);
  }

  return response.json();
}

function buildDashboardData(locations, permits) {
  const permitsByLocation = new Map();

  permits.forEach((permit) => {
    if (!permit.originLocationId) return;
    if (!permitsByLocation.has(permit.originLocationId)) {
      permitsByLocation.set(permit.originLocationId, []);
    }
    permitsByLocation.get(permit.originLocationId).push(permit);
  });

  const records = locations.map((location) => {
    const locationPermits = permitsByLocation.get(location.id) || [];

    const overloadIncidents = locationPermits.filter((permit) => permit.volumeCubes > 5).length;
    const fraudIncidents = locationPermits.filter(
      (permit) =>
        permit.status === 'CANCELLED' ||
        (permit.status === 'COMPLETED' && (permit.unloadLatitude == null || permit.unloadLongitude == null)),
    ).length;
    const totalIncidents = overloadIncidents + fraudIncidents;

    const riskScore = (totalIncidents >= 3 ? 2 : totalIncidents >= 1 ? 1 : 0) +
      (Number(location.inventory_cubes ?? 0) <= 5 ? 2 : Number(location.inventory_cubes ?? 0) <= 12 ? 1 : 0);

    const risk = clampRisk(riskScore);
    const latestPermit = locationPermits
      .slice()
      .sort((a, b) => b.transportDate.getTime() - a.transportDate.getTime())[0];

    const timeline = [
      { label: 'Overload incidents', value: `${overloadIncidents}` },
      { label: 'Fraud indicators', value: `${fraudIncidents}` },
      { label: 'Latest permit', value: latestPermit ? latestPermit.id.slice(0, 8).toUpperCase() : 'None' },
    ];

    return {
      id: location.id,
      name: location.name ?? 'Unnamed Location',
      type:
        location.location_type === 'MINE' || location.location_type === 'MINE_OWNER'
          ? 'Mine'
          : 'Hardware',
      region: getRegionFromLocation(location),
      inventory: Number(location.inventory_cubes ?? 0),
      incidents: totalIncidents,
      risk,
      status:
        totalIncidents > 0
          ? `${overloadIncidents} overload(s), ${fraudIncidents} fraud flag(s)`
          : 'No active incident patterns',
      coordinates: [
        Number(location.latitude ?? FALLBACK_CENTER[0]),
        Number(location.longitude ?? FALLBACK_CENTER[1]),
      ],
      permit: latestPermit?.id?.slice(0, 8)?.toUpperCase() ?? 'N/A',
      truck: latestPermit?.truckNumber ?? 'N/A',
      timeline,
    };
  });

  const activePermits = permits.filter((permit) => permit.status === 'ACTIVE').length;
  const openOverloads = permits.filter((permit) => permit.status !== 'COMPLETED' && permit.volumeCubes > 5).length;
  const fraudFlags = permits.filter(
    (permit) =>
      permit.status === 'CANCELLED' ||
      (permit.status === 'COMPLETED' && (permit.unloadLatitude == null || permit.unloadLongitude == null)),
  ).length;

  const metrics = [
    {
      label: 'Tracked locations',
      value: records.length,
      note: `Live from Supabase (${new Date().toLocaleTimeString()})`,
    },
    {
      label: 'Open overloads',
      value: openOverloads,
      note: 'Permits > 5 cubes not yet completed',
    },
    {
      label: 'Fraud flags',
      value: fraudFlags,
      note: 'Cancelled or suspicious completion logs',
    },
    {
      label: 'Active permits',
      value: activePermits,
      note: `${permits.length} total permits`,
    },
  ];

  const statusCounts = {
    Pending: permits.filter((permit) => permit.status === 'PENDING').length,
    Active: permits.filter((permit) => permit.status === 'ACTIVE').length,
    Completed: permits.filter((permit) => permit.status === 'COMPLETED').length,
    Cancelled: permits.filter((permit) => permit.status === 'CANCELLED').length,
  };

  const incidentSeries = buildMonthlyIncidentSeries(permits);

  return {
    generatedAt: new Date(),
    metrics,
    records,
    incidentSeries,
    statusCounts,
  };
}

async function loadLiveData() {
  setStatus('Loading live data...');

  try {
    const [rawLocations, rawPermits] = await Promise.all([
      fetchSupabase('locations?select=id,name,location_type,inventory_cubes,latitude,longitude'),
      fetchSupabase(
        'permits?select=id,permit_code,truck_number,volume_cubes,transport_date,expiration_date,status,origin_location_id,unload_latitude,unload_longitude,unloaded_at',
      ),
    ]);

    const permits = rawPermits.map(toPermit);
    dashboardData = buildDashboardData(rawLocations, permits);

    if (!activeRecordId && dashboardData.records.length > 0) {
      activeRecordId = dashboardData.records[0].id;
    }

    setStatus(`Live data connected (${dashboardData.records.length} locations)`);
  } catch (error) {
    console.error(error);
    dashboardData = cloneFallbackData();
    activeRecordId = null;
    setStatus('Live data unavailable. Showing empty fallback.', true);
  }

  renderRegionOptions();
  renderAll();
}

function getFilteredRecords() {
  const query = els.searchInput.value.trim().toLowerCase();
  const region = els.regionSelect.value;
  const risk = els.riskSelect.value;

  return dashboardData.records.filter((record) => {
    const matchesQuery =
      !query ||
      [record.id, record.name, record.type, record.region, record.status, record.truck, record.permit]
        .join(' ')
        .toLowerCase()
        .includes(query);

    const matchesRegion = region === 'all' || record.region === region;

    const rank = { low: 1, medium: 2, high: 3 }[record.risk];
    const riskRank = { low: 1, medium: 2, high: 3 }[risk] ?? 0;
    const matchesRisk = risk === 'all' || rank >= riskRank;

    return matchesQuery && matchesRegion && matchesRisk;
  });
}

function renderMetrics() {
  els.metricGrid.innerHTML = dashboardData.metrics
    .map(
      (metric) => `
        <article class="metric-card">
          <div class="metric-label">${metric.label}</div>
          <div class="metric-value">${metric.value}</div>
          <div class="metric-note">${metric.note}</div>
        </article>
      `,
    )
    .join('');
}

function renderRegionOptions() {
  const regions = ['all', ...new Set(dashboardData.records.map((record) => record.region))];
  els.regionSelect.innerHTML = regions
    .map((region) => `<option value="${region}">${region === 'all' ? 'All regions' : region}</option>`)
    .join('');
}

function renderTable(records) {
  if (records.length === 0) {
    els.locationTable.innerHTML = `
      <tr>
        <td colspan="6">No records match the selected filters.</td>
      </tr>
    `;
    return;
  }

  els.locationTable.innerHTML = records
    .map(
      (record) => `
        <tr data-id="${record.id}" class="${record.id === activeRecordId ? 'active' : ''}">
          <td><strong>${record.name}</strong><br /><span class="muted">${record.id}</span></td>
          <td>${record.type}</td>
          <td>${record.region}</td>
          <td>${formatNumber(record.inventory)} cubes</td>
          <td>${record.incidents}</td>
          <td><span class="badge ${record.risk}">${getRiskLabel(record.risk)}</span></td>
        </tr>
      `,
    )
    .join('');

  els.locationTable.querySelectorAll('tr[data-id]').forEach((row) => {
    row.addEventListener('click', () => {
      activeRecordId = row.dataset.id;
      renderAll();
    });
  });
}

function renderDetail(record) {
  if (!record) {
    els.detailPanel.innerHTML = '<p class="muted">No location selected.</p>';
    return;
  }

  els.detailPanel.innerHTML = `
    <div class="detail-hero">
      <p class="card-kicker">${record.type} / ${record.region}</p>
      <h3>${record.name}</h3>
      <p>${record.status}</p>
      <div class="badge ${record.risk}">${getRiskLabel(record.risk)} risk</div>
    </div>
    <div class="detail-meta">
      <div class="stat-box"><span>Inventory</span><strong>${formatNumber(record.inventory)} cubes</strong></div>
      <div class="stat-box"><span>Open incidents</span><strong>${record.incidents}</strong></div>
      <div class="stat-box"><span>Permit</span><strong>${record.permit}</strong></div>
      <div class="stat-box"><span>Truck</span><strong>${record.truck}</strong></div>
    </div>
    <div>
      <p class="card-kicker">Recent activity</p>
      <div class="timeline">
        ${record.timeline
          .map(
            (item) => `
              <div class="timeline-item">
                <div><strong>${item.label}</strong></div>
                <div>${item.value}</div>
              </div>
            `,
          )
          .join('')}
      </div>
    </div>
  `;
}

function clearMarkers() {
  mapMarkers.forEach((marker) => marker.remove());
  mapMarkers = [];
}

function renderMap(records) {
  clearMarkers();

  if (!map) {
    map = L.map('map', { scrollWheelZoom: false }).setView(FALLBACK_CENTER, 7.2);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map);
  }

  const bounds = [];

  records.forEach((record) => {
    const markerColor =
      record.risk === 'high' ? '#fb7185' : record.risk === 'medium' ? '#fbbf24' : '#34d399';
    const icon = L.divIcon({
      className: 'custom-marker',
      html: `<div style="width:16px;height:16px;border-radius:999px;background:${markerColor};border:3px solid #fff;box-shadow:0 0 0 8px rgba(255,255,255,0.1)"></div>`,
      iconSize: [16, 16],
      iconAnchor: [8, 8],
    });

    const marker = L.marker(record.coordinates, { icon }).addTo(map);
    marker.bindPopup(`
      <strong>${record.name}</strong><br />
      ${record.type} · ${record.region}<br />
      Risk: ${getRiskLabel(record.risk)}<br />
      Incidents: ${record.incidents}
    `);
    marker.on('click', () => {
      activeRecordId = record.id;
      renderAll();
    });

    mapMarkers.push(marker);
    bounds.push(record.coordinates);
  });

  if (bounds.length > 0) {
    map.fitBounds(bounds, { padding: [40, 40] });
  } else {
    map.setView(FALLBACK_CENTER, 7.2);
  }
}

function renderCharts() {
  const labels = dashboardData.incidentSeries.labels;
  const overloads = dashboardData.incidentSeries.overloads;
  const frauds = dashboardData.incidentSeries.frauds;

  if (incidentChart) incidentChart.destroy();
  if (statusChart) statusChart.destroy();

  incidentChart = new Chart(document.getElementById('incidentChart'), {
    type: 'line',
    data: {
      labels,
      datasets: [
        {
          label: 'Overloads',
          data: overloads,
          borderColor: '#fb7185',
          backgroundColor: 'rgba(251, 113, 133, 0.15)',
          tension: 0.35,
          fill: true,
        },
        {
          label: 'Fraud flags',
          data: frauds,
          borderColor: '#34d399',
          backgroundColor: 'rgba(52, 211, 153, 0.15)',
          tension: 0.35,
          fill: true,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { labels: { color: '#dbeafe' } } },
      scales: {
        x: { ticks: { color: '#9fb2cb' }, grid: { color: 'rgba(148, 163, 184, 0.1)' } },
        y: {
          ticks: { color: '#9fb2cb', precision: 0 },
          grid: { color: 'rgba(148, 163, 184, 0.1)' },
          beginAtZero: true,
        },
      },
    },
  });

  statusChart = new Chart(document.getElementById('statusChart'), {
    type: 'doughnut',
    data: {
      labels: Object.keys(dashboardData.statusCounts),
      datasets: [
        {
          data: Object.values(dashboardData.statusCounts),
          backgroundColor: ['#f59e0b', '#22c55e', '#64748b', '#ef4444'],
          borderWidth: 0,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { position: 'bottom', labels: { color: '#dbeafe' } } },
    },
  });
}

function exportReport(records) {
  const payload = {
    generatedAt: dashboardData.generatedAt.toISOString(),
    summary: dashboardData.metrics,
    records,
  };

  const blob = new Blob([JSON.stringify(payload, null, 2)], {
    type: 'application/json',
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = 'gsmb-dashboard-report.json';
  link.click();
  URL.revokeObjectURL(url);
}

function renderAll() {
  const records = getFilteredRecords();
  const activeRecord =
    records.find((record) => record.id === activeRecordId) || records[0] || null;

  renderMetrics();
  renderTable(records);
  renderMap(records);
  renderCharts();
  renderDetail(activeRecord);
}

function wireEvents() {
  [els.searchInput, els.regionSelect, els.riskSelect].forEach((element) => {
    element.addEventListener('input', renderAll);
    element.addEventListener('change', renderAll);
  });

  els.refreshBtn.addEventListener('click', async () => {
    await loadLiveData();
  });

  els.exportBtn.addEventListener('click', () => exportReport(getFilteredRecords()));
}

function initializeDashboard() {
  try {
    wireEvents();
    loadLiveData();
  } catch (error) {
    console.error(error);
    setStatus('Dashboard initialization failed.', true);
  }
}

initializeDashboard();
