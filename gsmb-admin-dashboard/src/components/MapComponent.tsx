import { useEffect, useRef, useState } from 'react';
import { Globe, Layers } from 'lucide-react';
import { ProcessedLocationRecord } from '../types';

interface MapComponentProps {
  records: ProcessedLocationRecord[];
  activeRecordId: string | null;
  onSelectRecord: (id: string) => void;
  theme?: 'dark' | 'light';
}

const FALLBACK_CENTER: [number, number] = [7.8731, 80.7718];

export default function MapComponent({
  records,
  activeRecordId,
  onSelectRecord,
  theme = 'dark',
}: MapComponentProps) {
  const [mapType, setMapType] = useState<'streets' | 'satellite'>('streets');
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<any>(null);
  const markersRef = useRef<any[]>([]);
  const prevActiveIdRef = useRef<string | null>(null);
  const isFirstRenderRef = useRef<boolean>(true);

  // Manual trigger to view whole country
  const handleResetView = () => {
    if (mapRef.current) {
      const bounds: any[] = records.map((r) => r.coordinates);
      if (bounds.length > 0) {
        mapRef.current.fitBounds(bounds, { padding: [50, 50], animate: true });
      } else {
        mapRef.current.setView(FALLBACK_CENTER, 7.5, { animate: true });
      }
    }
  };

  useEffect(() => {
    const L = (window as any).L;
    if (!L || !mapContainerRef.current) return;

    const isLight = theme === 'light';
    const tileUrl = mapType === 'satellite'
      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
      : (isLight
        ? 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png');

    // Initialize map if it doesn't exist
    if (!mapRef.current) {
      mapRef.current = L.map(mapContainerRef.current, {
        scrollWheelZoom: true,
        touchZoom: true,
        bounceAtZoomLimits: true,
        zoomControl: true,
        tap: true,
      }).setView(FALLBACK_CENTER, 7.5);

      const tileLayer = L.tileLayer(tileUrl, {
        maxZoom: 19,
        attribution: '&copy; <a href="https://carto.com/attributions">CARTO</a> contributors',
      }).addTo(mapRef.current);

      mapRef.current._tileLayerInstance = tileLayer;
    } else {
      // Dynamic tile layer swap
      if (mapRef.current._tileLayerInstance) {
        mapRef.current._tileLayerInstance.setUrl(tileUrl);
      }
    }

    const map = mapRef.current;

    // Clear old markers
    markersRef.current.forEach((marker) => marker.remove());
    markersRef.current = [];

    const bounds: any[] = [];

    // Add new markers
    records.forEach((record) => {
      const isSelected = record.id === activeRecordId;
      const markerColor =
        record.risk === 'high'
          ? '#fb7185' // rose
          : record.risk === 'medium'
          ? '#fbbf24' // amber
          : '#34d399'; // cyan/emerald

      // Custom HTML DivIcon to match beautiful theme
      const icon = L.divIcon({
        className: 'custom-react-marker',
        html: `
          <div style="
            width: ${isSelected ? '22px' : '14px'};
            height: ${isSelected ? '22px' : '14px'};
            border-radius: 999px;
            background: ${markerColor};
            border: 2px solid #ffffff;
            box-shadow: 0 0 16px ${markerColor}, 0 0 0 ${isSelected ? '8px' : '3px'} rgba(255, 255, 255, 0.2);
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            cursor: pointer;
          "></div>
        `,
        iconSize: isSelected ? [22, 22] : [14, 14],
        iconAnchor: isSelected ? [11, 11] : [7, 7],
      });

      const marker = L.marker(record.coordinates, { icon }).addTo(map);

      // Create beautiful theme-based popup content
      const popupBg = isLight ? '#ffffff' : '#0f172a';
      const popupText = isLight ? '#1f2937' : '#e2e8f0';
      const popupTitle = isLight ? '#111827' : '#ffffff';
      const popupSub = isLight ? '#4b5563' : '#94a3b8';
      const popupIncidentText = isLight ? '#374151' : '#cbd5e1';

      const isOverloaded = record.isOverloaded;
      const riskText = isOverloaded ? 'OVERLOADED' : `${record.risk.toUpperCase()} RISK`;
      const riskBg = isOverloaded 
        ? 'rgba(239, 68, 68, 0.25)' 
        : (record.risk === 'high' ? 'rgba(251, 113, 133, 0.2)' : record.risk === 'medium' ? 'rgba(251, 191, 36, 0.2)' : 'rgba(52, 211, 153, 0.2)');
      const riskColor = isOverloaded ? '#f87171' : markerColor;

      const popupContent = `
        <div style="font-family: system-ui, sans-serif; color: ${popupText}; padding: 2px;">
          <h4 style="margin: 0 0 4px 0; font-size: 14px; font-weight: 700; color: ${popupTitle};">${record.name}</h4>
          <p style="margin: 0 0 6px 0; font-size: 11px; color: ${popupSub}; text-transform: uppercase; letter-spacing: 0.05em;">
            ${record.type} · ${record.region}
          </p>
          <div style="display: flex; align-items: center; gap: 8px; font-size: 12px;">
            <span style="
              display: inline-block;
              padding: 2px 8px;
              border-radius: 999px;
              font-weight: 700;
              font-size: 10px;
              text-transform: uppercase;
              background: ${riskBg};
              color: ${riskColor};
            ">${riskText}</span>
            <span style="color: ${popupIncidentText}; font-weight: 500;">${record.incidents} Incidents</span>
          </div>
        </div>
      `;

      marker.bindPopup(popupContent, {
        closeButton: false,
        className: 'dark-leaflet-popup',
      });

      marker.on('click', () => {
        onSelectRecord(record.id);
      });

      markersRef.current.push(marker);
      bounds.push(record.coordinates);
    });

    // Zoom map to fit active selection, or overall bounds, or center
    // Track change in activeRecordId to prevent snapping back if user manually zooms out/pans
    if (activeRecordId) {
      if (isFirstRenderRef.current || prevActiveIdRef.current !== activeRecordId) {
        const activeRecord = records.find((r) => r.id === activeRecordId);
        if (activeRecord) {
          map.flyTo(activeRecord.coordinates, 18, { // zoom in closer (18 instead of 16)
            animate: true,
            duration: 1.5
          });
        }
        prevActiveIdRef.current = activeRecordId;
      }
    } else {
      if (isFirstRenderRef.current || prevActiveIdRef.current !== null) {
        if (bounds.length > 0) {
          map.fitBounds(bounds, { padding: [40, 40], animate: true });
        } else {
          map.setView(FALLBACK_CENTER, 7.5, { animate: true });
        }
        prevActiveIdRef.current = null;
      }
    }
    isFirstRenderRef.current = false;
  }, [records, activeRecordId, onSelectRecord, mapType, theme]);

  // Clean up on unmount
  useEffect(() => {
    return () => {
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, []);

  return (
    <div className={`relative w-full h-[500px] md:h-[560px] rounded-3xl overflow-hidden border shadow-2xl transition-all duration-300 ${
      theme === 'light' ? 'border-neutral-200 bg-white' : 'border-neutral-800 bg-neutral-950'
    }`}>
      {/* Absolute overlay for styling */}
      <div className={`absolute top-4 left-4 z-[1000] backdrop-blur-md px-3.5 py-1.5 rounded-full border text-[10px] tracking-widest uppercase font-black flex items-center gap-1.5 shadow-lg transition-all duration-300 ${
        theme === 'light'
          ? 'bg-white/90 border-neutral-200 text-indigo-600'
          : 'bg-neutral-900/90 border-neutral-800 text-indigo-400'
      }`}>
        <span className="w-2 h-2 rounded-full bg-indigo-500 animate-pulse"></span>
        LIVE OVERVIEW MAP
      </div>

      {/* Map Control Buttons overlay */}
      <div className="absolute bottom-4 right-4 z-[1000] flex gap-2">
        {/* Map Type Toggle */}
        <button
          onClick={() => setMapType(prev => prev === 'streets' ? 'satellite' : 'streets')}
          className={`cursor-pointer flex items-center gap-2 px-4 py-2.5 text-xs font-black rounded-2xl shadow-xl border hover:scale-105 active:scale-95 transition-all duration-200 ${
            theme === 'light'
              ? 'bg-white border-neutral-200 text-neutral-800 hover:bg-neutral-50 shadow-md'
              : 'bg-neutral-900 border-neutral-800 text-white hover:bg-neutral-800 shadow-2xl'
          }`}
        >
          <Layers className="w-4 h-4 text-indigo-500 dark:text-indigo-400" />
          <span>{mapType === 'streets' ? 'Satellite View' : 'Map View'}</span>
        </button>

        {/* Whole Country View */}
        <button
          onClick={handleResetView}
          className={`cursor-pointer flex items-center gap-2 px-4 py-2.5 text-xs font-black rounded-2xl shadow-xl border hover:scale-105 active:scale-95 transition-all duration-200 ${
            theme === 'light'
              ? 'bg-white border-neutral-200 text-neutral-800 hover:bg-neutral-50 hover:border-neutral-300 shadow-md'
              : 'bg-neutral-900 border-neutral-800 text-white hover:bg-neutral-800 hover:border-neutral-700 shadow-2xl'
          }`}
        >
          <Globe className="w-4 h-4 text-indigo-500 dark:text-indigo-400 animate-spin-slow" />
          <span>View Whole Country</span>
        </button>
      </div>
      
      {/* Leaflet instance container */}
      <div ref={mapContainerRef} className="w-full h-full" id="map-element" />
    </div>
  );
}
