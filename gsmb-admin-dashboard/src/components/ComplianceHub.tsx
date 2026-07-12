import React, { useState, useEffect, useRef, useMemo } from 'react';
import {
  ShieldAlert,
  AlertTriangle,
  TrendingUp,
  Truck,
  MapPin,
  BarChart3,
  Activity,
  Clock,
  Calendar,
  ChevronRight,
  Circle,
  WifiOff,
  Layers,
} from 'lucide-react';
import { ProcessedPermit, ProcessedLocationRecord } from '../types';

interface ComplianceHubProps {
  permits: ProcessedPermit[];
  records: ProcessedLocationRecord[];
  theme: 'dark' | 'light';
}

function TransitMap({
  permit,
  originRecord,
  theme,
}: {
  permit: ProcessedPermit | null;
  originRecord: ProcessedLocationRecord | null;
  theme: 'dark' | 'light';
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<any>(null);

  useEffect(() => {
    const L = (window as any).L;
    if (!L || !containerRef.current || !permit || !originRecord) return;

    if (mapRef.current) {
      try { mapRef.current.remove(); } catch (_) {}
      mapRef.current = null;
    }

    const tileUrl =
      theme === 'light'
        ? 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

    const originLat = originRecord.coordinates[0];
    const originLng = originRecord.coordinates[1];
    const hasUnload = permit.unloadLatitude !== null && permit.unloadLongitude !== null;
    const destLat = hasUnload ? permit.unloadLatitude! : originLat + 0.12;
    const destLng = hasUnload ? permit.unloadLongitude! : originLng + 0.08;
    const centerLat = (originLat + destLat) / 2;
    const centerLng = (originLng + destLng) / 2;

    const map = L.map(containerRef.current, {
      scrollWheelZoom: false,
      zoomControl: false,
      dragging: true,
      tap: true,
    }).setView([centerLat, centerLng], 11);
    mapRef.current = map;

    L.tileLayer(tileUrl, { maxZoom: 19, attribution: '&copy; CARTO' }).addTo(map);

    const originIcon = L.divIcon({
      className: '',
      html: `<div style="width:14px;height:14px;background:#6366f1;border-radius:50%;border:2px solid white;box-shadow:0 2px 8px rgba(99,102,241,0.6);"></div>`,
      iconSize: [14, 14],
      iconAnchor: [7, 7],
    });

    const isViolation = !hasUnload || permit.volumeCubes > 5;
    const destColor = isViolation ? '#f43f5e' : '#10b981';
    const destIcon = L.divIcon({
      className: '',
      html: `<div style="width:14px;height:14px;background:${destColor};border-radius:50%;border:2px solid white;box-shadow:0 2px 8px rgba(244,63,94,0.6);"></div>`,
      iconSize: [14, 14],
      iconAnchor: [7, 7],
    });

    L.marker([originLat, originLng], { icon: originIcon })
      .addTo(map)
      .bindPopup(`<strong>Origin</strong><br/>${originRecord.name}`);
    L.marker([destLat, destLng], { icon: destIcon })
      .addTo(map)
      .bindPopup(`<strong>${hasUnload ? 'Unload Point' : 'Unknown Destination'}</strong><br/>${permit.permitCode}`);

    const lineColor = isViolation ? '#f43f5e' : '#10b981';
    L.polyline([[originLat, originLng], [destLat, destLng]], {
      color: lineColor,
      weight: 3,
      opacity: 0.75,
      dashArray: hasUnload ? undefined : '8, 8',
    }).addTo(map);

    map.fitBounds([[originLat, originLng], [destLat, destLng]], { padding: [40, 40] });

    return () => {
      if (mapRef.current) {
        try { mapRef.current.remove(); } catch (_) {}
        mapRef.current = null;
      }
    };
  }, [permit, originRecord, theme]);

  if (!permit || !originRecord) {
    return (
      <div className="w-full h-full flex flex-col items-center justify-center gap-3 opacity-50">
        <MapPin className="w-8 h-8" />
        <p className="text-sm font-semibold">Select a transit record to view route</p>
      </div>
    );
  }

  return <div ref={containerRef} className="w-full h-full rounded-xl overflow-hidden" />;
}

function InlineBarChart({
  data,
  theme,
}: {
  data: { label: string; overload: number; fraud: number; gps: number }[];
  theme: 'dark' | 'light';
}) {
  const maxVal = Math.max(...data.map((d) => d.overload + d.fraud + d.gps), 1);
  const textMuted = theme === 'dark' ? 'text-neutral-400' : 'text-neutral-500';

  return (
    <div className="flex items-end gap-2 h-28 w-full">
      {data.map((d, i) => {
        const total = d.overload + d.fraud + d.gps;
        const totalPct = (total / maxVal) * 100;
        const overloadPct = total > 0 ? (d.overload / total) * 100 : 0;
        const fraudPct = total > 0 ? (d.fraud / total) * 100 : 0;
        const gpsPct = total > 0 ? (d.gps / total) * 100 : 0;
        return (
          <div key={i} className="flex-1 flex flex-col items-center gap-1">
            <div className="w-full flex flex-col justify-end" style={{ height: '88px' }}>
              <div
                className="w-full rounded-t-sm overflow-hidden flex flex-col-reverse"
                style={{ height: `${Math.max(totalPct, 2)}%`, minHeight: total > 0 ? '6px' : '2px' }}
              >
                <div style={{ flex: `${overloadPct} 0 0`, background: '#6366f1', minHeight: d.overload > 0 ? '4px' : '0' }} />
                <div style={{ flex: `${fraudPct} 0 0`, background: '#f43f5e', minHeight: d.fraud > 0 ? '4px' : '0' }} />
                <div style={{ flex: `${gpsPct} 0 0`, background: '#fbbf24', minHeight: d.gps > 0 ? '4px' : '0' }} />
              </div>
            </div>
            <span className={`text-[9px] font-bold text-center leading-tight ${textMuted}`}>{d.label}</span>
          </div>
        );
      })}
    </div>
  );
}

export default function ComplianceHub({ permits, records, theme }: ComplianceHubProps) {
  const [selectedPermitId, setSelectedPermitId] = useState<string | null>(null);
  const [riskFilter, setRiskFilter] = useState<'all' | 'overload' | 'fraud' | 'gps'>('all');
  const [transitSearch, setTransitSearch] = useState('');

  const overloadPermits = useMemo(() => permits.filter((p) => p.volumeCubes > 5), [permits]);
  const fraudPermits = useMemo(
    () => permits.filter((p) => p.status === 'CANCELLED' || (p.status === 'COMPLETED' && p.unloadLatitude === null)),
    [permits]
  );
  const gpsLostPermits = useMemo(
    () => permits.filter((p) => p.unloadLatitude === null && p.status !== 'CANCELLED' && p.status !== 'PENDING'),
    [permits]
  );

  const riskLedger = useMemo(() => [...records].sort((a, b) => b.incidents - a.incidents).slice(0, 12), [records]);

  const monthlyData = useMemo(() => {
    const now = new Date();
    return Array.from({ length: 6 }, (_, i) => {
      const d = new Date(now.getFullYear(), now.getMonth() - (5 - i), 1);
      const label = d.toLocaleDateString('en-US', { month: 'short' });
      const monthPermits = permits.filter((p) => {
        const pd = p.transportDate;
        return pd.getFullYear() === d.getFullYear() && pd.getMonth() === d.getMonth();
      });
      return {
        label,
        overload: monthPermits.filter((p) => p.volumeCubes > 5).length,
        fraud: monthPermits.filter((p) => p.status === 'CANCELLED' || (p.status === 'COMPLETED' && p.unloadLatitude === null)).length,
        gps: monthPermits.filter((p) => p.unloadLatitude === null && p.status !== 'CANCELLED').length,
      };
    });
  }, [permits]);

  const filteredTransit = useMemo(() => {
    let list =
      riskFilter === 'overload'
        ? overloadPermits
        : riskFilter === 'fraud'
        ? fraudPermits
        : riskFilter === 'gps'
        ? gpsLostPermits
        : [...overloadPermits, ...fraudPermits].filter((p, i, arr) => arr.findIndex((x) => x.id === p.id) === i);

    if (transitSearch.trim()) {
      const q = transitSearch.toLowerCase();
      list = list.filter(
        (p) =>
          p.permitCode.toLowerCase().includes(q) ||
          p.truckNumber.toLowerCase().includes(q) ||
          (p.originLocationName || '').toLowerCase().includes(q)
      );
    }
    return list.slice(0, 40);
  }, [riskFilter, overloadPermits, fraudPermits, gpsLostPermits, transitSearch]);

  const selectedPermit = useMemo(
    () => filteredTransit.find((p) => p.id === selectedPermitId) || filteredTransit[0] || null,
    [filteredTransit, selectedPermitId]
  );

  const selectedOriginRecord = useMemo(() => {
    if (!selectedPermit?.originLocationId) return null;
    return records.find((r) => r.id === selectedPermit.originLocationId) || null;
  }, [selectedPermit, records]);

  useEffect(() => {
    if (filteredTransit.length > 0 && !filteredTransit.find((p) => p.id === selectedPermitId)) {
      setSelectedPermitId(filteredTransit[0].id);
    }
  }, [filteredTransit, selectedPermitId]);

  const timelineEvents = useMemo(() => {
    if (!selectedPermit) return [];
    const events: { type: 'info' | 'warning' | 'danger'; icon: React.ReactNode; label: string; time: string }[] = [];

    events.push({
      type: 'info',
      icon: <Calendar className="w-3.5 h-3.5" />,
      label: `Permit issued — ${selectedPermit.permitCode}`,
      time: selectedPermit.transportDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
    });

    if (selectedPermit.volumeCubes > 5) {
      events.push({
        type: 'danger',
        icon: <AlertTriangle className="w-3.5 h-3.5" />,
        label: `OVERLOAD VIOLATION — ${selectedPermit.volumeCubes.toFixed(1)} m³ declared (limit: 5 m³)`,
        time: selectedPermit.transportDate.toLocaleDateString(),
      });
    }

    if (selectedPermit.unloadLatitude === null && selectedPermit.status !== 'PENDING' && selectedPermit.status !== 'ACTIVE') {
      events.push({
        type: 'warning',
        icon: <WifiOff className="w-3.5 h-3.5" />,
        label: 'GPS signal missing — no unload coordinates logged',
        time: 'During transit',
      });
    }

    if (selectedPermit.status === 'CANCELLED') {
      events.push({
        type: 'danger',
        icon: <ShieldAlert className="w-3.5 h-3.5" />,
        label: 'Permit CANCELLED — flagged for non-compliance review',
        time: selectedPermit.expirationDate?.toLocaleDateString() || 'Unknown',
      });
    }

    if (selectedPermit.unloadLatitude !== null) {
      events.push({
        type: 'info',
        icon: <MapPin className="w-3.5 h-3.5" />,
        label: `Unloaded at ${selectedPermit.unloadLatitude.toFixed(4)}, ${selectedPermit.unloadLongitude?.toFixed(4)}`,
        time: selectedPermit.unloadedAt ? new Date(selectedPermit.unloadedAt).toLocaleString() : 'Date unknown',
      });
    }

    if (selectedPermit.status === 'COMPLETED' && selectedPermit.unloadLatitude !== null) {
      events.push({
        type: 'info',
        icon: <Circle className="w-3.5 h-3.5" />,
        label: 'Permit completed — delivery confirmed',
        time: selectedPermit.expirationDate?.toLocaleDateString() || 'Unknown',
      });
    }

    return events;
  }, [selectedPermit]);

  const isDark = theme === 'dark';
  const cardCls = isDark ? 'bg-neutral-900 border-neutral-800' : 'bg-white border-neutral-200';
  const subtleCls = isDark ? 'bg-neutral-950 border-neutral-800' : 'bg-neutral-50 border-neutral-200';
  const textPrimary = isDark ? 'text-white' : 'text-neutral-900';
  const textMuted = isDark ? 'text-neutral-400' : 'text-neutral-500';

  return (
    <div className="w-full space-y-6 pb-10">
      {/* Header */}
      <div className="flex items-center gap-4">
        <div>
          <h1 className={`text-2xl font-black tracking-tight ${textPrimary}`}>
            Compliance &amp; Fraud Analytics
          </h1>
          <p className={`text-sm font-medium mt-1 ${textMuted}`}>
            Live violation detection, anomalous corridor risk ledger, and transit route playback
          </p>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-5">
        {[
          { label: 'Overload Violations', value: overloadPermits.length, sub: '> 5 m³ declared loads', icon: <Truck className="w-5 h-5" />, color: 'indigo' },
          { label: 'GPS Signal Lost', value: gpsLostPermits.length, sub: 'No unload coordinates', icon: <WifiOff className="w-5 h-5" />, color: 'amber' },
          { label: 'Cancelled Permits', value: permits.filter((p) => p.status === 'CANCELLED').length, sub: 'Flagged non-compliance', icon: <ShieldAlert className="w-5 h-5" />, color: 'rose' },
          { label: 'High-Risk Locations', value: records.filter((r) => r.risk === 'high').length, sub: 'Mines or hardware stores', icon: <AlertTriangle className="w-5 h-5" />, color: 'orange' },
        ].map((card, i) => (
          <div key={i} className={`rounded-2xl border p-5 ${cardCls}`}>
            <div className={`w-10 h-10 rounded-xl flex items-center justify-center mb-4 ${
              card.color === 'indigo' ? isDark ? 'bg-indigo-500/15 text-indigo-400' : 'bg-indigo-100 text-indigo-600'
              : card.color === 'amber' ? isDark ? 'bg-amber-500/15 text-amber-400' : 'bg-amber-100 text-amber-600'
              : card.color === 'rose' ? isDark ? 'bg-rose-500/15 text-rose-400' : 'bg-rose-100 text-rose-600'
              : isDark ? 'bg-orange-500/15 text-orange-400' : 'bg-orange-100 text-orange-600'
            }`}>
              {card.icon}
            </div>
            <div className={`text-3xl font-black mb-1 ${textPrimary}`}>{card.value}</div>
            <div className={`text-sm font-bold ${textPrimary}`}>{card.label}</div>
            <div className={`text-xs font-medium mt-1 ${textMuted}`}>{card.sub}</div>
          </div>
        ))}
      </div>

      {/* Chart + Risk Ledger Row */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-5">
        <div className={`rounded-2xl border p-6 ${cardCls}`}>
          <div className="flex items-center justify-between mb-5">
            <div>
              <h2 className={`text-sm font-black tracking-wider uppercase ${textPrimary}`}>Violation Trend (6 Months)</h2>
              <p className={`text-xs font-medium mt-1 ${textMuted}`}>Monthly count of anomalous transport events</p>
            </div>
            <BarChart3 className={`w-5 h-5 ${textMuted}`} />
          </div>
          <InlineBarChart data={monthlyData} theme={theme} />
          <div className="flex items-center gap-5 mt-4">
            {[{ label: 'Overload', color: '#6366f1' }, { label: 'Fraud / Cancelled', color: '#f43f5e' }, { label: 'GPS Lost', color: '#fbbf24' }].map((l) => (
              <div key={l.label} className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full" style={{ background: l.color }} />
                <span className={`text-xs font-semibold ${textMuted}`}>{l.label}</span>
              </div>
            ))}
          </div>
        </div>

        <div className={`rounded-2xl border p-6 ${cardCls}`}>
          <div className="flex items-center justify-between mb-5">
            <div>
              <h2 className={`text-sm font-black tracking-wider uppercase ${textPrimary}`}>Anomalous Site Risk Ledger</h2>
              <p className={`text-xs font-medium mt-1 ${textMuted}`}>Ranked by cumulative violation incidents</p>
            </div>
            <TrendingUp className={`w-5 h-5 ${textMuted}`} />
          </div>
          <div className="space-y-2 max-h-[220px] overflow-y-auto pr-1">
            {riskLedger.length === 0 ? (
              <p className={`text-sm text-center py-4 ${textMuted}`}>No sites with incidents found.</p>
            ) : (
              riskLedger.map((record, i) => (
                <div key={record.id} className={`flex items-center gap-3 rounded-xl px-4 py-3 border ${subtleCls}`}>
                  <span className={`text-xs font-black w-6 text-center ${textMuted}`}>#{i + 1}</span>
                  <div className={`w-2.5 h-2.5 rounded-full flex-shrink-0 ${record.risk === 'high' ? 'bg-rose-500' : record.risk === 'medium' ? 'bg-amber-500' : 'bg-emerald-500'}`} />
                  <div className="flex-1 min-w-0">
                    <p className={`text-sm font-bold truncate ${textPrimary}`}>{record.name}</p>
                    <p className={`text-xs font-medium ${textMuted}`}>{record.type} · {record.region}</p>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <span className={`text-sm font-black ${record.risk === 'high' ? 'text-rose-500' : record.risk === 'medium' ? 'text-amber-500' : textMuted}`}>{record.incidents}</span>
                    <p className={`text-xs ${textMuted}`}>incidents</p>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Transit Timeline & Route Playback */}
      <div className={`rounded-2xl border p-6 ${cardCls}`}>
        <div className="flex flex-col lg:flex-row gap-6">
          <div className="lg:w-88 flex-shrink-0 flex flex-col gap-4">
            <div>
              <h2 className={`text-sm font-black tracking-wider uppercase ${textPrimary}`}>Transit Route Playback</h2>
              <p className={`text-xs font-medium mt-1 ${textMuted}`}>Select a flagged permit to inspect its route</p>
            </div>
            <div className={`flex gap-1.5 rounded-xl p-1.5 border ${subtleCls}`}>
              {(['all', 'overload', 'fraud', 'gps'] as const).map((tab) => (
                <button key={tab} onClick={() => setRiskFilter(tab)}
                  className={`flex-1 py-2 rounded-lg text-xs font-black uppercase tracking-wider transition-all ${riskFilter === tab ? 'bg-indigo-600 text-white shadow-sm' : `${textMuted}`}`}>
                  {tab === 'all' ? 'All' : tab === 'overload' ? 'Overload' : tab === 'fraud' ? 'Fraud' : 'GPS Lost'}
                </button>
              ))}
            </div>
            <input type="text" placeholder="Search permit code or truck..." value={transitSearch}
              onChange={(e) => setTransitSearch(e.target.value)}
              className={`w-full rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-1 border transition-colors ${isDark ? 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500 placeholder:text-neutral-600' : 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-400 placeholder:text-neutral-400'}`}
            />
            <div className="space-y-2 max-h-[300px] overflow-y-auto pr-1">
              {filteredTransit.length === 0 ? (
                <p className={`text-sm text-center py-6 ${textMuted}`}>No flagged permits found.</p>
              ) : (
                filteredTransit.map((permit) => {
                  const isSelected = (selectedPermitId || filteredTransit[0]?.id) === permit.id;
                  const isOverload = permit.volumeCubes > 5;
                  const isFraud = permit.status === 'CANCELLED' || (permit.status === 'COMPLETED' && permit.unloadLatitude === null);
                  const dotColor = isOverload && isFraud ? 'bg-rose-500' : isOverload ? 'bg-indigo-500' : isFraud ? 'bg-rose-500' : 'bg-amber-500';
                  return (
                    <button key={permit.id} onClick={() => setSelectedPermitId(permit.id)}
                      className={`w-full text-left rounded-xl px-4 py-3 border transition-all flex items-center gap-3 ${isSelected ? isDark ? 'bg-indigo-500/15 border-indigo-500/40' : 'bg-indigo-50 border-indigo-300/60' : `${subtleCls} hover:border-indigo-400/50`}`}>
                      <div className={`w-2.5 h-2.5 rounded-full flex-shrink-0 ${dotColor}`} />
                      <div className="flex-1 min-w-0">
                        <p className={`text-sm font-bold truncate ${textPrimary}`}>{permit.permitCode}</p>
                        <p className={`text-xs font-medium ${textMuted}`}>{permit.truckNumber} · {permit.volumeCubes.toFixed(1)} m³</p>
                      </div>
                      <ChevronRight className={`w-4 h-4 flex-shrink-0 ${isSelected ? 'text-indigo-400' : textMuted}`} />
                    </button>
                  );
                })
              )}
            </div>
          </div>

          <div className="flex-1 flex flex-col gap-5">
            <div className={`h-64 lg:h-72 rounded-xl border overflow-hidden ${subtleCls}`}>
              {selectedPermit && selectedOriginRecord ? (
                <TransitMap permit={selectedPermit} originRecord={selectedOriginRecord} theme={theme} />
              ) : (
                <div className={`w-full h-full flex flex-col items-center justify-center gap-2 ${textMuted}`}>
                  <Layers className="w-8 h-8 opacity-40" />
                  <p className="text-sm font-semibold opacity-60">Select a permit to view route</p>
                </div>
              )}
            </div>

            {selectedPermit && (
              <div className={`rounded-xl border px-5 py-4 flex flex-wrap gap-5 ${subtleCls}`}>
                {[
                  { label: 'Permit', value: selectedPermit.permitCode },
                  { label: 'Truck', value: selectedPermit.truckNumber },
                  { label: 'Volume', value: `${selectedPermit.volumeCubes.toFixed(1)} m³${selectedPermit.volumeCubes > 5 ? ' ⚠ OVERLOAD' : ''}` },
                  { label: 'Status', value: selectedPermit.status },
                  { label: 'Origin', value: selectedOriginRecord?.name || 'Unknown' },
                  { label: 'Date', value: selectedPermit.transportDate.toLocaleDateString() },
                ].map((item) => (
                  <div key={item.label}>
                    <p className={`text-xs font-bold uppercase tracking-wider ${textMuted}`}>{item.label}</p>
                    <p className={`text-sm font-black mt-0.5 ${item.value.includes('OVERLOAD') || item.value === 'CANCELLED' ? 'text-rose-500' : textPrimary}`}>{item.value}</p>
                  </div>
                ))}
              </div>
            )}

            <div>
              <h3 className={`text-xs font-black tracking-wider uppercase mb-3 flex items-center gap-1.5 ${textMuted}`}>
                <Activity className="w-3.5 h-3.5" /> Event Timeline
              </h3>
              <div className="space-y-2">
                {timelineEvents.length === 0 ? (
                  <p className={`text-sm ${textMuted} py-2`}>Select a permit to view its event log.</p>
                ) : (
                  timelineEvents.map((event, i) => (
                    <div key={i} className={`flex items-start gap-3 rounded-xl px-4 py-3 border ${event.type === 'danger' ? isDark ? 'bg-rose-500/10 border-rose-500/20' : 'bg-rose-50 border-rose-200/60' : event.type === 'warning' ? isDark ? 'bg-amber-500/10 border-amber-500/20' : 'bg-amber-50 border-amber-200/60' : subtleCls}`}>
                      <div className={`mt-0.5 flex-shrink-0 ${event.type === 'danger' ? 'text-rose-500' : event.type === 'warning' ? 'text-amber-500' : 'text-indigo-500'}`}>
                        {event.icon}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className={`text-sm font-bold ${event.type === 'danger' ? 'text-rose-500' : event.type === 'warning' ? 'text-amber-600' : textPrimary}`}>{event.label}</p>
                      </div>
                      <div className={`flex-shrink-0 flex items-center gap-1.5 ${textMuted}`}>
                        <Clock className="w-3 h-3" />
                        <span className="text-xs font-semibold whitespace-nowrap">{event.time}</span>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
