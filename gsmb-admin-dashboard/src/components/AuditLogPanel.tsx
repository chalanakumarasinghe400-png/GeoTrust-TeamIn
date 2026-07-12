import { useState, useMemo, useEffect } from 'react';
import { ShieldCheck, ChevronDown, ChevronUp, Search, Trash2, X, Maximize2, ChevronLeft, ChevronRight } from 'lucide-react';

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
  onDeleteLog?: (id: string) => void;
  onClearLogs?: () => void;
}

export default function AuditLogPanel({ logs, theme, onDeleteLog, onClearLogs }: AuditLogPanelProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [modalSearchQuery, setModalSearchQuery] = useState('');

  const itemsPerPage = 10;
  const totalPages = Math.ceil(logs.length / itemsPerPage);

  // Auto-adjust current page if elements are deleted
  useEffect(() => {
    if (currentPage > totalPages) {
      setCurrentPage(Math.max(1, totalPages));
    }
  }, [logs.length, totalPages, currentPage]);

  const currentLogs = useMemo(() => {
    const startIndex = (currentPage - 1) * itemsPerPage;
    return logs.slice(startIndex, startIndex + itemsPerPage);
  }, [logs, currentPage]);

  const filteredModalLogs = useMemo(() => {
    return logs.filter(log => {
      const q = modalSearchQuery.toLowerCase().trim();
      return (
        !q ||
        log.actor.toLowerCase().includes(q) ||
        log.action.toLowerCase().includes(q) ||
        log.details.toLowerCase().includes(q) ||
        log.id.toLowerCase().includes(q)
      );
    });
  }, [logs, modalSearchQuery]);

  return (
    <div
      className={`rounded-3xl border transition-all duration-300 shadow-xl overflow-hidden ${
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
        <div className="flex items-center gap-2" onClick={(e) => e.stopPropagation()}>
          {isExpanded && (
            <button
              onClick={() => setIsModalOpen(true)}
              className={`px-3 py-1.5 rounded-xl border font-bold text-xs flex items-center gap-1.5 transition-all cursor-pointer mr-2 ${
                theme === 'light'
                  ? 'bg-indigo-50 hover:bg-indigo-100/80 text-indigo-600 border-indigo-200/80'
                  : 'bg-indigo-500/10 hover:bg-indigo-500/25 text-indigo-400 border-indigo-500/30'
              }`}
            >
              <Maximize2 className="w-3.5 h-3.5" />
              Show All
            </button>
          )}
          <div
            onClick={() => setIsExpanded(!isExpanded)}
            className="p-1 cursor-pointer hover:bg-neutral-500/10 rounded-lg transition-colors"
          >
            {isExpanded ? (
              <ChevronUp className="w-4 h-4 text-neutral-400" />
            ) : (
              <ChevronDown className="w-4 h-4 text-neutral-400" />
            )}
          </div>
        </div>
      </div>

      {/* Expanded Content */}
      {isExpanded && (
        <div className="p-6 border-t border-neutral-100 dark:border-neutral-800/40 flex flex-col gap-4">
          
          {/* Table / List */}
          <div className="overflow-x-auto border rounded-xl overflow-hidden border-neutral-100 dark:border-neutral-800 bg-neutral-50/10 dark:bg-neutral-950/10">
            <table className="w-full text-left border-collapse min-w-[650px] text-xs">
              <thead>
                <tr className={`border-b text-[9px] uppercase tracking-widest font-black ${
                  theme === 'light' ? 'border-neutral-200 bg-neutral-100/50 text-neutral-500' : 'border-neutral-800 bg-neutral-900/40 text-neutral-500'
                }`}>
                  <th className="py-2.5 px-4 w-20">Log ID</th>
                  <th className="py-2.5 px-4 w-40">Timestamp</th>
                  <th className="py-2.5 px-4 w-40">Actor</th>
                  <th className="py-2.5 px-4 w-48">Action Event</th>
                  <th className="py-2.5 px-4">Details</th>
                  <th className="py-2.5 px-4 w-16 text-center">Actions</th>
                </tr>
              </thead>
              <tbody className={`divide-y ${theme === 'light' ? 'divide-neutral-100' : 'divide-neutral-800/40'}`}>
                {currentLogs.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-8 text-center text-neutral-500 italic">
                      No logs stored in the audit trail.
                    </td>
                  </tr>
                ) : (
                  currentLogs.map(log => (
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
                      <td className="py-2.5 px-4 text-center">
                        {onDeleteLog && (
                          <button
                            onClick={() => onDeleteLog(log.id)}
                            className="p-1 rounded text-neutral-400 hover:text-rose-500 transition-colors cursor-pointer"
                            title="Delete Log"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        )}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination Footer */}
          {logs.length > 0 && (
            <div className="flex items-center justify-between mt-2 px-1 text-xs select-none">
              <button
                onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                disabled={currentPage === 1}
                className={`px-3 py-1.5 rounded-xl border font-extrabold transition-all duration-300 flex items-center gap-1 cursor-pointer ${
                  currentPage === 1
                    ? 'opacity-40 cursor-not-allowed border-transparent text-neutral-400'
                    : (theme === 'light' ? 'bg-white hover:bg-neutral-50 text-neutral-700 border-neutral-200' : 'bg-neutral-800 hover:bg-neutral-700 text-neutral-300 border-neutral-700')
                }`}
              >
                <ChevronLeft className="w-4 h-4" /> Previous
              </button>
              <span className="font-extrabold text-neutral-500">
                Page {currentPage} of {totalPages || 1}
              </span>
              <button
                onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                disabled={currentPage === totalPages || totalPages === 0}
                className={`px-3 py-1.5 rounded-xl border font-extrabold transition-all duration-300 flex items-center gap-1 cursor-pointer ${
                  currentPage === totalPages || totalPages === 0
                    ? 'opacity-40 cursor-not-allowed border-transparent text-neutral-400'
                    : (theme === 'light' ? 'bg-white hover:bg-neutral-50 text-neutral-700 border-neutral-200' : 'bg-neutral-800 hover:bg-neutral-700 text-neutral-300 border-neutral-700')
                }`}
              >
                Next <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          )}
        </div>
      )}

      {/* Show All Modal Popup Window */}
      {isModalOpen && (
        <div className="fixed inset-0 z-[99999] flex items-center justify-center p-4">
          {/* Overlay */}
          <div className="fixed inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setIsModalOpen(false)} />

          {/* Modal Content */}
          <div className={`relative w-full max-w-5xl h-[85vh] rounded-3xl border shadow-2xl flex flex-col overflow-hidden transition-all duration-300 ${
            theme === 'light' ? 'bg-white border-neutral-200 text-neutral-800' : 'bg-neutral-900 border-neutral-800 text-neutral-200'
          }`}>
            {/* Header */}
            <div className={`p-6 border-b flex justify-between items-center ${
              theme === 'light' ? 'bg-neutral-50 border-neutral-100' : 'bg-neutral-950/40 border-neutral-800/80'
            }`}>
              <div className="flex items-center gap-3">
                <div className={`p-2.5 rounded-xl ${theme === 'light' ? 'bg-indigo-50 text-indigo-600' : 'bg-indigo-500/10 text-indigo-400'}`}>
                  <ShieldCheck className="w-6 h-6" />
                </div>
                <div>
                  <h3 className="font-extrabold text-base tracking-tight">Accountability Audit Ledger</h3>
                  <p className="text-xs text-neutral-400 font-semibold mt-0.5">
                    Browse, filter, and delete secure ledger events ({logs.length} records)
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                {onClearLogs && logs.length > 0 && (
                  <button
                    onClick={() => {
                      if (window.confirm("Are you sure you want to permanently clear the audit ledger?")) {
                        onClearLogs();
                      }
                    }}
                    className={`px-3 py-1.5 rounded-xl border border-rose-500/30 text-rose-500 text-xs font-bold transition-colors hover:bg-rose-500/10 cursor-pointer`}
                  >
                    Clear Ledger
                  </button>
                )}
                <button
                  onClick={() => setIsModalOpen(false)}
                  className={`p-2 rounded-xl border transition-colors hover:bg-neutral-500/10 cursor-pointer ${
                    theme === 'light' ? 'border-neutral-200 text-neutral-500' : 'border-neutral-800 text-neutral-400'
                  }`}
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            {/* Filter Bar inside Modal */}
            <div className="p-6 pb-2">
              <div className="relative">
                <input
                  type="text"
                  placeholder="Search audit trail by log ID, actor email, action event, or details..."
                  value={modalSearchQuery}
                  onChange={e => setModalSearchQuery(e.target.value)}
                  className={`w-full rounded-2xl py-3 pl-11 pr-4 text-sm border transition-colors focus:outline-none focus:ring-1 ${
                    theme === 'light'
                      ? 'bg-neutral-50 border-neutral-200 text-neutral-800 placeholder-neutral-400 focus:ring-indigo-500 focus:border-indigo-500'
                      : 'bg-neutral-950 border-neutral-800 text-neutral-200 placeholder-neutral-600 focus:ring-indigo-500/50 focus:border-indigo-500/50'
                  }`}
                />
                <Search className="w-4 h-4 text-neutral-400 absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none" />
              </div>
            </div>

            {/* Scrollable List Container */}
            <div className="flex-1 overflow-y-auto px-6 pb-6">
              <div className={`overflow-x-auto border rounded-2xl ${theme === 'light' ? 'border-neutral-200 bg-neutral-50/10' : 'border-neutral-800 bg-neutral-950/20'}`}>
                <table className="w-full text-left border-collapse min-w-[700px] text-xs">
                  <thead>
                    <tr className={`border-b text-[10px] uppercase tracking-widest font-black ${
                      theme === 'light' ? 'border-neutral-200 bg-neutral-100/50 text-neutral-500' : 'border-neutral-800 bg-neutral-900/40 text-neutral-500'
                    }`}>
                      <th className="py-3 px-4 w-24">Log ID</th>
                      <th className="py-3 px-4 w-44">Timestamp</th>
                      <th className="py-3 px-4 w-48">Actor</th>
                      <th className="py-3 px-4 w-52">Action Event</th>
                      <th className="py-3 px-4">Details</th>
                      <th className="py-3 px-4 w-16 text-center">Actions</th>
                    </tr>
                  </thead>
                  <tbody className={`divide-y ${theme === 'light' ? 'divide-neutral-100' : 'divide-neutral-800/40'}`}>
                    {filteredModalLogs.length === 0 ? (
                      <tr>
                        <td colSpan={6} className="py-12 text-center text-sm text-neutral-500 italic">
                          No audit events match search query.
                        </td>
                      </tr>
                    ) : (
                      filteredModalLogs.map(log => (
                        <tr
                          key={log.id}
                          className={`transition-colors ${
                            theme === 'light' ? 'hover:bg-white' : 'hover:bg-neutral-950/40'
                          }`}
                        >
                          <td className="py-3 px-4 font-black text-[10px] text-neutral-400 uppercase">
                            {log.id}
                          </td>
                          <td className="py-3 px-4 font-sans text-neutral-500">
                            {log.timestamp.toLocaleDateString()} {log.timestamp.toLocaleTimeString()}
                          </td>
                          <td className="py-3 px-4 font-sans font-bold text-indigo-600 dark:text-indigo-400">
                            {log.actor}
                          </td>
                          <td className="py-3 px-4 font-sans font-extrabold uppercase text-[10px]">
                            {log.action}
                          </td>
                          <td className="py-3 px-4 font-sans text-neutral-600 dark:text-neutral-300 leading-normal" style={{ wordBreak: 'break-word' }}>
                            {log.details}
                          </td>
                          <td className="py-3 px-4 text-center">
                            {onDeleteLog && (
                              <button
                                onClick={() => onDeleteLog(log.id)}
                                className="p-1 rounded text-neutral-400 hover:text-rose-500 transition-colors cursor-pointer"
                                title="Delete Log"
                              >
                                <Trash2 className="w-3.5 h-3.5" />
                              </button>
                            )}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
