import { X, Download, ShieldCheck, HelpCircle } from 'lucide-react';
import { ProcessedPermit } from '../types';
import jsPDF from 'jspdf';

interface PermitModalProps {
  permit: ProcessedPermit | null;
  onClose: () => void;
  theme: 'light' | 'dark';
}

export default function PermitModal({ permit, onClose, theme }: PermitModalProps) {
  if (!permit) return null;

  const qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(permit.permitCode)}`;

  const handleDownloadPdf = async () => {
    try {
      const doc = new jsPDF({
        orientation: 'portrait',
        unit: 'mm',
        format: 'a4'
      });

      // ── Clean & Minimal PDF Layout ──
      
      // Top boundary line
      doc.setDrawColor(226, 232, 240); // slate-200
      doc.setLineWidth(0.5);
      doc.line(14, 12, 196, 12);

      // Letterhead Text
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(10);
      doc.setTextColor(71, 85, 105); // slate-600
      doc.text('GEOLOGICAL SURVEY & MINES BUREAU', 14, 20);
      
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(8);
      doc.setTextColor(148, 163, 184); // slate-400
      doc.text('SRI LANKA · MINISTRY OF ENVIRONMENT', 14, 24);

      // Document Title
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(18);
      doc.setTextColor(15, 23, 42); // slate-900
      doc.text('MINERAL TRANSIT PERMIT', 14, 38);

      // Verified Badge (Drawing a clean label)
      doc.setFillColor(240, 253, 250); // teal-50
      doc.roundedRect(14, 43, 38, 5.5, 1, 1, 'F');
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(7);
      doc.setTextColor(13, 148, 136); // teal-600
      doc.text('✓ OFFICIAL & VALIDATED', 17, 47);

      // Horizontal separator
      doc.setDrawColor(226, 232, 240); // slate-200
      doc.line(14, 54, 196, 54);

      // Details columns
      doc.setFontSize(8);
      
      // Column 1 Row 1
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(100, 116, 139); // slate-500
      doc.text('Permit Reference ID:', 14, 63);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(15, 23, 42);
      doc.text(permit.permitCode, 14, 68);

      // Column 2 Row 1
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(100, 116, 139);
      doc.text('Vehicle Registration:', 110, 63);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(15, 23, 42);
      doc.text(permit.truckNumber, 110, 68);

      // Column 1 Row 2
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(100, 116, 139);
      doc.text('Mineral Type & Quantity:', 14, 79);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(15, 23, 42);
      doc.text(`River Sand — ${permit.volumeCubes} Cubic Meters (m³)`, 14, 84);

      // Column 2 Row 2
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(100, 116, 139);
      doc.text('Site Origin & Quarry Depot:', 110, 79);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(15, 23, 42);
      doc.text(permit.originLocationName || 'Registered Mining Site', 110, 84);

      // Column 1 Row 3
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(100, 116, 139);
      doc.text('Transport Authorized On:', 14, 95);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(15, 23, 42);
      doc.text(permit.transportDate.toLocaleDateString(), 14, 100);

      // Column 2 Row 3
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(100, 116, 139);
      doc.text('Transit Status:', 110, 95);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(15, 23, 42);
      doc.text(permit.status, 110, 100);

      // Horizontal separator
      doc.line(14, 108, 196, 108);

      // Attempt to load and embed QR code image
      try {
        const res = await fetch(qrCodeUrl);
        const blob = await res.blob();
        const qrBase64 = await new Promise<string>((resolve) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result as string);
          reader.readAsDataURL(blob);
        });
        doc.addImage(qrBase64, 'PNG', 158, 16, 32, 32);
      } catch (err) {
        // Fallback placeholder border if offline
        doc.setDrawColor(203, 213, 225);
        doc.rect(158, 16, 32, 32);
        doc.setFontSize(6);
        doc.text('QR CODE ONLINE ONLY', 160, 32);
      }

      // Footnote
      doc.setFont('helvetica', 'italic');
      doc.setFontSize(7.5);
      doc.setTextColor(148, 163, 184); // slate-400
      doc.text('Note: This document is issued digitally in accordance with Section 11 of the Mines and Minerals Act No. 33 of 1992.', 14, 120);

      // Signature Block
      doc.setDrawColor(203, 213, 225);
      
      // Line for Officer
      doc.line(14, 150, 75, 150);
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(7.5);
      doc.setTextColor(100, 116, 139);
      doc.text('Authorized GSMB Officer', 14, 154);

      // Line for Driver
      doc.line(110, 150, 171, 150);
      doc.text('Driver / Permit Holder', 110, 154);

      // Save document
      doc.save(`permit-${permit.permitCode}.pdf`);
    } catch (e) {
      console.error(e);
      alert('Error generating PDF.');
    }
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-[9999] p-4">
      {/* Modal Card */}
      <div
        className={`w-full max-w-xl rounded-3xl border shadow-2xl flex flex-col overflow-hidden animate-scaleIn ${
          theme === 'light' ? 'bg-white border-neutral-200 text-neutral-800' : 'bg-neutral-950 border-neutral-800 text-neutral-200'
        }`}
      >
        {/* Header */}
        <div className={`p-6 border-b flex justify-between items-center ${theme === 'light' ? 'bg-neutral-50/50 border-neutral-100' : 'bg-neutral-900/40 border-neutral-800/80'}`}>
          <div className="flex items-center gap-2">
            <ShieldCheck className="w-5 h-5 text-indigo-500" />
            <div>
              <h2 className="font-extrabold text-sm tracking-wide uppercase">Digital Transit Permit Profile</h2>
              <p className="text-[10px] text-neutral-400 font-mono mt-0.5">{permit.id}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-xl hover:bg-neutral-100 dark:hover:bg-neutral-800/60 transition-colors cursor-pointer text-neutral-400 hover:text-neutral-200"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 flex flex-col md:flex-row gap-6 items-center md:items-start overflow-y-auto">
          {/* Left Details */}
          <div className="flex-1 w-full flex flex-col gap-4">
            <div className="flex items-center gap-2">
              <span className={`px-2.5 py-0.5 rounded-full text-[9px] font-black uppercase ${
                permit.status === 'ACTIVE' ? 'bg-indigo-500/10 text-indigo-400 border border-indigo-500/20'
                : permit.status === 'COMPLETED' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'
              }`}>
                {permit.status}
              </span>
              <span className="text-[10px] font-bold text-neutral-400 flex items-center gap-1">
                <HelpCircle className="w-3 h-3" /> Verification: Valid
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
              <div className="flex flex-col gap-0.5">
                <span className="text-neutral-400 font-bold uppercase text-[9px]">Permit Code</span>
                <span className="font-mono font-black text-sm">{permit.permitCode}</span>
              </div>
              <div className="flex flex-col gap-0.5">
                <span className="text-neutral-400 font-bold uppercase text-[9px]">Truck Plate</span>
                <div className={`px-2.5 py-1 rounded bg-amber-400 text-neutral-900 border border-amber-500 w-max font-mono font-extrabold text-[11px] shadow-sm`}>
                  {permit.truckNumber}
                </div>
              </div>
              <div className="flex flex-col gap-0.5">
                <span className="text-neutral-400 font-bold uppercase text-[9px]">Mineral Volume</span>
                <span className="font-bold font-mono text-sm">{permit.volumeCubes} m³</span>
              </div>
              <div className="flex flex-col gap-0.5">
                <span className="text-neutral-400 font-bold uppercase text-[9px]">Origin Site</span>
                <span className="font-bold text-indigo-500 dark:text-indigo-400">{permit.originLocationName || 'N/A'}</span>
              </div>
              <div className="flex flex-col gap-0.5">
                <span className="text-neutral-400 font-bold uppercase text-[9px]">Date Authorized</span>
                <span className="font-bold text-neutral-600 dark:text-neutral-300">{permit.transportDate.toLocaleDateString()}</span>
              </div>
              <div className="flex flex-col gap-0.5">
                <span className="text-neutral-400 font-bold uppercase text-[9px]">Telemetry Bounds</span>
                <span className="font-mono text-neutral-500">
                  {permit.unloadLatitude ? `${Number(permit.unloadLatitude).toFixed(4)}, ${Number(permit.unloadLongitude).toFixed(4)}` : 'N/A (Offline)'}
                </span>
              </div>
            </div>
          </div>

          {/* Right QR Section */}
          <div className="flex flex-col items-center gap-3 shrink-0 p-4 border rounded-2xl border-neutral-100 dark:border-neutral-800 bg-neutral-50/20 dark:bg-neutral-900/10">
            <img
              src={qrCodeUrl}
              alt="Scan Permit QR"
              className="w-28 h-28 bg-white p-1.5 rounded-xl border border-neutral-200"
            />
            <span className="text-[9px] font-black text-neutral-400 font-mono tracking-wider uppercase">FIELD SCANNABLE CODE</span>
          </div>
        </div>

        {/* Action Footer */}
        <div className={`p-6 border-t flex justify-end gap-3 ${theme === 'light' ? 'bg-neutral-50/50 border-neutral-100' : 'bg-neutral-900/20 border-neutral-800/80'}`}>
          <button
            onClick={onClose}
            className={`px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              theme === 'light'
                ? 'bg-neutral-100 hover:bg-neutral-200 text-neutral-600 border border-neutral-200'
                : 'bg-neutral-900 hover:bg-neutral-800 text-neutral-400 border border-neutral-800/80'
            }`}
          >
            Close
          </button>
          <button
            onClick={handleDownloadPdf}
            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center gap-1.5 shadow-md shadow-indigo-600/20"
          >
            <Download className="w-3.5 h-3.5" /> Download PDF Permit
          </button>
        </div>
      </div>
    </div>
  );
}
