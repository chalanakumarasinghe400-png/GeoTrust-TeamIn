import { useState, useEffect } from 'react';
import { Bell, BellRing, Check, AlertTriangle, WifiOff, ShieldAlert, X } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';

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
  alerts: AlertItem[];
  onNewAlertTriggered?: (logMessage: string) => void;
}

export default function AlertsPanel({ theme, alerts, onNewAlertTriggered }: AlertsPanelProps) {
  const [readAlertIds, setReadAlertIds] = useState<string[]>([]);
  const [resolvedAlertIds, setResolvedAlertIds] = useState<string[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [toasts, setToasts] = useState<AlertItem[]>([]);
  const [prevAlertsCount, setPrevAlertsCount] = useState(alerts.length);

  // Synchronize new toast alert when alerts list size increases
  useEffect(() => {
    if (alerts.length > prevAlertsCount) {
      const newAlerts = alerts.slice(0, alerts.length - prevAlertsCount);
      setToasts(prev => [...prev, ...newAlerts]);
      newAlerts.forEach(newAlert => {
        if (onNewAlertTriggered) {
          onNewAlertTriggered(`System flagged active permit violation: ${newAlert.message}`);
        }
      });
    }
    setPrevAlertsCount(alerts.length);
  }, [alerts, prevAlertsCount, onNewAlertTriggered]);

  const processedAlerts = alerts.map(alert => ({
    ...alert,
    read: alert.read || readAlertIds.includes(alert.id),
    status: resolvedAlertIds.includes(alert.id) ? ('resolved' as const) : alert.status
  }));

  const unreadCount = processedAlerts.filter(a => !a.read && a.status === 'active').length;

  const handleMarkAllRead = () => {
    const unreadIds = processedAlerts.filter(a => !a.read).map(a => a.id);
    setReadAlertIds(prev => [...prev, ...unreadIds]);
  };

  const handleResolveAlert = (id: string) => {
    setResolvedAlertIds(prev => [...prev, id]);
    setReadAlertIds(prev => [...prev, id]);
    if (onNewAlertTriggered) {
      onNewAlertTriggered(`Admin resolved telemetry alert ${id.toUpperCase()}`);
    }
  };

  const removeToast = (id: string) => {
    setToasts(prev => prev.filter(t => t.id !== id));
  };

  const getAlertIcon = (type: AlertItem['type']) => {
    switch (type) {
      case 'overload':
        return <ShieldAlert className="w-4 h-4 text-rose-500" />;
      case 'gps_lost':
        return <WifiOff className="w-4 h-4 text-amber-500" />;
      case 'unauthorized_route':
        return <AlertTriangle className="w-4 h-4 text-indigo-500" />;
    }
  };

  return (
    <>
      {/* Alert Bell Button */}
      <div className="relative">
        <button
          onClick={() => setIsOpen(!isOpen)}
          className={`p-2 rounded-xl border transition-all duration-300 flex items-center justify-center cursor-pointer shadow-md group relative ${
            isOpen
              ? (theme === 'light' ? 'bg-indigo-50 text-indigo-600 border-indigo-200' : 'bg-indigo-500/10 text-indigo-400 border-indigo-500/30')
              : (theme === 'light' ? 'bg-white hover:bg-neutral-50 text-neutral-600 border-neutral-200' : 'bg-neutral-900 hover:bg-neutral-800 text-neutral-400 border-neutral-800/80')
          }`}
          title="Telemetry Alerts"
        >
          {unreadCount > 0 ? (
            <BellRing className="w-5 h-5 animate-pulse text-rose-500" />
          ) : (
            <Bell className="w-5 h-5 group-hover:rotate-12 transition-transform" />
          )}

          {unreadCount > 0 && (
            <span className="absolute -top-1 -right-1 bg-rose-500 text-white font-black text-[9px] w-4.5 h-4.5 rounded-full flex items-center justify-center shadow-md animate-bounce">
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
                className={`absolute right-0 mt-3 w-[360px] max-h-[480px] rounded-2xl border shadow-2xl flex flex-col overflow-hidden z-[9995] ${
                  theme === 'light' ? 'bg-white border-neutral-200 text-neutral-800' : 'bg-neutral-950 border-neutral-800 text-neutral-200'
                }`}
              >
                {/* Header */}
                <div className={`p-4 border-b flex justify-between items-center ${theme === 'light' ? 'bg-neutral-50 border-neutral-100' : 'bg-neutral-900/40 border-neutral-800/80'}`}>
                  <div>
                    <h3 className="font-extrabold text-xs tracking-wider uppercase">Live Telemetry Alerts</h3>
                    <p className="text-[10px] text-neutral-400 font-mono mt-0.5">{unreadCount} active unresolved anomalies</p>
                  </div>
                  {unreadCount > 0 && (
                    <button
                      onClick={handleMarkAllRead}
                      className="text-[10px] font-bold text-indigo-500 hover:text-indigo-600 transition-colors cursor-pointer flex items-center gap-1"
                    >
                      <Check className="w-3 h-3" /> Mark all read
                    </button>
                  )}
                </div>

                {/* List Container */}
                <div className="flex-1 overflow-y-auto divide-y divide-neutral-100 dark:divide-neutral-800/40">
                  {processedAlerts.length === 0 ? (
                    <div className="p-8 text-center text-xs text-neutral-500 italic">No telemetry alerts active.</div>
                  ) : (
                    processedAlerts.map(alert => (
                      <div
                        key={alert.id}
                        className={`p-4 transition-colors relative flex flex-col gap-1.5 ${
                          alert.read
                            ? ''
                            : (theme === 'light' ? 'bg-indigo-50/20' : 'bg-indigo-500/[0.02]')
                        } ${alert.status === 'resolved' ? 'opacity-60' : ''}`}
                      >
                        <div className="flex items-start justify-between gap-2">
                          <div className="flex items-center gap-1.5 font-mono text-[10px]">
                            {getAlertIcon(alert.type)}
                            <span className="font-black text-neutral-400">{alert.id.toUpperCase()}</span>
                            <span className="text-[9px] text-neutral-500">·</span>
                            <span className="font-extrabold text-neutral-600 dark:text-neutral-300">{alert.truckNumber}</span>
                          </div>
                          <span className="text-[9px] text-neutral-500 font-mono shrink-0">
                            {alert.timestamp.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
                          </span>
                        </div>

                        <p className="text-[11px] leading-relaxed font-medium">{alert.message}</p>

                        <div className="flex items-center justify-between gap-2 mt-1">
                          <span className="text-[9px] font-black uppercase text-neutral-500 tracking-wide font-mono flex items-center gap-1">
                            📍 {alert.location}
                          </span>

                          {alert.status === 'active' ? (
                            <button
                              onClick={() => handleResolveAlert(alert.id)}
                              className={`px-2 py-0.5 rounded text-[9px] font-bold border transition-colors cursor-pointer ${
                                theme === 'light'
                                  ? 'bg-neutral-100 hover:bg-emerald-50 hover:text-emerald-800 hover:border-emerald-200 text-neutral-600 border-neutral-200'
                                  : 'bg-neutral-900 hover:bg-emerald-500/10 hover:text-emerald-300 hover:border-emerald-500/20 text-neutral-400 border-neutral-800/80'
                              }`}
                            >
                              Resolve Alert
                            </button>
                          ) : (
                            <span className="text-[9px] font-bold text-emerald-500 flex items-center gap-0.5">
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
      <div className="fixed bottom-6 right-6 z-[9999] flex flex-col gap-3 max-w-[360px] pointer-events-none">
        <AnimatePresence>
          {toasts.map(toast => (
            <motion.div
              key={toast.id}
              initial={{ opacity: 0, x: 50, y: 0 }}
              animate={{ opacity: 1, x: 0, y: 0 }}
              exit={{ opacity: 0, x: 50 }}
              transition={{ type: 'spring', damping: 18 }}
              className={`p-4 rounded-2xl border shadow-2xl flex items-start gap-3 pointer-events-auto w-[330px] ${
                theme === 'light'
                  ? 'bg-white border-rose-100 text-neutral-800'
                  : 'bg-neutral-950 border-rose-950/40 text-neutral-200'
              }`}
            >
              <div className="p-2 bg-rose-500/10 rounded-xl shrink-0">
                <AlertTriangle className="w-5 h-5 text-rose-500" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex justify-between items-center">
                  <span className="font-extrabold text-[10px] tracking-wider uppercase text-rose-500 font-mono">TELEMETRY ANOMALY</span>
                  <button
                    onClick={() => removeToast(toast.id)}
                    className="text-neutral-400 hover:text-neutral-200 transition-colors cursor-pointer"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                </div>
                <h4 className="font-bold text-xs mt-1 truncate">{toast.truckNumber}</h4>
                <p className="text-[11px] leading-relaxed text-neutral-500 dark:text-neutral-400 mt-1">{toast.message}</p>
                <div className="text-[9px] text-neutral-400 mt-2 flex items-center gap-1 font-mono">
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
