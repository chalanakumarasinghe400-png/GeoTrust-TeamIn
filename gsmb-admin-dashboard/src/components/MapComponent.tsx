import { useEffect, useRef, useState } from 'react';
import { Globe, Layers } from 'lucide-react';
import { ProcessedLocationRecord } from '../types';

interface MapComponentProps {
  records: ProcessedLocationRecord[];
  activeRecordId: string | null;
  onSelectRecord: (id: string) => void;
  theme?: 'dark' | 'light';
  dbUsers?: any[];
}

const FALLBACK_CENTER: [number, number] = [7.8731, 80.7718];

export default function MapComponent({
  records,
  activeRecordId,
  onSelectRecord,
  theme = 'dark',
  dbUsers = [],
}: MapComponentProps) {
  const [mapType, setMapType] = useState<'streets' | 'satellite'>(() => {
    return (localStorage.getItem('geotrust_map_type') as any) || 'streets';
  });

  useEffect(() => {
    localStorage.setItem('geotrust_map_type', mapType);
  }, [mapType]);
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

  // Effect to initialize the map
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
  }, [mapType, theme]);

  // Effect to populate markers (Triggered when records/theme/users change)
  useEffect(() => {
    const L = (window as any).L;
    if (!L || !mapRef.current) return;

    const map = mapRef.current;
    const isLight = theme === 'light';

    // Clear old markers
    markersRef.current.forEach((marker) => marker.remove());
    markersRef.current = [];

    const bounds: any[] = [];

    records.forEach((record) => {
      const isSelected = record.id === activeRecordId;
      const markerColor =
        record.risk === 'high'
          ? '#fb7185' // rose
          : record.risk === 'medium'
            ? '#fbbf24' // amber
            : '#34d399'; // cyan/emerald

      const isHighRisk = record.risk === 'high';
      const dotSize = isHighRisk ? 13 : 10;
      const borderSize = isHighRisk ? 3 : 2.5;

      const shadowStyle = isHighRisk
        ? `0 0 16px ${markerColor}, 0 0 0 ${borderSize}px rgba(255, 255, 255, 0.2)`
        : 'none';
      const borderStyle = isHighRisk ? '2px solid #ffffff' : '1px solid rgba(0, 0, 0, 0.8)';

      // Default icon - uses targeted transition to avoid transition animations lagging Leaflet transform positioning
      const icon = L.divIcon({
        className: 'custom-react-marker',
        html: `
          <div style="
            width: ${dotSize}px;
            height: ${dotSize}px;
            border-radius: 999px;
            background: ${markerColor};
            border: ${borderStyle};
            box-shadow: ${shadowStyle};
            transition: width 0.3s cubic-bezier(0.4, 0, 0.2, 1), height 0.3s cubic-bezier(0.4, 0, 0.2, 1), background 0.3s, box-shadow 0.3s;
            cursor: pointer;
          "></div>
        `,
        iconSize: [dotSize, dotSize],
        iconAnchor: [dotSize / 2, dotSize / 2],
      });

      // Layer ordering priority: active > high risk > medium risk > low risk
      const zIndexOffset = isSelected ? 2000 : record.risk === 'high' ? 1000 : record.risk === 'medium' ? 500 : 0;

      const marker = L.marker(record.coordinates, { icon, zIndexOffset }).addTo(map);
      (marker as any).recordId = record.id;
      (marker as any).markerColor = markerColor;

      // Create beautiful theme-based popup content mimicking the row details popup without the map
      const popupBg = isLight ? '#ffffff' : '#0f172a';
      const popupTitle = isLight ? '#0f172a' : '#ffffff';
      const popupText = isLight ? '#334155' : '#cbd5e1';
      const cardBorder = isLight ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.08)';
      const cardBgLight = isLight ? '#f8fafc' : '#090d16';
      const textMuted = isLight ? '#64748b' : '#94a3b8';
      const progressBarBg = isLight ? '#e2e8f0' : '#1e293b';

      const owner = dbUsers ? dbUsers.find((u: any) => u.user_id === record.user_id || u.id === record.user_id) : null;
      const ownerName = owner ? (owner.name || 'Unknown') : 'Unassigned';
      const ownerNic = owner ? (owner.nic || 'N/A') : 'N/A';

      const fill = record.maxCapacity > 0 ? Math.round((record.inventory / record.maxCapacity) * 100) : 0;
      const isOverloaded = record.inventory > record.maxCapacity;

      const fillBarColor = isOverloaded ? '#f43f5e' : fill > 75 ? '#eab308' : '#10b981';
      const statusTextColor = isOverloaded ? '#f43f5e' : (record.type === 'Mine' ? '#10b981' : '#6366f1');

      const popupContent = `
        <div style="font-family: system-ui, sans-serif; color: ${popupText}; width: 285px; padding: 2px; display: flex; flex-direction: column; gap: 10px;">
          <!-- Header -->
          <div style="display: flex; align-items: center; gap: 10px;">
            <div style="
              width: 36px;
              height: 36px;
              border-radius: 10px;
              display: flex;
              align-items: center;
              justify-content: center;
              background: ${record.type === 'Mine' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(99, 102, 241, 0.15)'};
              color: ${record.type === 'Mine' ? '#10b981' : '#6366f1'};
              flex-shrink: 0;
            ">
              ${record.type === 'Mine'
          ? `<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16c0 1.1.9 2 2 2h12a2 2 0 0 0 2-2V8l-6-6z"/><path d="M14 3v5h5M16 13H8M16 17H8M10 9H8"/></svg>`
          : `<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 10v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V10M12 2 2 7l10 5 10-5-10-5z"/></svg>`
        }
            </div>
            <div style="overflow: hidden;">
              <span style="display: block; font-size: 8px; font-weight: 900; text-transform: uppercase; letter-spacing: 0.05em; color: ${record.type === 'Mine' ? '#10b981' : '#6366f1'};">${record.type}</span>
              <h4 style="margin: 0; font-size: 13px; font-weight: 800; color: ${popupTitle}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 220px;">${record.name}</h4>
            </div>
          </div>

          <!-- Stats Grid -->
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
            <div style="padding: 6px 8px; border-radius: 10px; border: 1px solid ${cardBorder}; background: ${cardBgLight}; display: flex; flex-direction: column;">
              <span style="font-size: 7.5px; font-weight: 800; text-transform: uppercase; color: ${textMuted}; letter-spacing: 0.02em;">Current Stock</span>
              <span style="font-size: 11px; font-weight: 700; color: ${isOverloaded ? '#f43f5e' : popupTitle}; margin-top: 1px;">${record.inventory} m³</span>
            </div>
            <div style="padding: 6px 8px; border-radius: 10px; border: 1px solid ${cardBorder}; background: ${cardBgLight}; display: flex; flex-direction: column;">
              <span style="font-size: 7.5px; font-weight: 800; text-transform: uppercase; color: ${textMuted}; letter-spacing: 0.02em;">Max Capacity</span>
              <span style="font-size: 11px; font-weight: 700; color: ${popupTitle}; margin-top: 1px;">${record.maxCapacity} m³</span>
            </div>
            <div style="padding: 6px 8px; border-radius: 10px; border: 1px solid ${cardBorder}; background: ${cardBgLight}; display: flex; flex-direction: column; overflow: hidden;">
              <span style="font-size: 7.5px; font-weight: 800; text-transform: uppercase; color: ${textMuted}; letter-spacing: 0.02em; white-space: nowrap;">Owner</span>
              <span style="font-size: 11px; font-weight: 700; color: ${popupTitle}; margin-top: 1px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="${ownerName}">${ownerName}</span>
            </div>
            <div style="padding: 6px 8px; border-radius: 10px; border: 1px solid ${cardBorder}; background: ${cardBgLight}; display: flex; flex-direction: column;">
              <span style="font-size: 7.5px; font-weight: 800; text-transform: uppercase; color: ${textMuted}; letter-spacing: 0.02em;">Owner NIC</span>
              <span style="font-size: 11px; font-weight: 700; color: ${popupTitle}; margin-top: 1px;">${ownerNic}</span>
            </div>
          </div>

          <!-- Location ID -->
          <div style="padding: 6px 8px; border-radius: 10px; border: 1px solid ${cardBorder}; background: ${cardBgLight}; display: flex; flex-direction: column;">
            <span style="font-size: 7.5px; font-weight: 800; text-transform: uppercase; color: ${textMuted}; letter-spacing: 0.02em;">Location ID</span>
            <span style="font-size: 9.5px; font-family: monospace; color: ${textMuted}; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; margin-top: 1px;">${record.id}</span>
          </div>

          <!-- Capacity Fill Bar -->
          <div style="padding: 8px 10px; border-radius: 10px; border: 1px solid ${cardBorder}; background: ${cardBgLight};">
            <div style="display: flex; justify-content: space-between; font-size: 9.5px; font-weight: 700; margin-bottom: 5px;">
              <span style="color: ${textMuted};">Capacity Fill</span>
              <span style="color: ${statusTextColor}; font-weight: 800;">${fill}% ${isOverloaded ? '⚠ OVERLOADED' : ''}</span>
            </div>
            <div style="width: 100%; height: 6px; border-radius: 99px; background: ${progressBarBg}; overflow: hidden;">
              <div style="width: ${Math.min(fill, 100)}%; height: 100%; border-radius: 99px; background: ${fillBarColor};"></div>
            </div>
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

    // Zoom map to fit initial overall bounds
    if (!activeRecordId && bounds.length > 0 && isFirstRenderRef.current) {
      map.fitBounds(bounds, { padding: [40, 40], animate: false });
    }
  }, [records, theme, dbUsers]);

  // Effect to handle activeRecordId changes (Smooth zoom, icon size modifications, and dynamic z-index layering)
  useEffect(() => {
    const L = (window as any).L;
    if (!L || !mapRef.current) return;

    const map = mapRef.current;

    // Handle escape key to close active popups
    const handleEscKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        map.closePopup();
        onSelectRecord(null);
      }
    };
    window.addEventListener('keydown', handleEscKey);

    // Reset standard and active icons + update dynamic zIndexOffset priority
    markersRef.current.forEach((marker) => {
      const isSelected = marker.recordId === activeRecordId;
      const markerColor = marker.markerColor;

      const record = records.find(r => r.id === marker.recordId);
      const risk = record ? record.risk : 'low';

      // Layers priority: selected (2000) > high risk (1000) > medium risk (500) > low risk (0)
      const zIndexOffset = isSelected ? 2000 : risk === 'high' ? 1000 : risk === 'medium' ? 500 : 0;
      marker.setZIndexOffset(zIndexOffset);

      const isHighRisk = risk === 'high';
      let dotSize = 10;
      if (isSelected) {
        dotSize = isHighRisk ? 20 : 16;
      } else {
        dotSize = isHighRisk ? 13 : 10;
      }

      const borderSize = isHighRisk ? 3 : 2.5;

      const shadowStyle = isHighRisk
        ? `0 0 16px ${markerColor}, 0 0 0 ${isSelected ? '6px' : `${borderSize}px`} rgba(255, 255, 255, 0.2)`
        : 'none';
      const borderStyle = isHighRisk ? '2px solid #ffffff' : '1px solid rgba(0, 0, 0, 0.8)';

      const icon = L.divIcon({
        className: 'custom-react-marker',
        html: `
          <div style="
            width: ${dotSize}px;
            height: ${dotSize}px;
            border-radius: 999px;
            background: ${markerColor};
            border: ${borderStyle};
            box-shadow: ${shadowStyle};
            transition: width 0.3s cubic-bezier(0.4, 0, 0.2, 1), height 0.3s cubic-bezier(0.4, 0, 0.2, 1), background 0.3s, box-shadow 0.3s;
            cursor: pointer;
          "></div>
        `,
        iconSize: [dotSize, dotSize],
        iconAnchor: [dotSize / 2, dotSize / 2],
      });

      marker.setIcon(icon);
    });

    let timer: any;
    if (activeRecordId) {
      const activeRecord = records.find((r) => r.id === activeRecordId);
      if (activeRecord) {
        // Zoom and pan smoothly to the selection
        if (isFirstRenderRef.current || prevActiveIdRef.current !== activeRecordId) {
          map.setView(activeRecord.coordinates, 15, {
            animate: true,
            duration: 1.0,
          });
          prevActiveIdRef.current = activeRecordId;
        }

        // Open marker popup smoothly after animation settles
        const activeMarker = markersRef.current.find(m => m.recordId === activeRecordId);
        if (activeMarker && !activeMarker.isPopupOpen()) {
          timer = setTimeout(() => {
            if (activeMarker && map.hasLayer(activeMarker)) {
              activeMarker.openPopup();
            }
          }, 450);
        }
      }
    } else {
      if (isFirstRenderRef.current || prevActiveIdRef.current !== null) {
        const bounds = records.map(r => r.coordinates);
        if (bounds.length > 0) {
          map.fitBounds(bounds, { padding: [40, 40], animate: true });
        }
        prevActiveIdRef.current = null;
      }
    }
    isFirstRenderRef.current = false;

    return () => {
      window.removeEventListener('keydown', handleEscKey);
      if (timer) clearTimeout(timer);
    };
  }, [activeRecordId, records, onSelectRecord]);

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
    <div className={`relative w-full h-[500px] md:h-[560px] rounded-3xl overflow-hidden border shadow-2xl transition-all duration-300 ${theme === 'light' ? 'border-neutral-200 bg-white' : 'border-neutral-800 bg-neutral-950'
      }`}>
      {/* Absolute overlay for styling */}
      <div className={`absolute top-4 left-4 z-[1000] backdrop-blur-md px-3.5 py-1.5 rounded-full border text-[10px] tracking-widest uppercase font-black flex items-center gap-1.5 shadow-lg transition-all duration-300 ${theme === 'light'
        ? 'bg-white/90 border-neutral-200 text-indigo-600'
        : 'bg-neutral-900/90 border-neutral-800 text-indigo-400'
        }`}>
        <span className="w-2 h-2 rounded-full bg-indigo-500 animate-pulse"></span>
        LIVE OVERVIEW MAP
      </div>

      {/* Map Control Buttons overlay */}
      <div className="absolute bottom-4 left-4 right-4 sm:left-auto sm:right-4 z-[1000] flex justify-end gap-1.5 sm:gap-2">
        {/* Map Type Toggle */}
        <button
          onClick={() => setMapType(prev => prev === 'streets' ? 'satellite' : 'streets')}
          className={`cursor-pointer flex items-center gap-2 px-4 py-2.5 text-xs font-black rounded-2xl shadow-xl border hover:scale-105 active:scale-95 transition-all duration-200 ${theme === 'light'
              ? 'bg-white border-neutral-200 text-neutral-800 hover:bg-neutral-50 shadow-md'
              : 'bg-neutral-900 border-neutral-800 text-white hover:bg-neutral-800 shadow-2xl'
            }`}
        >
          <Layers className="w-3.5 sm:w-4 h-3.5 sm:h-4 text-indigo-500 dark:text-indigo-400" />
          <span>
            {mapType === 'streets' ? (
              <>
                <span className="hidden sm:inline">Satellite View</span>
                <span className="inline sm:hidden">Satellite</span>
              </>
            ) : (
              <>
                <span className="hidden sm:inline">Map View</span>
                <span className="inline sm:hidden">Map</span>
              </>
            )}
          </span>
        </button>

        {/* Whole Country View */}
        <button
          onClick={handleResetView}
          className={`cursor-pointer flex items-center gap-2 px-4 py-2.5 text-xs font-black rounded-2xl shadow-xl border hover:scale-105 active:scale-95 transition-all duration-200 ${theme === 'light'
              ? 'bg-white border-neutral-200 text-neutral-800 hover:bg-neutral-50 hover:border-neutral-300 shadow-md'
              : 'bg-neutral-900 border-neutral-800 text-white hover:bg-neutral-800 hover:border-neutral-700 shadow-2xl'
            }`}
        >
          <Globe className="w-3.5 sm:w-4 h-3.5 sm:h-4 text-indigo-500 dark:text-indigo-400 animate-spin-slow" />
          <span>
            <span className="hidden sm:inline">View Whole Country</span>
            <span className="inline sm:hidden">Sri Lanka</span>
          </span>
        </button>
      </div>

      {/* Leaflet instance container */}
      <div ref={mapContainerRef} className="w-full h-full" id="map-element" />
    </div>
  );
}
