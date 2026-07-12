import { useState, useMemo } from 'react';
import { FileSpreadsheet, Search, Clock, ShieldCheck, ChevronDown, ChevronUp } from 'lucide-react';

export interface AuditLogItem {
  id: string;
  timestamp: Date;
  actor: string;
  action: string;
  details: string;
}

interface AuditLogPanelProps {
  logs: AuditLogItem[];
  theme: 'light' | 'dark';
}

export default function AuditLogPanel({ logs, theme }: AuditLogPanelProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const filteredLogs = useMemo(() => {
    return logs.filter(log => {
      const q = searchQuery.toLowerCase().trim();
      return (
        !q ||
        log.actor.toLowerCase().includes(q) ||
        log.action.toLowerCase().includes(q) ||
        log.details.toLowerCase().includes(q) ||
        log.id.toLowerCase().includes(q)
      );
    });
  }, [logs, searchQuery]);

  return (
    <div
      className={`rounded-3xl border transition-all duration-300 shadow-xl overflow-hidden mt-6 ${
        theme === 'light' ? 'bg-white border-neutral-200' : 'bg-neutral-900 border-neutral-800'
      }`}
    >
      {/* Header (Expand/Collapse toggle) */}
      <div
        onClick={() => setIsExpanded(!isExpanded)}
        className={`p-5 flex justify-between items-center cursor-pointer select-none transition-colors ${
          theme === 'light' ? 'hover:bg-neutral-50/50' : 'hover:bg-neutral-800/30'
        }`}
      >
        <div className="flex items-center gap-3">
          <div className={`p-2 rounded-xl ${theme === 'light' ? 'bg-indigo-50 text-indigo-600' : 'bg-indigo-500/10 text-indigo-400'}`}>
            <ShieldCheck className="w-5 h-5" />
          </div>
          <div>
            <h3 className="font-extrabold text-sm tracking-tight transition-colors">
              Government Accountability Audit Trail
            </h3>
            <p className="text-[10px] text-neutral-400 font-semibold tracking-wide mt-0.5">
              Secure ledger of administrative actions & system alerts ({logs.length} entries)
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {isExpanded ? (
            <ChevronUp className="w-4 h-4 text-neutral-400" />
          ) : (
            <ChevronDown className="w-4 h-4 text-neutral-400" />
          )}
        </div>
      </div>

      {/* Expanded Content */}
      {isExpanded && (
        <div className="p-6 border-t border-neutral-100 dark:border-neutral-800/40 flex flex-col gap-4 max-h-[420px] overflow-hidden">
          {/* Filter Bar */}
          <div className="relative">
            <input
              type="text"
              placeholder="Search audit trail by actor, action, or log ID..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              className={`w-full rounded-xl py-2 pl-9 pr-3 text-xs border transition-colors focus:outline-none focus:ring-1 ${
                theme === 'light'
                  ? 'bg-white border-neutral-200 text-neutral-800 placeholder-neutral-400 focus:ring-indigo-500 focus:border-indigo-500'
                  : 'bg-neutral-950 border-neutral-800 text-neutral-200 placeholder-neutral-600 focus:ring-indigo-500/50 focus:border-indigo-500/50'
              }`}
            />
            <Search className="w-3.5 h-3.5 text-neutral-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>

          {/* Table / List */}
          <div className="flex-1 overflow-y-auto pr-1">
            <div className={`overflow-x-auto border rounded-xl ${theme === 'light' ? 'border-neutral-100 bg-neutral-50/20' : 'border-neutral-800 bg-neutral-950/25'}`}>
              <table className="w-full text-left border-collapse min-w-[650px] text-xs">
                <thead>
                  <tr className={`border-b text-[9px] uppercase tracking-widest font-black ${
                    theme === 'light' ? 'border-neutral-200 bg-neutral-100/50 text-neutral-500' : 'border-neutral-800 bg-neutral-900/40 text-neutral-500'
                  }`}>
                    <th className="py-2.5 px-4">Log ID</th>
                    <th className="py-2.5 px-4">Timestamp</th>
                    <th className="py-2.5 px-4">Actor</th>
                    <th className="py-2.5 px-4">Action Event</th>
                    <th className="py-2.5 px-4">Details</th>
                  </tr>
                </thead>
                <tbody className={`divide-y ${theme === 'light' ? 'divide-neutral-100' : 'divide-neutral-800/40'}`}>
                  {filteredLogs.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="py-8 text-center text-neutral-500 italic">
                        No audit events match search query.
                      </td>
                    </tr>
                  ) : (
                    filteredLogs.map(log => (
                      <tr
                        key={log.id}
                        className={`transition-colors ${
                          theme === 'light' ? 'hover:bg-white/80' : 'hover:bg-neutral-900/30'
                        }`}
                      >
                        <td className="py-2.5 px-4 font-black text-[10px] text-neutral-400 uppercase">
                          {log.id}
                        </td>
                        <td className="py-2.5 px-4 font-sans text-neutral-500">
                          {log.timestamp.toLocaleDateString()} {log.timestamp.toLocaleTimeString()}
                        </td>
                        <td className="py-2.5 px-4 font-sans font-bold text-indigo-600 dark:text-indigo-400">
                          {log.actor}
                        </td>
                        <td className="py-2.5 px-4 font-sans font-extrabold uppercase text-[10px]">
                          {log.action}
                        </td>
                        <td className="py-2.5 px-4 font-sans text-neutral-600 dark:text-neutral-300 leading-normal max-w-[260px] truncate" title={log.details}>
                          {log.details}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
