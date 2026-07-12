import { useState, useEffect, useMemo } from 'react';
import { Bell, BellRing, Check, AlertTriangle, WifiOff, ShieldAlert, X, Trash2 } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { ProcessedPermit } from '../types';

export interface AlertItem {
  id: string;
  timestamp: Date;
  truckNumber: string;
  location: string;
  type: 'overload' | 'gps_lost' | 'unauthorized_route';
  status: 'active' | 'resolved';
  message: string;
  read: boolean;
}

interface AlertsPanelProps {
  theme: 'light' | 'dark';
  permits: ProcessedPermit[];
  onNewAlertTriggered?: (logMessage: string) => void;
  onSelectPermit?: (permitId: string) => void;
}

export function deriveAlertsFromPermits(permits: ProcessedPermit[]): AlertItem[] {
  if (!permits) return [];
  const list: AlertItem[] = [];

  permits.forEach((permit) => {
    // 1. Cargo overload (> 5.0 cubes)
    if (permit.volumeCubes > 5.0) {
      list.push({
        id: `alt-ov-${permit.id}`,
        timestamp: permit.transportDate,
        truckNumber: permit.truckNumber,
        location: permit.originLocationName || 'Unknown Site',
        type: 'overload',
        status: permit.status === 'COMPLETED' ? 'resolved' : 'active',
        message: `Load limit warning: volume capacity threshold exceeded (${permit.volumeCubes}m³ registered, maximum 5.0m³).`,
        read: false,
      });
    }

    // 2. Deviation / cancelled permit
    if (permit.status === 'CANCELLED') {
      list.push({
        id: `alt-ur-${permit.id}`,
        timestamp: permit.transportDate,
        truckNumber: permit.truckNumber,
        location: permit.originLocationName || 'Unknown Site',
        type: 'unauthorized_route',
        status: 'active',
        message: `Geofencing alert: vehicle transit path cancelled (possible deviation detected).`,
        read: false,
      });
    }

    // 3. Completed but missing GPS coordinates
    if (permit.status === 'COMPLETED' && (permit.unloadLatitude === null || permit.unloadLongitude === null)) {
      list.push({
        id: `alt-gps-${permit.id}`,
        timestamp: permit.transportDate,
        truckNumber: permit.truckNumber,
        location: permit.originLocationName || 'Unknown Site',
        type: 'gps_lost',
        status: 'active',
        message: `Telemetry alert: completed permit has no registered unload location GPS data.`,
        read: false,
      });
    }
  });

  // Sort descending by timestamp
  return list.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());
}

export default function AlertsPanel({ theme, permits = [], onNewAlertTriggered, onSelectPermit }: AlertsPanelProps) {
  const [resolvedIds, setResolvedIds] = useState<string[]>(() => {
    try {
      const stored = localStorage.getItem('geotrust_resolved_ids');
      return stored ? JSON.parse(stored) : [];
    } catch {
      return [];
    }
  });
  const [readIds, setReadIds] = useState<string[]>(() => {
    try {
      const stored = localStorage.getItem('geotrust_read_ids');
      return stored ? JSON.parse(stored) : [];
    } catch {
      return [];
    }
  });
  const [seenIds, setSeenIds] = useState<string[]>(() => {
    try {
      const stored = localStorage.getItem('geotrust_seen_ids');
      return stored ? JSON.parse(stored) : [];
    } catch {
      return [];
    }
  });
  const [clearedIds, setClearedIds] = useState<string[]>(() => {
    try {
      const stored = localStorage.getItem('geotrust_cleared_ids');
      return stored ? JSON.parse(stored) : [];
    } catch {
      return [];
    }
  });
  const [toasts, setToasts] = useState<AlertItem[]>([]);
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    localStorage.setItem('geotrust_resolved_ids', JSON.stringify(resolvedIds));
  }, [resolvedIds]);

  useEffect(() => {
    localStorage.setItem('geotrust_read_ids', JSON.stringify(readIds));
  }, [readIds]);

  useEffect(() => {
    localStorage.setItem('geotrust_seen_ids', JSON.stringify(seenIds));
  }, [seenIds]);

  useEffect(() => {
    localStorage.setItem('geotrust_cleared_ids', JSON.stringify(clearedIds));
  }, [clearedIds]);

  // Compute final alerts list overlaying user actions
  const alerts = useMemo(() => {
    return deriveAlertsFromPermits(permits)
      .filter((alert) => !clearedIds.includes(alert.id))
      .map((alert) => {
        const isResolved = resolvedIds.includes(alert.id) || alert.status === 'resolved';
        const isRead = readIds.includes(alert.id) || alert.read || isResolved;
        return {
          ...alert,
          status: isResolved ? ('resolved' as const) : ('active' as const),
          read: isRead,
        };
      });
  }, [permits, resolvedIds, readIds, clearedIds]);

  const handleClearAll = () => {
    const allIds = deriveAlertsFromPermits(permits).map((a) => a.id);
    setClearedIds((prev) => [...new Set([...prev, ...allIds])]);
    setReadIds((prev) => [...new Set([...prev, ...allIds])]);
  };

  const unreadCount = alerts.filter((a) => !a.read).length;

  // Sync effect to show toast warnings only for newly arrived database alerts
  useEffect(() => {
    if (!permits || permits.length === 0) return;

    const currentAlerts = deriveAlertsFromPermits(permits);
    const currentIds = currentAlerts.map((a) => a.id);

    if (seenIds.length === 0) {
      setSeenIds(currentIds);
      return;
    }

    const newAlerts = currentAlerts.filter((a) => !seenIds.includes(a.id) && a.status === 'active');
    if (newAlerts.length > 0) {
      setToasts((prev) => [...prev, ...newAlerts]);
      setSeenIds((prev) => [...prev, ...newAlerts.map((a) => a.id)]);

      if (onNewAlertTriggered) {
        newAlerts.forEach((alert) => {
          onNewAlertTriggered(`Live database sync detected alert ${alert.id.toUpperCase()} on vehicle ${alert.truckNumber}`);
        });
      }
    }
  }, [permits, seenIds, onNewAlertTriggered]);

  const handleMarkAllRead = () => {
    const unreadAlerts = alerts.filter((a) => !a.read);
    setReadIds((prev) => [...prev, ...unreadAlerts.map((a) => a.id)]);
  };

  const handleResolveAlert = (id: string) => {
    setResolvedIds((prev) => [...prev, id]);
    setReadIds((prev) => [...prev, id]);
    if (onNewAlertTriggered) {
      onNewAlertTriggered(`Admin resolved telemetry alert ${id.toUpperCase()}`);
    }
  };

  const removeToast = (id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  const handleAlertClick = (alert: AlertItem) => {
    if (!alert.read) {
      setReadIds((prev) => [...prev, alert.id]);
    }
    setIsOpen(false);
    const permitId = alert.id.replace('alt-ov-', '').replace('alt-ur-', '').replace('alt-gps-', '');
    if (onSelectPermit) {
      onSelectPermit(permitId);
    }
  };

  const getAlertIcon = (type: AlertItem['type']) => {
    switch (type) {
      case 'overload':
        return <ShieldAlert className="w-5 h-5 text-rose-500 shrink-0" />;
      case 'gps_lost':
        return <WifiOff className="w-5 h-5 text-amber-500 shrink-0" />;
      case 'unauthorized_route':
        return <AlertTriangle className="w-5 h-5 text-indigo-500 shrink-0" />;
    }
  };

  return (
    <>
      {/* Alert Bell Button */}
      <div className="relative flex items-center">
        <button
          onClick={() => setIsOpen(!isOpen)}
          className={`h-11 w-11 rounded-xl border transition-all duration-300 flex items-center justify-center cursor-pointer shadow-md group relative ${isOpen
            ? (theme === 'light' ? 'bg-indigo-100/80 text-indigo-600 border-indigo-300' : 'bg-indigo-500/15 text-indigo-400 border-indigo-500/40')
            : (theme === 'light' ? 'bg-white hover:bg-indigo-50/50 text-slate-900 border-indigo-200/80 hover:border-indigo-300' : 'bg-slate-800 hover:bg-slate-700 text-neutral-400 border-slate-700 hover:border-slate-600')
            }`}
          title="Telemetry Alerts"
        >
          {unreadCount > 0 ? (
            <BellRing className="w-5 h-5 animate-pulse text-rose-500" />
          ) : (
            <Bell className="w-5 h-5 group-hover:rotate-12 transition-transform" />
          )}

          {unreadCount > 0 && (
            <span className="absolute -top-1 -right-1 bg-rose-500 text-white font-black text-[10px] w-5 h-5 rounded-full flex items-center justify-center shadow-md animate-bounce">
              {unreadCount}
            </span>
          )}
        </button>

        {/* Alerts Dropdown Panel */}
        <AnimatePresence>
          {isOpen && (
            <>
              {/* Overlay cover to close dropdown on click outside */}
              <div className="fixed inset-0 z-[9990]" onClick={() => setIsOpen(false)} />

              <motion.div
                initial={{ opacity: 0, y: 15, scale: 0.95 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: 15, scale: 0.95 }}
                transition={{ duration: 0.2 }}
                className={`absolute right-0 top-full mt-3 w-[400px] max-h-[500px] rounded-2xl border shadow-2xl flex flex-col overflow-hidden z-[9995] ${theme === 'light' ? 'bg-white border-slate-200 text-black' : 'bg-slate-900 border-slate-800 text-slate-100'
                  }`}
              >
                {/* Header */}
                <div className={`p-4 border-b flex justify-between items-center ${theme === 'light' ? 'bg-slate-50 border-slate-100' : 'bg-slate-950/60 border-slate-800/80'}`}>
                  <div>
                    <h3 className="font-extrabold text-sm tracking-wider uppercase text-black dark:text-white" style={{ color: theme === 'light' ? '#000000' : undefined }}>Live Telemetry Alerts</h3>
                    <p className="text-xs text-black/80 dark:text-slate-400 font-semibold tracking-wide mt-0.5" style={{ color: theme === 'light' ? '#000000' : undefined }}>{unreadCount} active unresolved anomalies</p>
                  </div>
                  <div className="flex items-center gap-3">
                    {unreadCount > 0 && (
                      <button
                        onClick={handleMarkAllRead}
                        className="text-xs font-bold text-indigo-600 hover:text-indigo-800 dark:text-indigo-400 dark:hover:text-indigo-300 transition-colors cursor-pointer flex items-center gap-1"
                      >
                        <Check className="w-3.5 h-3.5" /> Mark all read
                      </button>
                    )}
                    {alerts.length > 0 && (
                      <button
                        onClick={handleClearAll}
                        className="text-xs font-bold text-rose-600 hover:text-rose-800 dark:text-rose-400 dark:hover:text-rose-300 transition-colors cursor-pointer flex items-center gap-1"
                      >
                        <Trash2 className="w-3.5 h-3.5" /> Clear all
                      </button>
                    )}
                  </div>
                </div>

                {/* List Container */}
                <div className="flex-1 overflow-y-auto divide-y divide-slate-100 dark:divide-slate-800/50">
                  {alerts.length === 0 ? (
                    <div className="p-8 text-center text-sm text-slate-500 italic">No telemetry alerts active.</div>
                  ) : (
                    alerts.map(alert => (
                      <div
                        key={alert.id}
                        onClick={() => handleAlertClick(alert)}
                        className={`p-4 transition-colors relative flex flex-col gap-1.5 cursor-pointer ${alert.read
                          ? (theme === 'light' ? 'hover:bg-slate-50' : 'hover:bg-slate-800/60')
                          : (theme === 'light' ? 'bg-indigo-50 hover:bg-indigo-100/70' : 'bg-indigo-950/40 hover:bg-indigo-950/60')
                          } ${alert.status === 'resolved' ? 'opacity-55' : ''}`}
                      >
                        <div className="flex items-start justify-between gap-2">
                          <div className="flex items-center gap-2 font-medium tracking-wider text-xs">
                            {getAlertIcon(alert.type)}
                            <span className="font-extrabold text-black dark:text-slate-400" style={{ color: theme === 'light' ? '#000000' : undefined }}>{alert.id.toUpperCase()}</span>
                            <span className="text-slate-400 dark:text-slate-500">·</span>
                            <span className="font-black text-black dark:text-white" style={{ color: theme === 'light' ? '#000000' : undefined }}>{alert.truckNumber}</span>
                          </div>
                          <span className="text-[11px] text-black dark:text-slate-400 shrink-0 font-mono font-bold" style={{ color: theme === 'light' ? '#000000' : undefined }}>
                            {alert.timestamp.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
                          </span>
                        </div>

                        <p className="text-[13.5px] leading-relaxed font-bold text-black dark:text-slate-200" style={{ color: theme === 'light' ? '#000000' : undefined }}>{alert.message}</p>

                        <div className="flex items-center justify-between gap-2 mt-1">
                          <span className="text-[11px] font-black uppercase text-black dark:text-slate-400 tracking-wider flex items-center gap-1" style={{ color: theme === 'light' ? '#000000' : undefined }}>
                            📍 {alert.location}
                          </span>

                          {alert.status === 'active' ? (
                            <button
                              onClick={(e) => { e.stopPropagation(); handleResolveAlert(alert.id); }}
                              className={`px-3 py-1 rounded text-xs font-bold border transition-colors cursor-pointer ${theme === 'light'
                                ? 'bg-slate-100 hover:bg-slate-200 text-slate-800 border-slate-300 shadow-sm'
                                : 'bg-slate-800 hover:bg-slate-700 text-slate-300 border-slate-700'
                                }`}
                            >
                              Resolve Alert
                            </button>
                          ) : (
                            <span className="text-xs font-bold text-emerald-500 dark:text-emerald-400 flex items-center gap-0.5">
                              ✓ Resolved
                            </span>
                          )}
                        </div>

                        {/* Unread indicator circle */}
                        {!alert.read && (
                          <span className="absolute top-4 right-4 w-1.5 h-1.5 rounded-full bg-indigo-500 animate-pulse"></span>
                        )}
                      </div>
                    ))
                  )}
                </div>
              </motion.div>
            </>
          )}
        </AnimatePresence>
      </div>

      {/* Floating Toast Alerts (Bottom-Right) */}
      <div className="fixed bottom-6 right-6 z-[9999] flex flex-col gap-3 max-w-[380px] pointer-events-none">
        <AnimatePresence>
          {toasts.map(toast => (
            <motion.div
              key={toast.id}
              initial={{ opacity: 0, x: 50, y: 0 }}
              animate={{ opacity: 1, x: 0, y: 0 }}
              exit={{ opacity: 0, x: 50 }}
              transition={{ type: 'spring', damping: 18 }}
              onClick={() => {
                removeToast(toast.id);
                const permitId = toast.id.replace('alt-ov-', '').replace('alt-ur-', '').replace('alt-gps-', '');
                if (onSelectPermit) {
                  onSelectPermit(permitId);
                }
              }}
              className={`p-4 rounded-2xl border shadow-2xl flex items-start gap-3 pointer-events-auto w-[360px] cursor-pointer hover:scale-[1.02] transition-transform duration-200 ${theme === 'light'
                ? 'bg-white border-rose-100 text-black shadow-xl'
                : 'bg-slate-900 border-rose-950/40 text-slate-100 shadow-2xl'
                }`}
            >
              <div className="p-2 bg-rose-500/10 rounded-xl shrink-0">
                <AlertTriangle className="w-5 h-5 text-rose-500" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex justify-between items-center">
                  <span className="font-extrabold text-[11px] tracking-wider uppercase text-rose-500">TELEMETRY ANOMALY</span>
                  <button
                    onClick={(e) => { e.stopPropagation(); removeToast(toast.id); }}
                    className="text-slate-400 hover:text-slate-200 transition-colors cursor-pointer"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                </div>
                <h4 className="font-black text-sm mt-1 truncate text-black dark:text-white" style={{ color: theme === 'light' ? '#000000' : undefined }}>{toast.truckNumber}</h4>
                <p className="text-[13px] leading-relaxed text-black dark:text-slate-300 mt-1 font-bold" style={{ color: theme === 'light' ? '#000000' : undefined }}>{toast.message}</p>
                <div className="text-[11px] text-black/80 dark:text-slate-400 mt-2 flex items-center gap-1 font-semibold" style={{ color: theme === 'light' ? '#000000' : undefined }}>
                  📍 {toast.location}
                </div>
              </div>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </>
  );
}
