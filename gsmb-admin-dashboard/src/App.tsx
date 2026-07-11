import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { jsPDF } from 'jspdf';
import {
  Search,
  RotateCw,
  Download,
  ShieldAlert,
  MapPin,
  Truck,
  AlertTriangle,
  Calendar,
  Clock,
  Building2,
  HardHat,
  FileText,
  CheckCircle2,
  XCircle,
  TrendingUp,
  Boxes,
  Activity,
  ChevronRight,
  ChevronDown,
  Info,
  Mail,
  Phone,
  Send,
  ShieldCheck,
  Check,
  ExternalLink,
  MessageSquare,
  HelpCircle,
  User,
  ListFilter,
  Sun,
  Moon,
  X,
  Users,
  ChevronLeft,
  Eye,
  Copy,
  CheckCheck,
} from 'lucide-react';
import MapComponent from './components/MapComponent';
import { IncidentTrendChart, PermitStatusChart } from './components/Charts';
import {
  RawLocation,
  RawPermit,
  ProcessedPermit,
  ProcessedLocationRecord,
  DashboardData,
  StatusCounts,
  IncidentSeries,
} from './types';

const SUPABASE_URL = 'https://jtumrmelwetgzyiprfol.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0dW1ybWVsd2V0Z3p5aXByZm9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3MzY5ODksImV4cCI6MjA4OTMxMjk4OX0.8o99Izp2nVmpSUNn01CeHu0MSIesX6ocvK9sOwDZ0E4';

const FALLBACK_CENTER: [number, number] = [7.8731, 80.7718];

const parseLocalDate = (dateInput: string | Date | null | undefined): Date => {
  if (!dateInput) return new Date();
  if (dateInput instanceof Date) return dateInput;
  // If format is like YYYY-MM-DD (optionally with time), take the first part
  const dateStr = typeof dateInput === 'string' ? dateInput.split('T')[0] : '';
  const parts = dateStr.split('-');
  if (parts.length === 3) {
    const year = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10) - 1;
    const day = parseInt(parts[2], 10);
    return new Date(year, month, day);
  }
  return new Date(dateInput);
};

const getLocalDateString = (d: Date = new Date()): string => {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

// Initial blank dashboard data structure
const initialDashboardData = (): DashboardData => ({
  generatedAt: new Date(),
  metrics: [
    { label: 'Registered Users', value: 0, note: 'Connecting to accounts...' },
    { label: 'Active Mines', value: 0, note: 'Loading extraction sites...' },
    { label: 'Hardware Stores', value: 0, note: 'Loading depot registries...' },
    { label: 'Logistics Trucks', value: 0, note: 'Loading vehicle fleet...' },
    { label: 'Open overloads', value: 0, note: 'Analyzing permit loads...' },
    { label: 'Fraud flags', value: 0, note: 'Scanning for active anomalies...' },
    { label: 'Active permits', value: 0, note: 'Calculating active permit volume...' },
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
});

const generateUUID = () => {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
};
// ── Standalone Map Component — must be defined OUTSIDE App so React never re-creates
//    its component type between renders (which causes Leaflet to glitch).
interface PopupMapProps {
  lat: number;
  lng: number;
  label: string;
  theme: 'dark' | 'light';
}
function PopupMap({ lat, lng, label, theme }: PopupMapProps) {
  const containerRef = React.useRef<HTMLDivElement>(null);
  const mapRef = React.useRef<any>(null);

  React.useEffect(() => {
    const L = (window as any).L;
    if (!L || !containerRef.current) return;

    // Safety check to avoid duplicate map instances
    if (mapRef.current) {
      try { mapRef.current.remove(); } catch (_) { }
      mapRef.current = null;
    }

    const map = L.map(containerRef.current, {
      scrollWheelZoom: true,
      touchZoom: true,
      doubleClickZoom: true,
      zoomControl: true,
      dragging: true,
      tap: true,
    }).setView([lat, lng], 14);
    mapRef.current = map;

    L.tileLayer(
      theme === 'light'
        ? 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
      { maxZoom: 19, attribution: '&copy; <a href="https://carto.com/attributions">CARTO</a>' }
    ).addTo(map);

    const icon = L.divIcon({
      className: '',
      html: `<div style="width:20px;height:20px;background:#6366f1;border-radius:50%;border:3px solid white;box-shadow:0 3px 12px rgba(99,102,241,0.45);"></div>`,
      iconSize: [20, 20],
      iconAnchor: [10, 10],
    });

    L.marker([lat, lng], { icon }).addTo(map).bindPopup(`<strong>${label}</strong><br/>${lat.toFixed(5)}, ${lng.toFixed(5)}`).openPopup();

    return () => {
      if (mapRef.current) {
        try { mapRef.current.remove(); } catch (_) { }
        mapRef.current = null;
      }
    };
  }, [lat, lng, theme]);

  return <div ref={containerRef} className="w-full h-full min-h-[300px] md:min-h-[400px]" />;
}


export default function App() {

  // Dark / Light Theme state
  const [theme, setTheme] = useState<'dark' | 'light'>(() => {
    const saved = localStorage.getItem('gsmb-theme');
    return (saved === 'light' || saved === 'dark') ? saved : 'dark';
  });

  useEffect(() => {
    localStorage.setItem('gsmb-theme', theme);
    if (theme === 'light') {
      document.body.classList.add('theme-light');
    } else {
      document.body.classList.remove('theme-light');
    }
  }, [theme]);

  // Live Date and Time State
  const [liveDateTime, setLiveDateTime] = useState<Date>(new Date());

  useEffect(() => {
    const timer = setInterval(() => {
      setLiveDateTime(new Date());
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const [data, setData] = useState<DashboardData>(initialDashboardData());
  const [allRawPermits, setAllRawPermits] = useState<ProcessedPermit[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [isSyncing, setIsSyncing] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [activeRecordId, setActiveRecordId] = useState<string | null>(null);
  const [dbUsers, setDbUsers] = useState<any[]>([]);
  const [dbMineUserIds, setDbMineUserIds] = useState<string[]>([]);
  const [dbHardwareUserIds, setDbHardwareUserIds] = useState<string[]>([]);
  const [dbSchema, setDbSchema] = useState<any>(null);

  // Auth state variables
  const [authToken, setAuthToken] = useState<string | null>(() => {
    return localStorage.getItem('gsmb-auth-token') || null;
  });
  const [authEmail, setAuthEmail] = useState('');
  const [authPassword, setAuthPassword] = useState('');
  const [authLoading, setAuthLoading] = useState(false);
  const [authError, setAuthError] = useState<string | null>(null);
  const [authUser, setAuthUser] = useState<any>(() => {
    const saved = localStorage.getItem('gsmb-auth-user');
    try {
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });

  useEffect(() => {
    if (authToken) {
      localStorage.setItem('gsmb-auth-token', authToken);
    } else {
      localStorage.removeItem('gsmb-auth-token');
    }
  }, [authToken]);

  useEffect(() => {
    if (authUser) {
      localStorage.setItem('gsmb-auth-user', JSON.stringify(authUser));
      setFbName(authUser.user_metadata?.full_name || authUser.name || authUser.email?.split('@')[0] || 'Administrator');
      setFbEmail(authUser.email || '');
    } else {
      localStorage.removeItem('gsmb-auth-user');
    }
  }, [authUser]);

  // Invite / Recovery state variables
  const [inviteToken, setInviteToken] = useState<string | null>(null);
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [setPasswordSuccess, setSetPasswordSuccess] = useState(false);

  // Parse invite/recovery hash parameter
  useEffect(() => {
    const checkHash = () => {
      const hash = window.location.hash;
      if (hash && hash.startsWith('#')) {
        const params = new URLSearchParams(hash.slice(1));
        const accessToken = params.get('access_token');
        const type = params.get('type');
        if (accessToken && (type === 'invite' || type === 'recovery')) {
          setInviteToken(accessToken);
          window.location.hash = '';
        }
      }
    };
    checkHash();
  }, []);

  const handleLoginSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setAuthError(null);
    setAuthLoading(true);
    try {
      const response = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
        method: 'POST',
        headers: {
          apikey: SUPABASE_ANON_KEY,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email: authEmail.trim(),
          password: authPassword
        })
      });
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error_description || data.error || 'Authentication failed');
      }
      setAuthToken(data.access_token);
      setAuthUser(data.user);
    } catch (err: any) {
      setAuthError(err.message || 'Login failed');
    } finally {
      setAuthLoading(false);
    }
  };

  const handleSetPasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setAuthError(null);
    if (newPassword.length < 6) {
      setAuthError('Password must be at least 6 characters long');
      return;
    }
    if (newPassword !== confirmPassword) {
      setAuthError('Passwords do not match');
      return;
    }
    setAuthLoading(true);
    try {
      const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
        method: 'PUT',
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${inviteToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          password: newPassword
        })
      });
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error_description || data.error || 'Failed to update password');
      }
      // Do NOT log in automatically, clear invite state and require signing in manually
      setInviteToken(null);
      setNewPassword('');
      setConfirmPassword('');
      setSetPasswordSuccess(true);
    } catch (err: any) {
      setAuthError(err.message || 'Failed to set password');
    } finally {
      setAuthLoading(false);
    }
  };

  const handleLogout = () => {
    setAuthToken(null);
    setAuthUser(null);
    setAuthEmail('');
    setAuthPassword('');
  };

  // Page routing state
  const [activePage, setActivePage] = useState<'dashboard' | 'registry' | 'new-register' | 'about' | 'contact' | 'data-explorer'>(() => {
    const saved = localStorage.getItem('gsmb_active_page');
    const validPages = ['dashboard', 'registry', 'new-register', 'about', 'contact', 'data-explorer'];
    return (validPages.includes(saved || '') ? saved : 'dashboard') as any;
  });
  const [registerTab, setRegisterTab] = useState<'site' | 'user'>('site');

  useEffect(() => {
    localStorage.setItem('gsmb_active_page', activePage);
  }, [activePage]);

  // Scroll to top on page transition to avoid glitchy jumping layout shifts
  useEffect(() => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }, [activePage]);

  // Registration form state
  const [regId, setRegId] = useState(() => generateUUID());
  const [regName, setRegName] = useState('');
  const [regType, setRegType] = useState<'MINE' | 'HARDWARE'>('MINE');
  const [regInventory, setRegInventory] = useState('0');
  const [regMaxCapacity, setRegMaxCapacity] = useState('100');
  const [regLat, setRegLat] = useState('7.8731');
  const [regLng, setRegLng] = useState('80.7718');
  const [regSubmitting, setRegSubmitting] = useState(false);
  const [regSuccess, setRegSuccess] = useState(false);
  const [regError, setRegError] = useState<string | null>(null);
  const [regUserNic, setRegUserNic] = useState('');

  // User registration form state
  const [userRegName, setUserRegName] = useState('');
  const [userRegNic, setUserRegNic] = useState('');
  const [userRegEmail, setUserRegEmail] = useState('');
  const [userRegPassword, setUserRegPassword] = useState('');
  const [userRegSubmitting, setUserRegSubmitting] = useState(false);
  const [userRegSuccess, setUserRegSuccess] = useState(false);
  const [userRegError, setUserRegError] = useState<string | null>(null);

  // Separated lists filter states for Dashboard
  const [activeTypeTab, setActiveTypeTab] = useState<'all' | 'mine' | 'hardware'>('all');

  // Custom independent search bar state for EACH tab
  const [generalSearch, setGeneralSearch] = useState<string>('');
  const [minesSearch, setMinesSearch] = useState<string>('');
  const [hardwareSearch, setHardwareSearch] = useState<string>('');

  // Dropdown global filters
  const [selectedRegion, setSelectedRegion] = useState<string>('all');
  const [selectedRisk, setSelectedRisk] = useState<string>('all');

  // Pagination states for Mines & Hardwares table
  const [locationsCurrentPage, setLocationsCurrentPage] = useState<number>(1);

  // Reset pagination on filter or search changes
  useEffect(() => {
    setLocationsCurrentPage(1);
  }, [activeTypeTab, generalSearch, minesSearch, hardwareSearch, selectedRegion, selectedRisk]);

  // ── Data Explorer State ──────────────────────────────────────────
  const [explorerTab, setExplorerTab] = useState<'users' | 'mines' | 'hardwares' | 'trucks'>('users');
  const [explorerSearch, setExplorerSearch] = useState<string>('');
  const [explorerPage, setExplorerPage] = useState<number>(1);
  const EXPLORER_PAGE_SIZE = 20;

  // Raw data for the explorer (trucks not yet fetched in main loadData)
  const [rawTrucks, setRawTrucks] = useState<any[]>([]);
  const [rawMinesData, setRawMinesData] = useState<any[]>([]);
  const [rawHardwaresData, setRawHardwaresData] = useState<any[]>([]);

  // Popup state
  const [popupItem, setPopupItem] = useState<any>(null);
  const [popupType, setPopupType] = useState<'user' | 'mine' | 'hardware' | 'truck' | null>(null);
  // User popup sub-tab
  const [userPopupTab, setUserPopupTab] = useState<'mines' | 'hardwares' | 'trucks'>('mines');
  // Sub-item popup (mine/hardware/truck inside user popup)
  const [subPopupItem, setSubPopupItem] = useState<any>(null);
  const [subPopupType, setSubPopupType] = useState<'mine' | 'hardware' | 'truck' | null>(null);
  const [mapPopup, setMapPopup] = useState<{ lat: number; lng: number; label: string } | null>(null);

  // Reset explorer page when tab or search changes
  useEffect(() => {
    setExplorerPage(1);
  }, [explorerTab, explorerSearch]);

  // Popup sub-search (for user popup subtables)
  const [popupSubSearch, setPopupSubSearch] = useState<string>('');
  // Copy feedback
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const handleCopyId = (id: string) => {
    navigator.clipboard.writeText(id).then(() => {
      setCopiedId(id);
      setTimeout(() => setCopiedId(null), 1800);
    });
  };

  // Helper: get owner name from dbUsers by user_id
  const getUserNameById = (userId: string | null | undefined): string => {
    if (!userId) return 'N/A';
    const u = dbUsers.find(u => u.user_id === userId || u.id === userId);
    return u ? (u.name || u.full_name || 'Unknown') : 'Unknown';
  };

  // Registry logs search states
  const [registrySearchQuery, setRegistrySearchQuery] = useState<string>('');
  const [registryStatusFilter, setRegistryStatusFilter] = useState<string>('all');

  // Feedback / support contact form state
  const [fbName, setFbName] = useState('');
  const [fbEmail, setFbEmail] = useState('');
  const [fbSubject, setFbSubject] = useState('General Query');
  const [fbMessage, setFbMessage] = useState('');
  const [fbLocationId, setFbLocationId] = useState('');
  const [fbSubmitted, setFbSubmitted] = useState(false);
  const [nodeSearchQuery, setNodeSearchQuery] = useState('');
  const [isNodeDropdownOpen, setIsNodeDropdownOpen] = useState(false);
  const [supportTickets, setSupportTickets] = useState<any[]>([
    {
      id: "GSMB-TK-8032",
      subject: "Overload alert check on Kurunegala Mine",
      message: "Truck WP-GA-4509 logged with 6.5 cubes load limit violation. Requesting manual inspector audit.",
      status: "INVESTIGATING",
      date: "2026-07-09",
    },
    {
      id: "GSMB-TK-7922",
      subject: "Unloaded mismatch coordinates flag",
      message: "Permit PM-20892 marked completed outside coordinates buffer region. Hardware Store informed.",
      status: "RESOLVED",
      date: "2026-07-08",
    }
  ]);

  // Fetch Supabase data with standard REST API
  const fetchSupabase = async (path: string) => {
    const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error(`Supabase request failed with status code ${response.status}`);
    }

    return response.json();
  };

  // Build 6 months rolling series for charts
  const buildMonthlyIncidentSeries = (permits: ProcessedPermit[]): IncidentSeries => {
    const now = new Date();
    const labels: string[] = [];
    const overloads: number[] = [];
    const frauds: number[] = [];

    // Past 6 months
    for (let i = 5; i >= 0; i -= 1) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const label = d.toLocaleDateString('en-US', { month: 'short' });
      labels.push(label);

      // Total counts for this month using local month & year
      const targetYear = d.getFullYear();
      const targetMonth = d.getMonth();

      const monthPermits = permits.filter((permit) => {
        const pDate = permit.transportDate;
        return pDate.getFullYear() === targetYear && pDate.getMonth() === targetMonth;
      });

      const overloadCount = monthPermits.filter((p) => p.volumeCubes > 5).length;
      const fraudCount = monthPermits.filter(
        (permit) =>
          permit.status === 'CANCELLED' ||
          (permit.status === 'COMPLETED' && permit.unloadLatitude === null) ||
          permit.gpsMismatch
      ).length;

      overloads.push(overloadCount);
      frauds.push(fraudCount);
    }

    return { labels, overloads, frauds };
  };

  // Convert raw permit schema into processed model
  const toProcessedPermit = (raw: RawPermit): ProcessedPermit => {
    return {
      id: raw.id,
      permitCode: raw.permit_code ?? 'N/A',
      truckNumber: raw.truck_number ?? 'Unknown',
      volumeCubes: Number(raw.volume_cubes ?? 0),
      transportDate: parseLocalDate(raw.transport_date),
      expirationDate: raw.expiration_date ? parseLocalDate(raw.expiration_date) : null,
      status: (raw.status ? raw.status.toUpperCase() : 'PENDING') as ProcessedPermit['status'],
      originLocationId: raw.origin_location_id,
      unloadLatitude: raw.unload_latitude,
      unloadLongitude: raw.unload_longitude,
      unloadedAt: raw.unloaded_at,
      gpsMismatch: false, // will be evaluated dynamically if needed
    };
  };

  // Build cohesive dashboard metrics, location records, and status outcomes
  const buildDashboardData = (locations: RawLocation[], permits: ProcessedPermit[]): DashboardData => {
    const permitsByLocation = new Map<string, ProcessedPermit[]>();

    permits.forEach((permit) => {
      if (!permit.originLocationId) return;
      if (!permitsByLocation.has(permit.originLocationId)) {
        permitsByLocation.set(permit.originLocationId, []);
      }
      permitsByLocation.get(permit.originLocationId)!.push(permit);
    });

    const records: ProcessedLocationRecord[] = locations.map((location) => {
      const locationPermits = permitsByLocation.get(location.id) || [];

      const overloadIncidents = locationPermits.filter((p) => p.volumeCubes > 5).length;
      const fraudIncidents = locationPermits.filter(
        (p) =>
          p.status === 'CANCELLED' ||
          (p.status === 'COMPLETED' && (p.unloadLatitude === null || p.unloadLongitude === null))
      ).length;

      const totalIncidents = overloadIncidents + fraudIncidents;
      const inventory = Number(location.inventory_cubes ?? 0);
      const typeStr = (location.location_type || '').toUpperCase();
      const isHardware = typeStr !== 'MINE' && typeStr !== 'MINE_OWNER';
      const maxCapFromDb = Number(location.max_capacity);
      const maxCapacity = (location.max_capacity !== null && location.max_capacity !== undefined && !isNaN(maxCapFromDb) && maxCapFromDb > 0)
        ? maxCapFromDb
        : (isHardware ? 20 : 100);

      let inventoryRiskPoints = 0;
      const isOverloaded = inventory > maxCapacity;

      if (isOverloaded) {
        inventoryRiskPoints = 2; // Maximum warning for overload
      } else if (isHardware) {
        // Hardware store: near maximum capacity (e.g. >= 75% of maxCapacity) is high risk. 
        // empty stores (0 cubes) are low/zero inventory risk points!
        if (inventory >= maxCapacity * 0.75) {
          inventoryRiskPoints = 2; // nearing capacity alert
        } else if (inventory >= maxCapacity * 0.5) {
          inventoryRiskPoints = 1; // buffer capacity warning
        } else {
          inventoryRiskPoints = 0; // safe
        }
      } else {
        // Mine: high warning / risk when it is near to empty (low remaining inventory)
        if (inventory <= 15) {
          inventoryRiskPoints = 2; // nearing empty alert
        } else if (inventory <= 30) {
          inventoryRiskPoints = 1; // moderately low warning
        } else {
          inventoryRiskPoints = 0; // safe (plenty of stock remaining)
        }
      }

      const incidentRiskPoints = totalIncidents >= 3 ? 2 : totalIncidents >= 1 ? 1 : 0;
      const riskScore = incidentRiskPoints + inventoryRiskPoints;

      const risk: 'low' | 'medium' | 'high' =
        (isOverloaded || inventoryRiskPoints === 2 || riskScore >= 2) ? 'high' : riskScore >= 1 ? 'medium' : 'low';

      // Sort location permits descending to find the latest
      const sortedPermits = [...locationPermits].sort(
        (a, b) => b.transportDate.getTime() - a.transportDate.getTime()
      );
      const latestPermit = sortedPermits[0];

      // Assemble detail timeline
      const timeline = [
        { label: 'Overload incidents', value: `${overloadIncidents} flagged` },
        { label: 'Fraud indicators', value: `${fraudIncidents} flags` },
        { label: 'Latest active permit', value: latestPermit ? latestPermit.permitCode : 'None' },
      ];

      // Generate clean location profile string
      const profileParts = [location.name, location.address, location.district]
        .filter(Boolean);
      const region = profileParts.length > 1 ? `${profileParts[1]}, ${profileParts[2] || 'Sri Lanka'}` : 'Sri Lanka Region';

      return {
        id: location.id,
        name: location.name ?? 'Unnamed Site',
        type: isHardware ? 'Hardware' : 'Mine',
        region: location.district || 'Unknown District',
        inventory,
        maxCapacity,
        incidents: totalIncidents,
        risk,
        isOverloaded,
        status:
          isOverloaded
            ? `OVERLOADED: current stock exceeds maximum capacity (${inventory} m³ / ${maxCapacity} m³)`
            : totalIncidents > 0
              ? `${overloadIncidents} overload(s), ${fraudIncidents} fraud indicator(s) found`
              : isHardware && inventory >= maxCapacity * 0.75
                ? `Store is near maximum capacity (${inventory} m³ / ${maxCapacity} m³)`
                : !isHardware && inventory <= 15
                  ? `Mine is near empty: high risk of service disruption (${inventory} m³ remaining)`
                  : '',
        coordinates: [
          Number(location.latitude ?? FALLBACK_CENTER[0]),
          Number(location.longitude ?? FALLBACK_CENTER[1]),
        ] as [number, number],
        permit: latestPermit?.permitCode ?? 'N/A',
        truck: latestPermit?.truckNumber ?? 'N/A',
        timeline,
        user_id: location.user_id,
        raw: location.raw,
      };
    });

    const activePermits = permits.filter((p) => p.status === 'ACTIVE').length;
    const overloadedLocations = records.filter((r) => r.isOverloaded).length;
    const permitOverloads = permits.filter((p) => p.status !== 'COMPLETED' && p.volumeCubes > 5).length;
    const totalOpenOverloads = permitOverloads + overloadedLocations;

    const fraudFlags = permits.filter(
      (p) =>
        p.status === 'CANCELLED' ||
        (p.status === 'COMPLETED' && (p.unloadLatitude === null || p.unloadLongitude === null))
    ).length;

    const metrics = [
      {
        label: 'Registered Users',
        value: dbUsers.length,
        note: 'Active regulatory accounts',
      },
      {
        label: 'Active Mines',
        value: rawMinesData.length,
        note: 'Monitored extraction sites',
      },
      {
        label: 'Hardware Stores',
        value: rawHardwaresData.length,
        note: 'Registered distribution depots',
      },
      {
        label: 'Logistics Trucks',
        value: rawTrucks.length,
        note: 'Tracked logistics vehicles',
      },
      {
        label: 'Open overloads',
        value: totalOpenOverloads,
        note: `${permitOverloads} permits & ${overloadedLocations} sites exceeded`,
      },
      {
        label: 'Fraud flags',
        value: fraudFlags,
        note: 'Anomalies and unscheduled cancel logs',
      },
      {
        label: 'Active permits',
        value: activePermits,
        note: `${permits.length} total transport logs`,
      },
    ];

    const statusCounts: StatusCounts = {
      Pending: permits.filter((p) => p.status === 'PENDING').length,
      Active: permits.filter((p) => p.status === 'ACTIVE').length,
      Completed: permits.filter((p) => p.status === 'COMPLETED').length,
      Cancelled: permits.filter((p) => p.status === 'CANCELLED').length,
    };

    const incidentSeries = buildMonthlyIncidentSeries(permits);

    return {
      generatedAt: new Date(),
      metrics,
      records,
      incidentSeries,
      statusCounts,
    };
  };

  const handleMetricClick = (index: number) => {
    if (index === 0) {
      setExplorerTab('users');
      setActivePage('data-explorer');
    } else if (index === 1) {
      setExplorerTab('mines');
      setActivePage('data-explorer');
    } else if (index === 2) {
      setExplorerTab('hardwares');
      setActivePage('data-explorer');
    } else if (index === 3) {
      setExplorerTab('trucks');
      setActivePage('data-explorer');
    } else if (index === 4) {
      setSelectedRisk('high');
      setActiveTypeTab('all');
      setGeneralSearch('');
    } else if (index === 5) {
      setActivePage('registry');
      setRegistryStatusFilter('all');
      setRegistrySearchQuery('CANCELLED');
      setTimeout(() => {
        window.scrollTo({ top: 0, behavior: 'smooth' });
      }, 100);
    } else if (index === 6) {
      setActivePage('registry');
      setRegistryStatusFilter('ACTIVE');
      setRegistrySearchQuery('');
      setTimeout(() => {
        window.scrollTo({ top: 0, behavior: 'smooth' });
      }, 100);
    }
  };

  const loadData = async (silent = false) => {
    if (silent) {
      setIsSyncing(true);
    } else {
      setLoading(true);
    }
    setError(null);
    try {
      const [rawMines, rawHardwares, rawMinePermits, rawHardwarePermits] = await Promise.all([
        fetchSupabase('mines?select=*'),
        fetchSupabase('hardwares?select=*'),
        fetchSupabase('mine_permits?select=permit_id,permit_code,truck_number_plate,no_of_cubes,started_date,expiry_date,status,mine_id,mine_unloads(unloaded_latitude,unloaded_longitude,unloaded_date,unloaded_time)'),
        fetchSupabase('hardware_permits?select=permit_id,permit_code,truck_number_plate,no_of_cubes,started_date,expiry_date,status,hardware_id,hardware_unloads(unloaded_latitude,unloaded_longitude,unloaded_date,unloaded_time)'),
      ]);

      // Store raw mines/hardwares for data explorer
      setRawMinesData(rawMines as any[]);
      setRawHardwaresData(rawHardwares as any[]);

      // Fetch trucks for data explorer
      let fetchedTrucks: any[] = [];
      try {
        fetchedTrucks = await fetchSupabase('trucks?select=*');
      } catch (err) {
        console.error('Failed to fetch trucks:', err);
      }
      setRawTrucks(fetchedTrucks);

      let fetchedUsers: any[] = [];
      try {
        fetchedUsers = await fetchSupabase('user_accounts?select=*');
      } catch (err) {
        console.error('Failed to fetch user_accounts:', err);
      }
      setDbUsers(fetchedUsers);

      try {
        const schemaInfo = await fetchSupabase('');
        setDbSchema(schemaInfo);
      } catch (errSchema) {
        console.error('Failed to fetch OpenAPI schema:', errSchema);
      }

      const collectedMineUserIds = (rawMines as any[]).map((m) => m.user_id).filter(Boolean);
      const collectedHardwareUserIds = (rawHardwares as any[]).map((h) => h.user_id).filter(Boolean);
      // Get unique values
      setDbMineUserIds(Array.from(new Set(collectedMineUserIds)));
      setDbHardwareUserIds(Array.from(new Set(collectedHardwareUserIds)));

      const minesList: RawLocation[] = (rawMines as any[]).map((m) => ({
        id: m.mine_id,
        name: m.mine_name,
        location_type: 'MINE',
        inventory_cubes: m.current_cubes !== null ? Number(m.current_cubes) : 0,
        latitude: m.latitude !== null ? Number(m.latitude) : null,
        longitude: m.longitude !== null ? Number(m.longitude) : null,
        max_capacity: m.maximum_cubes !== null ? Number(m.maximum_cubes) : 100,
        user_id: m.user_id,
        raw: m,
      }));

      const hardwaresList: RawLocation[] = (rawHardwares as any[]).map((h) => ({
        id: h.hardware_id,
        name: h.hardware_name,
        location_type: 'HARDWARE',
        inventory_cubes: h.current_cubes !== null ? Number(h.current_cubes) : 0,
        latitude: h.latitude !== null ? Number(h.latitude) : null,
        longitude: h.longitude !== null ? Number(h.longitude) : null,
        max_capacity: h.maximum_cubes !== null ? Number(h.maximum_cubes) : 20,
        user_id: h.user_id,
        raw: h,
      }));

      const rawLocations = [...minesList, ...hardwaresList];

      const minePermitsMapped = (rawMinePermits as any[]).map((p) => {
        const unload = Array.isArray(p.mine_unloads) ? p.mine_unloads[0] : p.mine_unloads;
        return {
          id: p.permit_id,
          permit_code: p.permit_code || 'N/A',
          truck_number: p.truck_number_plate || 'Unknown',
          volume_cubes: p.no_of_cubes !== null ? Number(p.no_of_cubes) : 0,
          transport_date: p.started_date,
          expiration_date: p.expiry_date,
          status: p.status,
          origin_location_id: p.mine_id,
          unload_latitude: unload && unload.unloaded_latitude !== null ? Number(unload.unloaded_latitude) : null,
          unload_longitude: unload && unload.unloaded_longitude !== null ? Number(unload.unloaded_longitude) : null,
          unloaded_at: unload && unload.unloaded_date && unload.unloaded_time ? `${unload.unloaded_date}T${unload.unloaded_time}` : null,
        };
      });

      const hardwarePermitsMapped = (rawHardwarePermits as any[]).map((p) => {
        const unload = Array.isArray(p.hardware_unloads) ? p.hardware_unloads[0] : p.hardware_unloads;
        return {
          id: p.permit_id,
          permit_code: p.permit_code || 'N/A',
          truck_number: p.truck_number_plate || 'Unknown',
          volume_cubes: p.no_of_cubes !== null ? Number(p.no_of_cubes) : 0,
          transport_date: p.started_date,
          expiration_date: p.expiry_date,
          status: p.status,
          origin_location_id: p.hardware_id,
          unload_latitude: unload && unload.unloaded_latitude !== null ? Number(unload.unloaded_latitude) : null,
          unload_longitude: unload && unload.unloaded_longitude !== null ? Number(unload.unloaded_longitude) : null,
          unloaded_at: unload && unload.unloaded_date && unload.unloaded_time ? `${unload.unloaded_date}T${unload.unloaded_time}` : null,
        };
      });

      const locationNameMap = new Map<string, string>();
      rawLocations.forEach((loc) => {
        if (loc.id && loc.name) {
          locationNameMap.set(loc.id, loc.name);
        }
      });

      const processedPermits = [...minePermitsMapped, ...hardwarePermitsMapped].map((p) => {
        const processed = toProcessedPermit(p as any);
        processed.originLocationName = locationNameMap.get(p.origin_location_id || '') || 'Unknown Site';
        return processed;
      });
      setAllRawPermits(processedPermits);

      const enrichedLocations = (rawLocations as RawLocation[]).map((loc) => {
        let district = 'Colombo';
        let address = 'Galle Road, Colombo 03';
        const latNum = Number(loc.latitude || 7.8731);
        const lngNum = Number(loc.longitude || 80.7718);

        if (latNum > 8.1) {
          district = 'Anuradhapura';
          address = 'Anuradhapura City limits';
        } else if (latNum > 7.8 && lngNum < 80.0) {
          district = 'Puttalam';
          address = 'Mundel Road, Puttalam';
        } else if (latNum > 7.4 && latNum <= 7.8 && lngNum < 80.5) {
          district = 'Kurunegala';
          address = 'Dambulla Road, Kurunegala';
        } else if (latNum > 7.1 && latNum <= 7.4 && lngNum > 80.4) {
          district = 'Kandy';
          address = 'William Gopallawa Mawatha, Kandy';
        } else if (latNum > 6.8 && latNum <= 7.15 && lngNum < 80.1) {
          district = 'Gampaha';
          address = 'Negombo Road, Kurana';
        } else if (latNum < 6.5) {
          district = 'Galle';
          address = 'Galle Highway Exit';
        }
        return {
          ...loc,
          district,
          address,
        };
      });

      const dashboardPayload = buildDashboardData(enrichedLocations, processedPermits);
      setData(dashboardPayload);

      // Start with no specific active record selected so map displays whole country
      setActiveRecordId(null);
    } catch (err: any) {
      console.error('Error fetching oversight data:', err);
      setError(err.message || 'Oversight database connections failed.');
    } finally {
      setLoading(false);
      setIsSyncing(false);
    }
  };

  useEffect(() => {
    loadData();
    const interval = setInterval(() => {
      loadData(true);
    }, 300000);
    return () => clearInterval(interval);
  }, []);

  // Compute distinct regions from current dataset
  const regionsList = useMemo(() => {
    if (!data.records) return [];
    const set = new Set(data.records.map((r) => r.region).filter(Boolean));
    return Array.from(set).sort();
  }, [data.records]);

  // Filtered lists for the sub-tabs in dashboard
  const filteredRecords = useMemo(() => {
    return data.records.filter((record) => {
      // 1. Tab type selection
      if (activeTypeTab === 'mine' && record.type !== 'Mine') return false;
      if (activeTypeTab === 'hardware' && record.type !== 'Hardware') return false;

      // 2. Select appropriate search query
      let query = '';
      if (activeTypeTab === 'all') query = generalSearch.trim().toLowerCase();
      else if (activeTypeTab === 'mine') query = minesSearch.trim().toLowerCase();
      else if (activeTypeTab === 'hardware') query = hardwareSearch.trim().toLowerCase();

      const matchesQuery =
        !query ||
        [record.name, record.id, record.type, record.region, record.permit, record.truck]
          .join(' ')
          .toLowerCase()
          .includes(query);

      // 3. District Region filter
      const matchesRegion = selectedRegion === 'all' || record.region === selectedRegion;

      // 4. Risk Level filter
      const rank = { low: 1, medium: 2, high: 3 }[record.risk];
      const matchesRisk =
        selectedRisk === 'all' ||
        (selectedRisk === 'high' && record.risk === 'high') ||
        (selectedRisk === 'medium' && rank >= 2) ||
        (selectedRisk === 'low' && record.risk === 'low');

      return matchesQuery && matchesRegion && matchesRisk;
    });
  }, [data.records, activeTypeTab, generalSearch, minesSearch, hardwareSearch, selectedRegion, selectedRisk]);

  // Paginate filtered records
  const totalPages = Math.ceil(filteredRecords.length / 5);
  const paginatedRecords = useMemo(() => {
    const startIndex = (locationsCurrentPage - 1) * 5;
    return filteredRecords.slice(startIndex, startIndex + 5);
  }, [filteredRecords, locationsCurrentPage]);

  // Active selected record profile details
  const activeRecord = useMemo(() => {
    return (
      filteredRecords.find((r) => r.id === activeRecordId) ||
      filteredRecords[0] ||
      null
    );
  }, [filteredRecords, activeRecordId]);

  // Helper to extract owner Name and NIC from dbUsers state or raw properties
  const getRecordOwnerInfo = (record: ProcessedLocationRecord | null) => {
    if (!record) return { name: 'N/A', nic: 'N/A' };

    // 1. Try to find in dbUsers state
    if (record.user_id && dbUsers && dbUsers.length > 0) {
      const user = dbUsers.find(
        u => u.id === record.user_id || u.user_id === record.user_id || u.owner_id === record.user_id
      );
      if (user) {
        const name = user.name || user.full_name || user.username || user.owner_name || user.owner || '';
        const nic = user.nic || user.nic_number || user.national_id || user.owner_nic || '';
        if (name || nic) {
          return { name: name || 'N/A', nic: nic || 'N/A' };
        }
      }
    }

    // 2. Try to find in raw properties of the record (from db select=*)
    const raw: any = (record as any).raw || {};
    const name = raw.owner_name || raw.owner || raw.operator || raw.operator_name || raw.user_name || '';
    const nic = raw.nic || raw.nic_number || raw.national_id || raw.owner_nic || '';

    return {
      name: name || 'N/A',
      nic: nic || 'N/A'
    };
  };

  // Helper to dynamically retrieve or generate user_id from the database
  const getDynamicUserId = (type?: 'MINE' | 'HARDWARE') => {
    // 1. Try to get from active locations of this type
    if (type === 'MINE' && dbMineUserIds && dbMineUserIds.length > 0) {
      return dbMineUserIds[0];
    }
    if (type === 'HARDWARE' && dbHardwareUserIds && dbHardwareUserIds.length > 0) {
      return dbHardwareUserIds[0];
    }
    // 2. Try to get any user from dbUsers list matching the type role if possible
    if (dbUsers && dbUsers.length > 0) {
      const matchedUser = dbUsers.find(u => {
        const role = String(u.role || u.type || '').toUpperCase();
        return type === 'MINE' ? role.includes('MINE') : role.includes('HARDWARE');
      });
      const user = matchedUser || dbUsers[0];
      return user.id || user.user_id || user.owner_id || generateUUID();
    }
    // 3. Fallback to any active location user_id
    if (dbMineUserIds && dbMineUserIds.length > 0) return dbMineUserIds[0];
    if (dbHardwareUserIds && dbHardwareUserIds.length > 0) return dbHardwareUserIds[0];

    // 4. Generate dynamic random UUID
    return generateUUID();
  };

  // Filtered permit logs for the dedicated Registry Search page
  const filteredRegistryPermits = useMemo(() => {
    return allRawPermits.filter((permit) => {
      const query = registrySearchQuery.trim().toLowerCase();
      const matchesQuery =
        !query ||
        [permit.permitCode, permit.truckNumber, permit.id, permit.originLocationName || '']
          .join(' ')
          .toLowerCase()
          .includes(query);

      const matchesStatus =
        registryStatusFilter === 'all' ||
        permit.status === (registryStatusFilter.toUpperCase() as any);

      return matchesQuery && matchesStatus;
    });
  }, [allRawPermits, registrySearchQuery, registryStatusFilter]);

  // Handle registering a new administrative node (Mine/Hardware store)
  const handleRegisterSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!regName.trim() || !regId.trim() || !regUserNic.trim()) {
      setRegError('All fields, including Owner NIC, are required.');
      return;
    }

    setRegSubmitting(true);
    setRegError(null);
    setRegSuccess(false);

    try {
      // Find the user by NIC
      const matchedUser = dbUsers.find(
        u => String(u.nic || u.nic_number || u.owner_nic || '').trim().toLowerCase() === regUserNic.trim().toLowerCase()
      );
      if (!matchedUser) {
        throw new Error(`No user account found with NIC "${regUserNic}". Please register the user account first.`);
      }

      const isUuid = (str: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str);
      const targetId = isUuid(regId.trim()) ? regId.trim() : undefined;

      const path = regType === 'MINE' ? 'mines' : 'hardwares';
      const payload = regType === 'MINE' ? {
        ...(targetId ? { mine_id: targetId } : {}),
        mine_name: regName.trim(),
        current_cubes: Number(regInventory),
        maximum_cubes: Number(regMaxCapacity),
        latitude: Number(regLat),
        longitude: Number(regLng),
        user_id: matchedUser.user_id || matchedUser.id || generateUUID(),
      } : {
        ...(targetId ? { hardware_id: targetId } : {}),
        hardware_name: regName.trim(),
        current_cubes: Number(regInventory),
        maximum_cubes: Number(regMaxCapacity),
        latitude: Number(regLat),
        longitude: Number(regLng),
        user_id: matchedUser.user_id || matchedUser.id || generateUUID(),
      };

      const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
        method: 'POST',
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const errText = await response.text();
        let parsedMessage = '';
        try {
          const parsed = JSON.parse(errText);
          parsedMessage = parsed.message || parsed.details || errText;
        } catch {
          parsedMessage = errText;
        }
        throw new Error(parsedMessage || `Supabase query returned ${response.status}`);
      }

      setRegSuccess(true);
      // Setup next defaults
      setRegId(generateUUID());
      setRegName('');
      setRegInventory('0');
      setRegUserNic('');
      // Refresh telemetry dashboard dataset
      await loadData();
    } catch (err: any) {
      console.error('Failed to insert new node:', err);
      setRegError(err.message || 'Oversight telemetry register transaction aborted.');
    } finally {
      setRegSubmitting(false);
    }
  };

  // Handle contact feedback submissions
  const handleFeedbackSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!fbName || !fbEmail || !fbMessage) return;

    const ticketId = `GSMB-TK-${Math.floor(1000 + Math.random() * 9000)}`;
    const newTicket = {
      id: ticketId,
      subject: fbSubject,
      message: fbMessage,
      status: "OPEN",
      date: getLocalDateString(new Date()),
    };

    setSupportTickets([newTicket, ...supportTickets]);
    setFbSubmitted(true);

    try {
      // Find selected location or fallback to first one
      const targetLocId = fbLocationId || (data.records[0]?.id || null);

      if (targetLocId) {
        // Find if target is Mine or Hardware
        const targetRecord = data.records.find(r => r.id === targetLocId);
        const isMine = targetRecord ? targetRecord.type === 'Mine' : true;

        // Build permit payload to insert as a violation
        const isOverload = fbSubject === 'Overloading Report';
        const isMismatch = fbSubject === 'Coordinate Mismatch Alert' || fbSubject === 'Illegal Mining Site';

        const letter = String.fromCharCode(65 + Math.floor(Math.random() * 26));
        const truckPlate = `WP - G${letter} ${Math.floor(1000 + Math.random() * 9000)}`;

        // Pre-insert/upsert truck to satisfy foreign key constraints
        try {
          await fetch(`${SUPABASE_URL}/rest/v1/trucks`, {
            method: 'POST',
            headers: {
              apikey: SUPABASE_ANON_KEY,
              Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
              'Content-Type': 'application/json',
              'Prefer': 'resolution=merge-duplicates',
            },
            body: JSON.stringify({
              number_plate: truckPlate,
              capacity: isOverload ? 5.0 : 10.0,
              user_id: isMine ? getDynamicUserId('MINE') : getDynamicUserId('HARDWARE'),
            }),
          });
        } catch (truckErr) {
          console.error('Failed to insert/upsert truck:', truckErr);
        }

        const permitCode = `P-${Math.floor(100000 + Math.random() * 900000)}`;
        const startedDate = getLocalDateString(new Date());
        const expiryDate = getLocalDateString(new Date(Date.now() + 14 * 24 * 3600 * 1000));
        const status = isMismatch ? 'CANCELLED' : 'ACTIVE';
        const volumeCubes = isOverload ? 6.8 : 3.5;

        const path = isMine ? 'mine_permits' : 'hardware_permits';
        const payload = isMine ? {
          permit_code: permitCode,
          truck_number_plate: truckPlate,
          no_of_cubes: volumeCubes,
          started_date: startedDate,
          expiry_date: expiryDate,
          status: status,
          mine_id: targetLocId,
        } : {
          permit_code: permitCode,
          truck_number_plate: truckPlate,
          no_of_cubes: volumeCubes,
          started_date: startedDate,
          expiry_date: expiryDate,
          status: status,
          hardware_id: targetLocId,
        };

        const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: JSON.stringify(payload),
        });

        if (response.ok) {
          const insertedPermits = await response.json();
          const permitId = insertedPermits[0]?.permit_id;
          if (permitId && !isMismatch) {
            const unloadPath = isMine ? 'mine_unloads' : 'hardware_unloads';
            const now = new Date();
            const unloadedDate = getLocalDateString(now);
            const unloadedTime = now.toTimeString().split(' ')[0];

            await fetch(`${SUPABASE_URL}/rest/v1/${unloadPath}`, {
              method: 'POST',
              headers: {
                apikey: SUPABASE_ANON_KEY,
                Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                permit_id: permitId,
                unloaded_latitude: 6.9271,
                unloaded_longitude: 80.7718,
                photo_url: "https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?auto=format&fit=crop&w=600&q=80",
                unloaded_date: unloadedDate,
                unloaded_time: unloadedTime,
              }),
            });
          }
          // Re-load the database data so everything is synchronized
          await loadData();
        } else {
          console.warn('Failed to insert permit into Supabase', await response.text());
        }
      }
    } catch (err) {
      console.error('Error recording incident permit:', err);
    }

    setTimeout(() => {
      if (authUser) {
        setFbName(authUser.user_metadata?.full_name || authUser.name || authUser.email?.split('@')[0] || 'Administrator');
        setFbEmail(authUser.email || '');
      } else {
        setFbName('');
        setFbEmail('');
      }
      setFbMessage('');
      setFbSubmitted(false);
    }, 5000);
  };

  // Export report down to client as PDF
  const handleExport = () => {
    const doc = new jsPDF();

    // Add custom header/background
    doc.setFillColor(243, 244, 246); // gray-100
    doc.rect(0, 0, 210, 40, 'F');

    // Title
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(20);
    doc.setTextColor(30, 41, 59); // slate-800
    doc.text('GSMB GeoTrust Compliance Report', 14, 23);

    // Subtitle
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(10);
    doc.setTextColor(71, 85, 105); // slate-600
    doc.text('GSMB Operational Tracking, Permit Verification & Compliance Telemetry', 14, 30);

    // Metadata block
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(9);
    doc.setTextColor(15, 23, 42); // slate-900
    doc.text(`Generated on:`, 14, 50);
    doc.setFont('helvetica', 'normal');
    doc.text(`${liveDateTime.toLocaleDateString()} ${liveDateTime.toLocaleTimeString()}`, 42, 50);

    doc.setFont('helvetica', 'bold');
    doc.text(`Exporter:`, 14, 56);
    doc.setFont('helvetica', 'normal');
    doc.text(`dtshoppr@gmail.com`, 42, 56);

    doc.setFont('helvetica', 'bold');
    doc.text(`Active Filter:`, 14, 62);
    doc.setFont('helvetica', 'normal');
    doc.text(`${activeTypeTab.toUpperCase()} SITES (District: ${selectedRegion}, Risk: ${selectedRisk})`, 42, 62);

    // Summary Compliance Metrics Section
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(13);
    doc.setTextColor(15, 23, 42);
    doc.text('SUMMARY COMPLIANCE METRICS', 14, 75);

    doc.setDrawColor(226, 232, 240); // slate-200
    doc.setLineWidth(0.5);
    doc.line(14, 78, 196, 78);

    // Draw 4 metrics boxes (or details)
    let myY = 86;
    data.metrics.forEach((metric) => {
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(10);
      doc.setTextColor(51, 65, 85);
      doc.text(`${metric.label}:`, 16, myY);

      doc.setFont('helvetica', 'normal');
      doc.setFontSize(10);
      doc.setTextColor(15, 23, 42);
      doc.text(`${metric.value}`, 75, myY);

      doc.setFont('helvetica', 'italic');
      doc.setFontSize(9);
      doc.setTextColor(100, 116, 139);
      doc.text(`(${metric.note})`, 105, myY);

      myY += 8;
    });

    // Save PDF
    const year = liveDateTime.getFullYear();
    const month = String(liveDateTime.getMonth() + 1).padStart(2, '0');
    const day = String(liveDateTime.getDate()).padStart(2, '0');
    const filename = `gsmb-operational-report-${year}-${month}-${day}.pdf`;
    doc.save(filename);
  };



  // ── Sub-render Functions ──────────────────────────────────────────
  const renderAuth = () => {
    return (
      <div className={`min-h-screen flex items-center justify-center p-4 relative overflow-hidden font-sans selection:bg-indigo-500 selection:text-white ${theme === 'light' ? 'bg-neutral-50' : 'bg-neutral-950'}`}>
        {/* Premium Fine Bento Grid Background Overlay */}
        <div className="fixed inset-0 pointer-events-none z-0">
          <div className={`absolute inset-0 transition-colors duration-300 ${theme === 'light' ? 'bg-neutral-50' : 'bg-[#0a0a0a]'}`}></div>
          <div
            className={`absolute inset-0 transition-colors duration-300 ${theme === 'light'
              ? 'bg-[linear-gradient(rgba(0,0,0,0.02)_1px,transparent_1px),linear-gradient(90deg,rgba(0,0,0,0.02)_1px,transparent_1px)]'
              : 'bg-[linear-gradient(rgba(255,255,255,0.012)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.012)_1px,transparent_1px)]'
              } bg-[size:44px_44px]`}
            style={{ maskImage: 'radial-gradient(ellipse at center, black, transparent 95%)' }}
          ></div>
          <div className={`absolute top-[-20%] left-[-10%] w-[60%] h-[60%] rounded-full blur-[135px] ${theme === 'light' ? 'bg-indigo-500/[0.02]' : 'bg-indigo-500/[0.03]'}`}></div>
          <div className={`absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full blur-[135px] ${theme === 'light' ? 'bg-indigo-500/[0.01]' : 'bg-indigo-500/[0.02]'}`}></div>
        </div>

        <div className={theme === 'light' ? 'relative z-10 w-full max-w-lg bg-white/80 backdrop-blur-2xl border border-neutral-200/80 p-10 sm:p-12 rounded-[32px] shadow-[0_30px_70px_-15px_rgba(0,0,0,0.1)] flex flex-col gap-8 transition-all duration-500 hover:border-indigo-500/30' : 'relative z-10 w-full max-w-lg bg-neutral-900/60 backdrop-blur-2xl border border-neutral-800/60 p-10 sm:p-12 rounded-[32px] shadow-[0_30px_70px_-15px_rgba(0,0,0,0.8)] flex flex-col gap-8 transition-all duration-500 hover:border-indigo-500/30'}>
          <div className="flex items-center gap-4 justify-center">
            <div className="w-12 h-12 bg-indigo-600 rounded-2xl flex items-center justify-center shadow-xl shadow-indigo-500/35 transform hover:scale-105 transition-transform duration-300">
              <ShieldAlert className="w-6 h-6 text-white" />
            </div>
            <div className="text-left">
              <span className={`text-2xl font-extrabold tracking-tight uppercase block ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>GSMB GeoTrust</span>
              <p className="text-[11px] text-indigo-400 font-mono tracking-widest uppercase font-bold">Oversight Portal</p>
            </div>
          </div>

          {inviteToken ? (
            // Invitation / Password setup screen
            <form onSubmit={handleSetPasswordSubmit} className="flex flex-col gap-4">
              <div className="text-center mb-2">
                <h2 className={`text-xl font-black ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Create New Password</h2>
                <p className={`text-xs mt-1 leading-relaxed ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
                  Enter a secure password for your invited administrator account.
                </p>
              </div>

              {authError && (
                <div className="p-3.5 bg-rose-500/10 border border-rose-500/20 rounded-xl text-xs text-rose-400 font-semibold flex gap-2 items-start">
                  <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
                  <span>{authError}</span>
                </div>
              )}

              <div className="flex flex-col gap-1.5">
                <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>New Password</label>
                <input
                  required
                  type="password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  className={`rounded-xl p-3.5 text-sm focus:outline-none focus:ring-1 font-mono transition-colors ${theme === 'light' ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500' : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'}`}
                  placeholder="••••••••"
                />
              </div>

              <div className="flex flex-col gap-1.5">
                <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Confirm Password</label>
                <input
                  required
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  className={`rounded-xl p-3.5 text-sm focus:outline-none focus:ring-1 font-mono transition-colors ${theme === 'light' ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500' : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'}`}
                  placeholder="••••••••"
                />
              </div>

              <button
                type="submit"
                disabled={authLoading}
                className="w-full mt-4 py-3 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white rounded-xl text-sm font-bold transition-all cursor-pointer shadow-md flex items-center justify-center gap-2 shadow-indigo-600/25"
              >
                {authLoading ? (
                  <RotateCw className="w-4 h-4 animate-spin" />
                ) : (
                  'Set Password & Log In'
                )}
              </button>
            </form>
          ) : (
            // Login screen
            <form onSubmit={handleLoginSubmit} className="flex flex-col gap-4">
              <div className="text-center mb-2">
                <h2 className={`text-xl font-black ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Administrator Sign In</h2>
                <p className={`text-xs mt-1 leading-relaxed ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
                  Provide credentials linked to your authorized profile.
                </p>
              </div>

              {setPasswordSuccess && (
                <div className="p-3.5 bg-emerald-500/10 border border-emerald-500/20 rounded-xl text-xs text-emerald-400 font-semibold flex gap-2 items-start">
                  <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Password updated successfully. Please sign in below using your credentials.</span>
                </div>
              )}

              {authError && (
                <div className="p-3.5 bg-rose-500/10 border border-rose-500/20 rounded-xl text-xs text-rose-400 font-semibold flex gap-2 items-start">
                  <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
                  <span>{authError}</span>
                </div>
              )}

              <div className="flex flex-col gap-2">
                <label className={`text-xs font-bold uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Email Address</label>
                <input
                  required
                  type="email"
                  value={authEmail}
                  onChange={(e) => setAuthEmail(e.target.value)}
                  className={`rounded-2xl p-4 text-base focus:outline-none focus:ring-2 font-sans transition-colors ${theme === 'light' ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500' : 'bg-neutral-950/80 border-neutral-800 text-neutral-200 focus:ring-indigo-500/50'}`}
                  placeholder="admin@gsmb.gov.lk"
                />
              </div>

              <div className="flex flex-col gap-2">
                <label className={`text-xs font-bold uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Password</label>
                <input
                  required
                  type="password"
                  value={authPassword}
                  onChange={(e) => setAuthPassword(e.target.value)}
                  className={`rounded-2xl p-4 text-base focus:outline-none focus:ring-2 font-mono transition-colors ${theme === 'light' ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500' : 'bg-neutral-950/80 border-neutral-800 text-neutral-200 focus:ring-indigo-500/50'}`}
                  placeholder="••••••••"
                />
              </div>

              <button
                type="submit"
                disabled={authLoading}
                className="w-full mt-4 py-4 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white rounded-2xl text-base font-bold transition-all duration-300 cursor-pointer shadow-lg flex items-center justify-center gap-2 shadow-indigo-600/35 transform hover:-translate-y-0.5 active:translate-y-0"
              >
                {authLoading ? (
                  <RotateCw className="w-5 h-5 animate-spin" />
                ) : (
                  'Sign In to Dashboard'
                )}
              </button>
            </form>
          )}

          <div className={`text-center text-[10px] mt-2 font-mono ${theme === 'light' ? 'text-neutral-400' : 'text-neutral-500'}`}>
            AUTHORIZED TELEMETRY SYSTEM • SECURED VIA SUPABASE AUTH
          </div>
        </div>
      </div>
    );
  };

  const renderDashboard = () => {
    return (
      <div className="flex flex-col gap-6 w-full">
        {/* Redesigned Sleek Top Bar (replacing the giant hero card) */}
        <div className={`rounded-3xl p-6 relative overflow-hidden transition-all duration-300 border flex flex-col md:flex-row justify-between items-start md:items-center gap-6 ${theme === 'light'
          ? 'bg-white border-neutral-200 shadow-md'
          : 'bg-neutral-900/60 backdrop-blur-xl border-neutral-800 shadow-2xl'
          }`}>
          <div className="absolute right-[-20px] bottom-[-20px] w-48 h-48 bg-indigo-500/[0.02] rounded-full blur-2xl pointer-events-none"></div>

          <div className="flex flex-col gap-2 z-10">
            <span className="px-3.5 py-1 bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 text-[10px] font-black rounded-full border border-indigo-500/20 uppercase tracking-widest w-max">
              ADMINISTRATIVE COMPLIANCE & SAFETY PORTAL
            </span>
            <h1 className={`text-2xl lg:text-3xl font-black tracking-tight leading-tight mt-1 transition-colors duration-300 ${theme === 'light' ? 'text-neutral-900' : 'text-white'
              }`}>
              Sri Lanka Mineral Telemetry & Verification
            </h1>
            <p className={`text-xs leading-relaxed max-w-xl transition-colors duration-300 ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'
              }`}>
              Review live permit overloads, transport hotspots, and fraud signals across mining depots and dealers in real-time.
            </p>
          </div>

          {/* Date & Time Lockscreen Widget */}
          <div className="flex flex-col items-start md:items-end select-none shrink-0 gap-1 text-left md:text-right z-10">
            <div className="leading-none flex items-baseline w-full justify-start md:justify-end">
              <span className={`text-5xl lg:text-6xl font-black tracking-tight font-mono transition-colors duration-300 ${theme === 'light' ? 'text-neutral-900' : 'text-white'
                }`}>
                {liveDateTime.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit', hour12: false })}
              </span>
              <span className={`text-base font-extrabold tracking-widest font-mono uppercase animate-pulse shrink-0 ml-1.5 ${theme === 'light' ? 'text-indigo-600' : 'text-indigo-400'
                }`}>
                :{liveDateTime.toLocaleTimeString(undefined, { second: '2-digit' })}
              </span>
              <span className={`text-[11px] font-black uppercase ml-1.5 ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>
                {liveDateTime.toLocaleTimeString(undefined, { hour: '2-digit', hour12: true }).slice(-2)}
              </span>
            </div>
            <div className="flex items-center justify-between w-full border-t border-neutral-300/40 dark:border-neutral-700/30 pt-1.5">
              <Calendar className="w-4 h-4 text-indigo-500 dark:text-indigo-400 shrink-0" />
              <span className={`text-sm font-black uppercase tracking-wider font-mono transition-colors duration-300 ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'
                }`}>
                {liveDateTime.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })}
              </span>
            </div>
          </div>
        </div>

        {/* Dashboard Metrics Bento Grid */}
        <section className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {data.metrics.map((metric, i) => {
            const boxStyle = [
              {
                // Registered Users (Indigo Gradient)
                classes: theme === 'light'
                  ? 'bg-gradient-to-br from-indigo-500 to-indigo-700 text-white border-indigo-600 hover:shadow-lg hover:shadow-indigo-500/20'
                  : 'bg-gradient-to-br from-indigo-950/80 to-indigo-900/40 border-indigo-500/30 text-white shadow-xl shadow-indigo-950/20',
                iconClass: theme === 'light' ? 'text-white' : 'text-indigo-400',
                labelClass: theme === 'light' ? 'text-indigo-100 font-extrabold' : 'text-indigo-300 font-extrabold',
                valueClass: 'text-white font-black',
                noteClass: theme === 'light' ? 'text-indigo-100/80 font-medium' : 'text-indigo-400/80 font-medium',
              },
              {
                // Active Mines (Emerald Gradient)
                classes: theme === 'light'
                  ? 'bg-gradient-to-br from-emerald-500 to-emerald-700 text-white border-emerald-600 hover:shadow-lg hover:shadow-emerald-500/20'
                  : 'bg-gradient-to-br from-emerald-950/80 to-emerald-900/40 border-emerald-500/30 text-white shadow-xl shadow-emerald-950/20',
                iconClass: theme === 'light' ? 'text-white' : 'text-emerald-400',
                labelClass: theme === 'light' ? 'text-emerald-100 font-extrabold' : 'text-emerald-300 font-extrabold',
                valueClass: 'text-white font-black',
                noteClass: theme === 'light' ? 'text-emerald-100/80 font-medium' : 'text-emerald-400/80 font-medium',
              },
              {
                // Hardware Stores (Sky Gradient)
                classes: theme === 'light'
                  ? 'bg-gradient-to-br from-sky-500 to-blue-600 text-white border-sky-600 hover:shadow-lg hover:shadow-sky-500/20'
                  : 'bg-gradient-to-br from-sky-950/80 to-blue-950/40 border-sky-500/30 text-white shadow-xl shadow-sky-950/20',
                iconClass: theme === 'light' ? 'text-white' : 'text-sky-400',
                labelClass: theme === 'light' ? 'text-sky-100 font-extrabold' : 'text-sky-300 font-extrabold',
                valueClass: 'text-white font-black',
                noteClass: theme === 'light' ? 'text-sky-100/80 font-medium' : 'text-sky-400/80 font-medium',
              },
              {
                // Logistics Trucks (Amber Gradient)
                classes: theme === 'light'
                  ? 'bg-gradient-to-br from-amber-500 to-amber-700 text-white border-amber-600 hover:shadow-lg hover:shadow-amber-500/20'
                  : 'bg-gradient-to-br from-amber-950/80 to-amber-900/40 border-amber-500/30 text-white shadow-xl shadow-amber-950/20',
                iconClass: theme === 'light' ? 'text-white' : 'text-amber-400',
                labelClass: theme === 'light' ? 'text-amber-100 font-extrabold' : 'text-amber-300 font-extrabold',
                valueClass: 'text-white font-black',
                noteClass: theme === 'light' ? 'text-amber-100/80 font-medium' : 'text-amber-400/80 font-medium',
              },
              {
                // Open overloads (Rose Gradient)
                classes: theme === 'light'
                  ? 'bg-gradient-to-br from-rose-500 to-red-600 text-white border-rose-600 hover:shadow-lg hover:shadow-rose-500/20'
                  : 'bg-gradient-to-br from-rose-950/80 to-red-950/40 border-rose-500/30 text-white shadow-xl shadow-rose-950/20',
                iconClass: theme === 'light' ? 'text-white' : 'text-rose-400',
                labelClass: theme === 'light' ? 'text-rose-100 font-extrabold' : 'text-rose-300 font-extrabold',
                valueClass: 'text-white font-black',
                noteClass: theme === 'light' ? 'text-rose-100/80 font-medium' : 'text-rose-400/80 font-medium',
              },
              {
                // Fraud flags (Purple Gradient)
                classes: theme === 'light'
                  ? 'bg-gradient-to-br from-purple-500 to-fuchsia-600 text-white border-purple-600 hover:shadow-lg hover:shadow-purple-500/20'
                  : 'bg-gradient-to-br from-purple-950/80 to-fuchsia-950/40 border-purple-500/30 text-white shadow-xl shadow-purple-950/20',
                iconClass: theme === 'light' ? 'text-white' : 'text-purple-400',
                labelClass: theme === 'light' ? 'text-purple-100 font-extrabold' : 'text-purple-300 font-extrabold',
                valueClass: 'text-white font-black',
                noteClass: theme === 'light' ? 'text-purple-100/80 font-medium' : 'text-purple-400/80 font-medium',
              },
              {
                // Active permits (Teal Gradient)
                classes: theme === 'light'
                  ? 'bg-gradient-to-br from-teal-500 to-cyan-600 text-white border-teal-600 hover:shadow-lg hover:shadow-teal-500/20'
                  : 'bg-gradient-to-br from-teal-950/80 to-cyan-950/40 border-teal-500/30 text-white shadow-xl shadow-teal-950/20',
                iconClass: theme === 'light' ? 'text-white' : 'text-teal-400',
                labelClass: theme === 'light' ? 'text-teal-100 font-extrabold' : 'text-teal-300 font-extrabold',
                valueClass: 'text-white font-black',
                noteClass: theme === 'light' ? 'text-teal-100/80 font-medium' : 'text-teal-400/80 font-medium',
              }
            ][i] || {
              classes: 'bg-neutral-900 border-neutral-800 text-white',
              iconClass: 'text-white',
              labelClass: 'text-neutral-300',
              valueClass: 'text-white',
              noteClass: 'text-neutral-400',
            };

            return (
              <button
                key={i}
                onClick={() => handleMetricClick(i)}
                className={`text-left rounded-[28px] p-7 flex flex-col justify-between h-[160px] border relative overflow-hidden group cursor-pointer active:scale-[0.98] modern-grid-card ${boxStyle.classes}`}
              >
                <div className="absolute right-4 top-4 opacity-15 group-hover:opacity-30 group-hover:scale-110 transition-all duration-300">
                  {i === 0 && <Users className={`w-14 h-14 ${boxStyle.iconClass}`} />}
                  {i === 1 && <HardHat className={`w-14 h-14 ${boxStyle.iconClass}`} />}
                  {i === 2 && <Building2 className={`w-14 h-14 ${boxStyle.iconClass}`} />}
                  {i === 3 && <Truck className={`w-14 h-14 ${boxStyle.iconClass}`} />}
                  {i === 4 && <AlertTriangle className={`w-14 h-14 ${boxStyle.iconClass}`} />}
                  {i === 5 && <ShieldAlert className={`w-14 h-14 ${boxStyle.iconClass}`} />}
                  {i === 6 && <FileText className={`w-14 h-14 ${boxStyle.iconClass}`} />}
                </div>
                <span className={`text-[15px] uppercase tracking-wide font-black drop-shadow-sm ${boxStyle.labelClass}`}>{metric.label}</span>
                <span className={`text-5xl font-black tracking-tight mt-2 ${boxStyle.valueClass}`}>
                  {loading ? '...' : metric.value}
                </span>
                <span className={`text-xs truncate mt-2 ${boxStyle.noteClass}`}>{metric.note}</span>
              </button>
            );
          })}
        </section>

        {/* Map & Chart Section */}
        <section className="grid grid-cols-1 lg:grid-cols-12 gap-6">

          {/* Interactive Map Component */}
          <div className={theme === 'light' ? 'lg:col-span-8 bg-white border border-neutral-200 p-8 rounded-[32px] shadow-2xl flex flex-col gap-5 min-h-[500px] map-glow-container hover:border-neutral-200/80 transition-all duration-300' : 'lg:col-span-8 bg-neutral-900 border border-neutral-800 p-8 rounded-[32px] shadow-2xl flex flex-col gap-5 min-h-[500px] map-glow-container hover:border-neutral-700/80 transition-all duration-300'}>
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
              <div>
                <p className="text-[11px] font-extrabold text-indigo-500 dark:text-indigo-400 tracking-widest uppercase">Live Geo-Tracking</p>
                <h2 className={`text-2xl font-bold tracking-normal mt-0.5 ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Active Mineral Transit Hotspots</h2>
              </div>

              <div className={`flex flex-wrap gap-4 text-xs rounded-2xl border transition-colors ${theme === 'light' ? 'bg-neutral-50 border-neutral-200 text-neutral-600' : 'bg-neutral-950 border-neutral-800 text-neutral-400'}`}>
                <span className="flex items-center gap-1.5 px-3 py-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-emerald-400"></span> Low
                </span>
                <span className="flex items-center gap-1.5 px-3 py-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-amber-400"></span> Medium
                </span>
                <span className="flex items-center gap-1.5 px-3 py-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-red-500"></span> High
                </span>
                {/* <span className="flex items-center gap-1.5 px-3 py-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-rose-500 animate-ping"></span> Overload
                </span> */}

              </div>
            </div>

            <div className="flex-1 w-full min-h-[420px] relative rounded-2xl overflow-hidden shadow-inner">
              <MapComponent
                records={filteredRecords}
                activeRecordId={activeRecordId}
                onSelectRecord={(id) => {
                  setActiveRecordId(id);
                }}
                theme={theme}
              />
            </div>
            <p className="text-[11px] text-neutral-500 text-center italic mt-1">
              * Interactive map supports tactile pinch zoom on tablets & mobile screens. Click a node to inspect location profile.
            </p>
          </div>

          {/* Right: Charts Vertical Stack */}
          <div className="lg:col-span-4 flex flex-col gap-6">

            {/* Incident Trend */}
            <article className={theme === 'light' ? 'bg-white border border-neutral-200 p-8 rounded-[32px] shadow-lg flex flex-col gap-5 modern-grid-card' : 'bg-neutral-900 border border-neutral-800 p-8 rounded-[32px] shadow-lg flex flex-col gap-5 modern-grid-card'}>
              <div>
                <p className="text-[11px] font-extrabold text-rose-500 dark:text-rose-400 tracking-widest uppercase">Telemetry Incident Trend</p>
                <h2 className={`text-lg font-bold mt-0.5 ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Overloads vs Fraud Alerts</h2>
              </div>
              <IncidentTrendChart data={data.incidentSeries} theme={theme} />
            </article>

            {/* Status Distribution */}
            <article className={theme === 'light' ? 'bg-white border border-neutral-200 p-8 rounded-[32px] shadow-lg flex flex-col gap-5 modern-grid-card' : 'bg-neutral-900 border border-neutral-800 p-8 rounded-[32px] shadow-lg flex flex-col gap-5 modern-grid-card'}>
              <div>
                <p className="text-[11px] font-extrabold text-amber-500 dark:text-amber-400 tracking-widest uppercase">State Outcome Allocation</p>
                <h2 className={`text-lg font-bold mt-0.5 ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Permit Compliance</h2>
              </div>
              <PermitStatusChart data={data.statusCounts} theme={theme} />
            </article>

          </div>
        </section>

        {/* Controls and Region/Risk Filtering Toolbar */}
        <section className={theme === 'light' ? 'bg-white border border-neutral-200 p-6 rounded-[28px] grid grid-cols-1 md:grid-cols-2 gap-5 shadow-lg hover:border-neutral-200/80 transition-all duration-300' : 'bg-neutral-900 border border-neutral-800 p-6 rounded-[28px] grid grid-cols-1 md:grid-cols-2 gap-5 shadow-lg hover:border-neutral-700/80 transition-all duration-300'}>
          <div className="flex flex-col gap-2">
            <label htmlFor="region" className="text-[11px] font-extrabold text-neutral-500 tracking-wider uppercase">
              Filter by Geological Region
            </label>
            <select
              id="region"
              value={selectedRegion}
              onChange={(e) => setSelectedRegion(e.target.value)}
              className={`w-full rounded-2xl p-4 text-base transition-all cursor-pointer font-medium focus:outline-none focus:ring-2 border ${theme === 'light' ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500/20' : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500/30'}`}
            >
              <option value="all">All administrative regions</option>
              {regionsList.map((reg) => (
                <option key={reg} value={reg}>
                  {reg}
                </option>
              ))}
            </select>
          </div>

          <div className="flex flex-col gap-2">
            <label htmlFor="risk" className="text-[11px] font-extrabold text-neutral-500 tracking-wider uppercase">
              Risk Assessment Status
            </label>
            <select
              id="risk"
              value={selectedRisk}
              onChange={(e) => setSelectedRisk(e.target.value)}
              className={`w-full rounded-2xl p-4 text-base transition-all cursor-pointer font-medium focus:outline-none focus:ring-2 border ${theme === 'light' ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500/20' : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500/30'}`}
            >
              <option value="all">All Risk Classes</option>
              <option value="high">High Assessment Alert</option>
              <option value="medium">Medium and Above warnings</option>
              <option value="low">Low Risk Only</option>
            </select>
          </div>
        </section>

      </div>
    );
  };

  const renderRegistry = () => {
    return (
      <div className="flex flex-col gap-6 w-full animate-fadeIn">

        <div className={`rounded-3xl p-8 relative overflow-hidden transition-all duration-300 border ${theme === 'light'
          ? 'bg-white border-neutral-200 shadow-md'
          : 'bg-neutral-900 border-neutral-800 shadow-xl'
          }`}>
          <span className="px-3.5 py-1 bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 text-[10px] font-black rounded-full border border-indigo-500/20 uppercase tracking-widest">
            LIVE COMPLIANCE LEDGER
          </span>
          <h1 className={`text-3xl font-black mt-4 tracking-tight transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Active & Historical Transport Permits</h1>
          <p className={`text-sm max-w-2xl mt-2 leading-relaxed transition-colors ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
            Search, review, and verify every mineral transport permit registered in Sri Lanka. High-contrast labels highlight legal compliance, volume overloads, and GPS anomalies.
          </p>
          <div className="absolute right-[-20px] bottom-[-20px] w-48 h-48 bg-indigo-500/[0.03] rounded-full blur-2xl"></div>
        </div>

        {/* Filters toolbar for Permits */}
        <div className={`p-6 rounded-3xl grid grid-cols-1 md:grid-cols-3 gap-5 transition-all duration-300 border ${theme === 'light'
          ? 'bg-white border-neutral-200 shadow-md'
          : 'bg-neutral-900 border-neutral-800 shadow-lg'
          }`}>
          <div className="flex flex-col gap-2">
            <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Search License / Truck Plate / Site Name</label>
            <div className="relative">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral-400" />
              <input
                type="text"
                placeholder="Search permit, truck, mine, hardware..."
                value={registrySearchQuery}
                onChange={(e) => setRegistrySearchQuery(e.target.value)}
                className={`rounded-xl py-3 pl-10 pr-4 text-xs transition-colors focus:outline-none focus:ring-1 w-full border ${theme === 'light'
                  ? 'bg-white border-neutral-200 text-neutral-800 placeholder-neutral-400 focus:ring-indigo-500 focus:border-indigo-500'
                  : 'bg-neutral-950 border-neutral-800 text-neutral-200 placeholder-neutral-600 focus:ring-indigo-500/50 focus:border-indigo-500/50'
                  }`}
              />
            </div>
          </div>

          <div className="flex flex-col gap-2">
            <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Permit Processing Status</label>
            <select
              value={registryStatusFilter}
              onChange={(e) => setRegistryStatusFilter(e.target.value)}
              className={`rounded-xl py-3 px-4 text-xs transition-colors focus:outline-none focus:ring-1 cursor-pointer w-full border ${theme === 'light'
                ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500/50'
                }`}
            >
              <option value="all">All Status Outcomes</option>
              <option value="active">Active Transit</option>
              <option value="completed">Completed Trips</option>
              <option value="pending">Pending Validation</option>
              <option value="cancelled">Cancelled Alerts</option>
            </select>
          </div>

          <div className="flex flex-col gap-2 justify-end">
            <button
              onClick={() => loadData(false)}
              disabled={loading || isSyncing}
              className={`w-full py-3 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center justify-center gap-2 border ${theme === 'light'
                ? 'bg-neutral-100 hover:bg-neutral-200 text-neutral-700 border-neutral-200'
                : 'bg-neutral-800 hover:bg-neutral-700 text-white border-neutral-700/50'
                }`}
            >
              <RotateCw className={`w-3.5 h-3.5 ${loading || isSyncing ? 'animate-spin' : ''}`} />
              Refresh List
            </button>
          </div>
        </div>

        {/* Table Ledger list */}
        <div className={`p-6 rounded-3xl transition-all duration-300 border ${theme === 'light'
          ? 'bg-white border-neutral-200 shadow-md'
          : 'bg-neutral-900 border-neutral-800 shadow-xl'
          }`}>
          <div className="flex justify-between items-center mb-4">
            <span className={`text-xs font-bold ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>
              Showing {filteredRegistryPermits.length} of {allRawPermits.length} total permits
            </span>
          </div>

          <div className={`overflow-x-auto border rounded-2xl transition-colors ${theme === 'light'
            ? 'border-neutral-200 bg-white'
            : 'border-neutral-800 bg-neutral-950'
            }`}>
            <table className="w-full text-left border-collapse min-w-[700px]">
              <thead>
                <tr className={`border-b text-[10px] uppercase tracking-widest font-black transition-colors ${theme === 'light'
                  ? 'border-neutral-200 bg-neutral-50 text-neutral-500'
                  : 'border-neutral-800 bg-neutral-900/30 text-neutral-500'
                  }`}>
                  <th className="py-4 px-5">Permit Code</th>
                  <th className="py-4 px-5">Truck Plate</th>
                  <th className="py-4 px-5">Load Volume</th>
                  <th className="py-4 px-5">Date of Transport</th>
                  <th className="py-4 px-5">Telemetry Coordinates</th>
                  <th className="py-4 px-5 text-center">Status</th>
                </tr>
              </thead>
              <tbody className={`divide-y text-xs transition-colors ${theme === 'light' ? 'divide-neutral-100' : 'divide-neutral-800/50'}`}>
                {loading ? (
                  <tr>
                    <td colSpan={6} className="py-12 text-center text-neutral-500 font-medium">
                      Synchronizing live database permits...
                    </td>
                  </tr>
                ) : filteredRegistryPermits.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-12 text-center text-neutral-500 font-medium">
                      No matching permits registered under current search query.
                    </td>
                  </tr>
                ) : (
                  filteredRegistryPermits.map((permit) => {
                    const isOverload = permit.volumeCubes > 5;
                    const isCancelled = permit.status === 'CANCELLED';

                    return (
                      <tr key={permit.id} className={`transition-colors border-b last:border-b-0 ${theme === 'light' ? 'hover:bg-neutral-50/50 border-neutral-100' : 'hover:bg-neutral-900/50 border-neutral-800/40'}`}>
                        <td className={`py-4 px-5 font-mono ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>
                          <div className="font-black text-sm">{permit.permitCode}</div>
                          <div className={`text-[10px] font-sans font-bold mt-0.5 ${theme === 'light' ? 'text-indigo-600' : 'text-indigo-400'}`}>{permit.originLocationName}</div>
                        </td>
                        <td className={`py-4 px-5 font-mono ${theme === 'light' ? 'text-neutral-800 font-bold' : 'text-neutral-300'}`}>
                          {permit.truckNumber}
                        </td>
                        <td className="py-4 px-5">
                          <span className={`px-2 py-0.5 rounded font-bold font-mono ${isOverload
                            ? (theme === 'light'
                              ? 'bg-rose-50 text-rose-800 border border-rose-200'
                              : 'bg-rose-500/10 text-rose-400 border border-rose-500/20')
                            : (theme === 'light' ? 'text-neutral-800' : 'text-neutral-200')
                            }`}>
                            {permit.volumeCubes} m³
                          </span>
                          {isOverload && (
                            <span className="block text-[8px] text-rose-500 dark:text-rose-400 uppercase font-black tracking-wider mt-0.5">
                              Overload Warning
                            </span>
                          )}
                        </td>
                        <td className={`py-4 px-5 ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
                          {permit.transportDate.toLocaleDateString('en-US', {
                            year: 'numeric',
                            month: 'short',
                            day: '2-digit',
                          })}
                        </td>
                        <td className="py-4 px-5 font-mono">
                          {permit.unloadLatitude && permit.unloadLongitude ? (
                            <span className={`${theme === 'light' ? 'text-emerald-600' : 'text-emerald-400'} font-bold flex items-center gap-1`}>
                              <Check className={`w-3 h-3 ${theme === 'light' ? 'text-emerald-600' : 'text-emerald-400'}`} />
                              {Number(permit.unloadLatitude).toFixed(4)}°N, {Number(permit.unloadLongitude).toFixed(4)}°E
                            </span>
                          ) : isCancelled ? (
                            <span className="text-neutral-500">N/A (Cancelled)</span>
                          ) : (
                            <span className={`${theme === 'light' ? 'text-rose-600' : 'text-rose-400'} font-bold flex items-center gap-1 animate-pulse`}>
                              <XCircle className={`w-3 h-3 ${theme === 'light' ? 'text-rose-600' : 'text-rose-400'}`} />
                              GPS Destination Missing
                            </span>
                          )}
                        </td>
                        <td className="py-4 px-5 text-center">
                          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[9px] font-black uppercase ${permit.status === 'ACTIVE'
                            ? (theme === 'light'
                              ? 'bg-indigo-50 text-indigo-800 border border-indigo-200/50'
                              : 'bg-indigo-500/15 text-indigo-400 border border-indigo-500/20')
                            : permit.status === 'COMPLETED'
                              ? (theme === 'light'
                                ? 'bg-emerald-50 text-emerald-800 border border-emerald-200/50'
                                : 'bg-emerald-500/15 text-emerald-300 border border-emerald-500/20')
                              : permit.status === 'CANCELLED'
                                ? (theme === 'light'
                                  ? 'bg-rose-50 text-rose-800 border border-rose-200/50'
                                  : 'bg-rose-500/15 text-rose-300 border border-rose-500/20')
                                : (theme === 'light'
                                  ? 'bg-amber-50 text-amber-800 border border-amber-200/50'
                                  : 'bg-amber-500/15 text-amber-300 border border-amber-500/20')
                            }`}>
                            {permit.status}
                          </span>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>

      </div>
    );
  };

  // ── Pagination helper component ──────────────────────────────────
  const renderPagination = (currentPage: number, totalPg: number, totalItems: number, pageSize: number, onPrev: () => void, onNext: () => void, onPage: (p: number) => void) => {
    if (totalPg <= 1) return null;
    const start = Math.min(totalItems, (currentPage - 1) * pageSize + 1);
    const end = Math.min(totalItems, currentPage * pageSize);
    return (
      <div className={`flex flex-col sm:flex-row items-center justify-between gap-4 pt-4 border-t transition-all duration-300 ${theme === 'light' ? 'border-neutral-100 text-neutral-600' : 'border-neutral-800/60 text-neutral-400'}`}>
        <div className="text-xs font-bold font-mono tracking-wider">
          Showing <span className={theme === 'light' ? 'text-neutral-900 font-extrabold' : 'text-white font-extrabold'}>{start}</span> to <span className={theme === 'light' ? 'text-neutral-900 font-extrabold' : 'text-white font-extrabold'}>{end}</span> of <span className={theme === 'light' ? 'text-neutral-900 font-extrabold' : 'text-white font-extrabold'}>{totalItems}</span>
        </div>
        <div className="flex items-center gap-1.5">
          <button onClick={onPrev} disabled={currentPage === 1} className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all duration-200 flex items-center gap-1 ${currentPage === 1 ? 'opacity-40 cursor-not-allowed border border-transparent' : theme === 'light' ? 'border border-neutral-200 bg-white hover:bg-neutral-100 hover:text-indigo-600 text-neutral-700 shadow-sm cursor-pointer' : 'border border-neutral-800/80 bg-neutral-900 hover:bg-neutral-800 hover:text-indigo-400 text-neutral-300 shadow-md cursor-pointer'}`}>
            <ChevronLeft className="w-3.5 h-3.5" /> Previous
          </button>
          {Array.from({ length: totalPg }, (_, i) => i + 1).filter(p => p === 1 || p === totalPg || Math.abs(p - currentPage) <= 1).map((page, index, arr) => {
            const isActive = page === currentPage;
            const showEllipsis = index > 0 && page - arr[index - 1] > 1;
            return (
              <React.Fragment key={page}>
                {showEllipsis && <span className="px-1 text-xs text-neutral-500 font-bold select-none">...</span>}
                <button onClick={() => onPage(page)} className={`w-8 h-8 rounded-xl text-xs font-black transition-all duration-200 cursor-pointer flex items-center justify-center ${isActive ? 'bg-indigo-600 text-white font-extrabold shadow-md shadow-indigo-600/25 scale-105' : theme === 'light' ? 'border border-neutral-200 bg-white hover:bg-neutral-100 hover:text-indigo-600 text-neutral-600' : 'border border-neutral-800/80 bg-neutral-900 hover:bg-neutral-800 hover:text-indigo-400 text-neutral-400'}`}>{page}</button>
              </React.Fragment>
            );
          })}
          <button onClick={onNext} disabled={currentPage === totalPg} className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all duration-200 flex items-center gap-1 ${currentPage === totalPg ? 'opacity-40 cursor-not-allowed border border-transparent' : theme === 'light' ? 'border border-neutral-200 bg-white hover:bg-neutral-100 hover:text-indigo-600 text-neutral-700 shadow-sm cursor-pointer' : 'border border-neutral-800/80 bg-neutral-900 hover:bg-neutral-800 hover:text-indigo-400 text-neutral-300 shadow-md cursor-pointer'}`}>
            Next <ChevronRight className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>
    );
  };

  // ── Data Explorer ────────────────────────────────────────────────
  const renderDataExplorer = () => {
    const th = theme;
    const card = `${th === 'light' ? 'bg-white border-neutral-200 shadow-md' : 'bg-neutral-900 border-neutral-800 shadow-2xl'}`;
    const tableBg = `${th === 'light' ? 'border-neutral-200 bg-white' : 'border-neutral-800 bg-neutral-950'}`;
    const theadTr = `border-b text-[10px] uppercase tracking-widest font-black transition-colors ${th === 'light' ? 'border-neutral-200 bg-neutral-50 text-neutral-500' : 'border-neutral-800 bg-neutral-900/30 text-neutral-500'}`;
    const tdBase = `py-3.5 px-4 text-sm ${th === 'light' ? 'text-neutral-800' : 'text-neutral-200'}`;
    const trHover = `cursor-pointer transition-colors border-b last:border-b-0 ${th === 'light' ? 'hover:bg-indigo-50/60 border-neutral-100' : 'hover:bg-indigo-950/30 border-neutral-800/40'}`;
    const inputCls = `w-full rounded-xl py-2 pl-9 pr-3 text-xs border transition-colors focus:outline-none focus:ring-1 ${th === 'light' ? 'bg-white border-neutral-200 text-neutral-800 placeholder-neutral-400 focus:ring-indigo-500 focus:border-indigo-500' : 'bg-neutral-950 border-neutral-800 text-neutral-200 placeholder-neutral-600 focus:ring-indigo-500/50 focus:border-indigo-500/50'}`;

    const TABS: { key: 'users' | 'mines' | 'hardwares' | 'trucks'; label: string; icon: React.ReactNode }[] = [
      { key: 'users', label: 'Users', icon: <Users className="w-4 h-4" /> },
      { key: 'mines', label: 'Mines', icon: <HardHat className="w-4 h-4" /> },
      { key: 'hardwares', label: 'Hardwares', icon: <Building2 className="w-4 h-4" /> },
      { key: 'trucks', label: 'Trucks', icon: <Truck className="w-4 h-4" /> },
    ];

    // ── filter + paginate ──
    const q = explorerSearch.trim().toLowerCase();

    const filteredUsers = dbUsers.filter(u => {
      if (!q) return true;
      // search by name, nic, email, phone
      return [u.name, u.nic, u.email, u.phone, u.phone_number, u.user_id].filter(Boolean).join(' ').toLowerCase().includes(q);
    });
    const filteredMines = rawMinesData.filter(m => {
      if (!q) return true;
      // search by name, id, owner name
      const ownerName = getUserNameById(m.user_id);
      return [m.mine_name, m.mine_id, ownerName].filter(Boolean).join(' ').toLowerCase().includes(q);
    });
    const filteredHardwares = rawHardwaresData.filter(h => {
      if (!q) return true;
      const ownerName = getUserNameById(h.user_id);
      return [h.hardware_name, h.hardware_id, ownerName].filter(Boolean).join(' ').toLowerCase().includes(q);
    });
    const filteredTrucks = rawTrucks.filter(t => {
      if (!q) return true;
      return [t.number_plate, t.truck_id, t.user_id].filter(Boolean).join(' ').toLowerCase().includes(q);
    });

    const getFiltered = () => {
      if (explorerTab === 'users') return filteredUsers;
      if (explorerTab === 'mines') return filteredMines;
      if (explorerTab === 'hardwares') return filteredHardwares;
      return filteredTrucks;
    };

    const filteredAll = getFiltered();
    const totalPg = Math.max(1, Math.ceil(filteredAll.length / EXPLORER_PAGE_SIZE));
    const safePage = Math.min(explorerPage, totalPg);
    const paginatedItems = filteredAll.slice((safePage - 1) * EXPLORER_PAGE_SIZE, safePage * EXPLORER_PAGE_SIZE);

    // Copy button helper
    const CopyBtn = ({ id }: { id: string }) => (
      <button
        onClick={e => { e.stopPropagation(); handleCopyId(id); }}
        title="Copy full ID"
        className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded-lg text-[10px] font-bold border cursor-pointer transition-colors shrink-0 ${copiedId === id
          ? th === 'light' ? 'border-emerald-300 bg-emerald-50 text-emerald-700' : 'border-emerald-500/40 bg-emerald-500/15 text-emerald-300'
          : th === 'light' ? 'border-neutral-200 bg-neutral-50 text-neutral-500 hover:bg-neutral-100' : 'border-neutral-700 bg-neutral-800 text-neutral-400 hover:bg-neutral-700'
          }`}
      >
        {copiedId === id ? <CheckCheck className="w-3 h-3" /> : <Copy className="w-3 h-3" />}
      </button>
    );


    // Search within user popup sub-tables
    const subQ = popupSubSearch.trim().toLowerCase();

    return (
      <div className="flex flex-col gap-6 w-full animate-fadeIn">
        {/* Header */}
        <div className={`rounded-3xl p-6 relative overflow-hidden transition-all duration-300 border ${card}`}>
          <span className="px-3.5 py-1 bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 text-[10px] font-black rounded-full border border-indigo-500/20 uppercase tracking-widest">
            DATABASE EXPLORER
          </span>
          <h1 className={`text-2xl lg:text-3xl font-black mt-3 tracking-tight transition-colors ${th === 'light' ? 'text-neutral-900' : 'text-white'}`}>Data Explorer</h1>
          <p className={`text-xs max-w-2xl mt-1.5 leading-relaxed transition-colors ${th === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>
            Browse and inspect all Users, Mines, Hardware stores, and Trucks from the live database. Click any row for detailed information.
          </p>
          <div className="absolute right-[-20px] bottom-[-20px] w-40 h-40 bg-indigo-500/[0.03] rounded-full blur-2xl"></div>
        </div>

        {/* Tab toggle */}
        <div className={`p-1.5 rounded-2xl border flex items-center gap-1.5 w-full sm:w-max transition-all duration-300 ${th === 'light' ? 'bg-white border-neutral-200 shadow-sm' : 'bg-neutral-900 border-neutral-800'}`}>
          {TABS.map(tab => (
            <button
              key={tab.key}
              onClick={() => { setExplorerTab(tab.key); setExplorerSearch(''); }}
              className={`flex-1 sm:flex-none py-2 px-5 rounded-xl text-xs font-bold uppercase transition-all flex items-center justify-center gap-2 cursor-pointer ${explorerTab === tab.key
                ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/25'
                : th === 'light'
                  ? 'text-neutral-600 hover:text-neutral-900 hover:bg-neutral-100'
                  : 'text-neutral-400 hover:text-white hover:bg-neutral-800'
                }`}
            >
              {tab.icon} {tab.label}
            </button>
          ))}
        </div>

        {/* Search + table */}
        <div className={`p-6 rounded-3xl border flex flex-col gap-5 transition-all duration-300 ${card}`}>
          {/* Search bar */}
          <div className="relative">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral-400" />
            <input
              type="text"
              placeholder={
                explorerTab === 'users' ? 'Search by name, NIC, email or phone...'
                  : explorerTab === 'mines' ? 'Search by mine name or owner name...'
                    : explorerTab === 'hardwares' ? 'Search by hardware name or owner name...'
                      : 'Search trucks by plate number...'
              }
              value={explorerSearch}
              onChange={e => setExplorerSearch(e.target.value)}
              className={`w-full rounded-xl py-2.5 pl-10 pr-4 text-sm border transition-colors focus:outline-none focus:ring-1 ${th === 'light'
                ? 'bg-white border-neutral-200 text-neutral-800 placeholder-neutral-400 focus:ring-indigo-500 focus:border-indigo-500'
                : 'bg-neutral-950 border-neutral-800 text-neutral-200 placeholder-neutral-600 focus:ring-indigo-500/50 focus:border-indigo-500/50'
                }`}
            />
          </div>

          {/* Table */}
          <div className={`overflow-x-auto border rounded-2xl transition-colors ${tableBg}`}>
            {explorerTab === 'users' && (
              <table className="w-full text-left border-collapse min-w-[750px]">
                <thead><tr className={theadTr}>
                  <th className="py-3.5 px-4">Name</th>
                  <th className="py-3.5 px-4">NIC</th>
                  <th className="py-3.5 px-4">Email</th>
                  <th className="py-3.5 px-4">Phone</th>
                  <th className="py-3.5 px-4 text-center">Mines</th>
                  <th className="py-3.5 px-4 text-center">Hardwares</th>
                  <th className="py-3.5 px-4 text-center">Actions</th>
                </tr></thead>
                <tbody className={`divide-y text-sm ${th === 'light' ? 'divide-neutral-100' : 'divide-neutral-800/50'}`}>
                  {loading ? (
                    <tr><td colSpan={7} className="py-10 text-center text-neutral-400 animate-pulse">Loading users...</td></tr>
                  ) : paginatedItems.length === 0 ? (
                    <tr><td colSpan={7} className="py-10 text-center text-neutral-400">No users found.</td></tr>
                  ) : paginatedItems.map((u: any) => {
                    const uid = u.user_id || u.id;
                    const mineCount = rawMinesData.filter(m => m.user_id === uid).length;
                    const hwCount = rawHardwaresData.filter(h => h.user_id === uid).length;
                    return (
                      <tr key={uid} onClick={() => { setPopupItem(u); setPopupType('user'); setUserPopupTab('mines'); setSubPopupItem(null); setSubPopupType(null); setPopupSubSearch(''); }} className={trHover}>
                        <td className={tdBase}>
                          <div className="flex items-center gap-2.5">
                            {u.profile_picture ? (
                              <img src={u.profile_picture} alt="" className="w-7 h-7 rounded-full object-cover shrink-0" />
                            ) : (
                              <div className={`w-7 h-7 rounded-full flex items-center justify-center shrink-0 text-[11px] font-black ${th === 'light' ? 'bg-indigo-100 text-indigo-700' : 'bg-indigo-500/20 text-indigo-300'}`}>
                                {(u.name || 'U')[0].toUpperCase()}
                              </div>
                            )}
                            <span className="font-semibold">{u.name || 'Unknown'}</span>
                          </div>
                        </td>
                        <td className={`${tdBase} font-mono text-xs`}>{u.nic || 'N/A'}</td>
                        <td className={`${tdBase} text-xs`}>{u.email || 'N/A'}</td>
                        <td className={`${tdBase} text-xs font-mono`}>{u.phone || u.phone_number || 'N/A'}</td>
                        <td className={`${tdBase} text-center`}>
                          <span className={`inline-flex items-center justify-center min-w-[1.5rem] h-6 px-2 rounded-full text-[11px] font-black ${mineCount > 0
                            ? th === 'light' ? 'bg-emerald-100 text-emerald-800' : 'bg-emerald-500/20 text-emerald-300'
                            : th === 'light' ? 'bg-neutral-100 text-neutral-500' : 'bg-neutral-800 text-neutral-500'
                            }`}>{mineCount}</span>
                        </td>
                        <td className={`${tdBase} text-center`}>
                          <span className={`inline-flex items-center justify-center min-w-[1.5rem] h-6 px-2 rounded-full text-[11px] font-black ${hwCount > 0
                            ? th === 'light' ? 'bg-indigo-100 text-indigo-800' : 'bg-indigo-500/20 text-indigo-300'
                            : th === 'light' ? 'bg-neutral-100 text-neutral-500' : 'bg-neutral-800 text-neutral-500'
                            }`}>{hwCount}</span>
                        </td>
                        <td className={`${tdBase} text-center`}>
                          <button className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] font-bold border cursor-pointer transition-colors ${th === 'light' ? 'border-indigo-200 bg-indigo-50 text-indigo-700 hover:bg-indigo-100' : 'border-indigo-500/25 bg-indigo-500/10 text-indigo-300 hover:bg-indigo-500/20'}`}>
                            <Eye className="w-3 h-3" /> View
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}

            {explorerTab === 'mines' && (
              <table className="w-full text-left border-collapse min-w-[650px]">
                <thead><tr className={theadTr}>
                  <th className="py-3.5 px-4">Mine Name</th>
                  <th className="py-3.5 px-4">Owner</th>
                  <th className="py-3.5 px-4">Current Stock</th>
                  <th className="py-3.5 px-4">Max Capacity</th>
                  <th className="py-3.5 px-4">Coordinates</th>
                  <th className="py-3.5 px-4 text-center">Actions</th>
                </tr></thead>
                <tbody className={`divide-y text-sm ${th === 'light' ? 'divide-neutral-100' : 'divide-neutral-800/50'}`}>
                  {loading ? (
                    <tr><td colSpan={6} className="py-10 text-center text-neutral-400 animate-pulse">Loading mines...</td></tr>
                  ) : paginatedItems.length === 0 ? (
                    <tr><td colSpan={6} className="py-10 text-center text-neutral-400">No mines found.</td></tr>
                  ) : paginatedItems.map((m: any) => (
                    <tr key={m.mine_id} onClick={() => { setPopupItem(m); setPopupType('mine'); }} className={trHover}>
                      <td className={tdBase}>
                        <div className="font-semibold">{m.mine_name || 'Unnamed'}</div>
                        <div className="font-mono text-[10px] text-neutral-400 mt-0.5 truncate max-w-[140px]">{m.mine_id}</div>
                      </td>
                      <td className={`${tdBase} text-xs`}>{getUserNameById(m.user_id)}</td>
                      <td className={tdBase}><span className="font-mono font-bold">{m.current_cubes ?? 'N/A'}</span> m³</td>
                      <td className={tdBase}><span className="font-mono font-bold">{m.maximum_cubes ?? 'N/A'}</span> m³</td>
                      <td className={`${tdBase} text-xs font-mono`}>{m.latitude != null ? `${Number(m.latitude).toFixed(4)}, ${Number(m.longitude).toFixed(4)}` : 'N/A'}</td>
                      <td className={`${tdBase} text-center`}>
                        <button className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] font-bold border cursor-pointer transition-colors ${th === 'light' ? 'border-emerald-200 bg-emerald-50 text-emerald-700 hover:bg-emerald-100' : 'border-emerald-500/25 bg-emerald-500/10 text-emerald-300 hover:bg-emerald-500/20'}`}>
                          <Eye className="w-3 h-3" /> View
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {explorerTab === 'hardwares' && (
              <table className="w-full text-left border-collapse min-w-[650px]">
                <thead><tr className={theadTr}>
                  <th className="py-3.5 px-4">Hardware Name</th>
                  <th className="py-3.5 px-4">Owner</th>
                  <th className="py-3.5 px-4">Current Stock</th>
                  <th className="py-3.5 px-4">Max Capacity</th>
                  <th className="py-3.5 px-4">Coordinates</th>
                  <th className="py-3.5 px-4 text-center">Actions</th>
                </tr></thead>
                <tbody className={`divide-y text-sm ${th === 'light' ? 'divide-neutral-100' : 'divide-neutral-800/50'}`}>
                  {loading ? (
                    <tr><td colSpan={6} className="py-10 text-center text-neutral-400 animate-pulse">Loading hardwares...</td></tr>
                  ) : paginatedItems.length === 0 ? (
                    <tr><td colSpan={6} className="py-10 text-center text-neutral-400">No hardware stores found.</td></tr>
                  ) : paginatedItems.map((h: any) => (
                    <tr key={h.hardware_id} onClick={() => { setPopupItem(h); setPopupType('hardware'); }} className={trHover}>
                      <td className={tdBase}>
                        <div className="font-semibold">{h.hardware_name || 'Unnamed'}</div>
                        <div className="font-mono text-[10px] text-neutral-400 mt-0.5 truncate max-w-[140px]">{h.hardware_id}</div>
                      </td>
                      <td className={`${tdBase} text-xs`}>{getUserNameById(h.user_id)}</td>
                      <td className={tdBase}><span className="font-mono font-bold">{h.current_cubes ?? 'N/A'}</span> m³</td>
                      <td className={tdBase}><span className="font-mono font-bold">{h.maximum_cubes ?? 'N/A'}</span> m³</td>
                      <td className={`${tdBase} text-xs font-mono`}>{h.latitude != null ? `${Number(h.latitude).toFixed(4)}, ${Number(h.longitude).toFixed(4)}` : 'N/A'}</td>
                      <td className={`${tdBase} text-center`}>
                        <button className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] font-bold border cursor-pointer transition-colors ${th === 'light' ? 'border-indigo-200 bg-indigo-50 text-indigo-700 hover:bg-indigo-100' : 'border-indigo-500/25 bg-indigo-500/10 text-indigo-300 hover:bg-indigo-500/20'}`}>
                          <Eye className="w-3 h-3" /> View
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {explorerTab === 'trucks' && (
              <table className="w-full text-left border-collapse min-w-[550px]">
                <thead><tr className={theadTr}>
                  <th className="py-3.5 px-4">Number Plate</th>
                  <th className="py-3.5 px-4">Owner</th>
                  <th className="py-3.5 px-4">Capacity</th>
                  <th className="py-3.5 px-4 text-center">Actions</th>
                </tr></thead>
                <tbody className={`divide-y text-sm ${th === 'light' ? 'divide-neutral-100' : 'divide-neutral-800/50'}`}>
                  {loading ? (
                    <tr><td colSpan={4} className="py-10 text-center text-neutral-400 animate-pulse">Loading trucks...</td></tr>
                  ) : paginatedItems.length === 0 ? (
                    <tr><td colSpan={4} className="py-10 text-center text-neutral-400">No trucks found.</td></tr>
                  ) : paginatedItems.map((t: any, idx: number) => (
                    <tr key={t.truck_id || t.number_plate || idx} onClick={() => { setPopupItem(t); setPopupType('truck'); }} className={trHover}>
                      <td className={`${tdBase} font-mono font-bold`}>{t.number_plate || 'N/A'}</td>
                      <td className={`${tdBase} text-xs`}>{getUserNameById(t.user_id)}</td>
                      <td className={tdBase}><span className="font-mono">{t.capacity != null ? `${t.capacity} m³` : 'N/A'}</span></td>
                      <td className={`${tdBase} text-center`}>
                        <button className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] font-bold border cursor-pointer transition-colors ${th === 'light' ? 'border-amber-200 bg-amber-50 text-amber-700 hover:bg-amber-100' : 'border-amber-500/25 bg-amber-500/10 text-amber-300 hover:bg-amber-500/20'}`}>
                          <Eye className="w-3 h-3" /> View
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          {/* Pagination */}
          {renderPagination(safePage, totalPg, filteredAll.length, EXPLORER_PAGE_SIZE,
            () => setExplorerPage(p => Math.max(1, p - 1)),
            () => setExplorerPage(p => Math.min(totalPg, p + 1)),
            (p) => setExplorerPage(p)
          )}
        </div>

        {/* ── Popups ── */}
        <AnimatePresence>
          {popupItem && popupType && (
            <motion.div
              key="popup-backdrop"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-[99999] flex items-center justify-center p-4"
              style={{ backdropFilter: 'blur(5px)', WebkitBackdropFilter: 'blur(5px)', backgroundColor: th === 'light' ? 'rgba(255,255,255,0.6)' : 'rgba(10,10,14,0.75)' }}
              onClick={e => { if (e.target === e.currentTarget) { setPopupItem(null); setPopupType(null); setSubPopupItem(null); setSubPopupType(null); } }}
            >
              {/* ── USER POPUP ── */}
              {popupType === 'user' && (() => {
                const u = popupItem;
                const uid = u.user_id || u.id;
                const userMines = rawMinesData.filter(m => m.user_id === uid);
                const userHardwares = rawHardwaresData.filter(h => h.user_id === uid);
                const userTrucks = rawTrucks.filter(t => t.user_id === uid);
                const hasMines = userMines.length > 0;
                const hasHardwares = userHardwares.length > 0;
                const hasTrucks = userTrucks.length > 0;
                const availableTabs = (['mines', 'hardwares', 'trucks'] as const).filter(t => t === 'mines' ? hasMines : t === 'hardwares' ? hasHardwares : hasTrucks);
                const activeSubTab = availableTabs.includes(userPopupTab) ? userPopupTab : availableTabs[0] || 'mines';

                const filteredSubMines = userMines.filter(m => !subQ || (m.mine_name || '').toLowerCase().includes(subQ));
                const filteredSubHardwares = userHardwares.filter(h => !subQ || (h.hardware_name || '').toLowerCase().includes(subQ));
                const filteredSubTrucks = userTrucks.filter(t => !subQ || (t.number_plate || '').toLowerCase().includes(subQ));

                return (
                  <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.15 }}
                    className={`relative w-full max-w-2xl max-h-[90vh] overflow-y-auto rounded-3xl border shadow-2xl p-6 sm:p-8 flex flex-col gap-5 ${th === 'light' ? 'bg-white border-neutral-200' : 'bg-neutral-900 border-neutral-800'}`}
                    onClick={e => e.stopPropagation()}
                  >
                    <button
                      onClick={() => { setPopupItem(null); setPopupType(null); setSubPopupItem(null); setSubPopupType(null); }}
                      className={`absolute top-4 right-4 p-2 rounded-xl border transition-colors cursor-pointer z-10 ${th === 'light' ? 'border-neutral-200 bg-white hover:bg-neutral-100 text-neutral-600' : 'border-neutral-800 bg-neutral-950 hover:bg-neutral-800 text-neutral-400 hover:text-white'}`}
                    >
                      <X className="w-4 h-4" />
                    </button>

                    {/* User header */}
                    <div className="flex flex-col items-center gap-3 pb-5 border-b" style={{ borderColor: th === 'light' ? '#e5e7eb' : 'rgba(255,255,255,0.1)' }}>
                      {u.profile_picture ? (
                        <img src={u.profile_picture} alt="Profile" className="w-20 h-20 rounded-full object-cover border-4 shadow-lg" style={{ borderColor: th === 'light' ? '#e0e7ff' : '#4f46e5' }} />
                      ) : (
                        <div className={`w-20 h-20 rounded-full flex items-center justify-center text-3xl font-black border-4 shadow-lg ${th === 'light' ? 'bg-indigo-100 text-indigo-700 border-indigo-200' : 'bg-indigo-500/20 text-indigo-300 border-indigo-500/30'}`}>
                          {(u.name || 'U')[0].toUpperCase()}
                        </div>
                      )}
                      <h2 className={`text-xl font-black ${th === 'light' ? 'text-neutral-900' : 'text-white'}`}>{u.name || 'Unknown User'}</h2>

                      {/* Counts badges */}
                      <div className="flex items-center gap-2 flex-wrap justify-center">
                        {[{ label: 'Mines', count: userMines.length, color: th === 'light' ? 'bg-emerald-100 text-emerald-800 border-emerald-200' : 'bg-emerald-500/15 text-emerald-300 border-emerald-500/25' },
                        { label: 'Hardwares', count: userHardwares.length, color: th === 'light' ? 'bg-indigo-100 text-indigo-800 border-indigo-200' : 'bg-indigo-500/15 text-indigo-300 border-indigo-500/25' },
                        { label: 'Trucks', count: userTrucks.length, color: th === 'light' ? 'bg-amber-100 text-amber-800 border-amber-200' : 'bg-amber-500/15 text-amber-300 border-amber-500/25' },
                        ].map(b => (
                          <span key={b.label} className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-black border ${b.color}`}>
                            <span className="text-base font-black">{b.count}</span> {b.label}
                          </span>
                        ))}
                      </div>

                      {/* Info grid */}
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 w-full mt-1">
                        {[
                          { icon: <User className="w-3.5 h-3.5" />, label: 'NIC', value: u.nic || 'N/A', copy: false },
                          { icon: <Mail className="w-3.5 h-3.5" />, label: 'Email', value: u.email || 'N/A', copy: false },
                          { icon: <Phone className="w-3.5 h-3.5" />, label: 'Phone', value: u.phone || u.phone_number || 'N/A', copy: false },
                          { icon: <ShieldCheck className="w-3.5 h-3.5" />, label: 'User ID', value: uid || 'N/A', copy: true },
                        ].map(row => (
                          <div key={row.label} className={`flex items-start gap-2 p-2.5 rounded-xl border text-xs ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                            <span className={`shrink-0 mt-0.5 ${th === 'light' ? 'text-indigo-600' : 'text-indigo-400'}`}>{row.icon}</span>
                            <div className="flex-1 min-w-0">
                              <div className={`text-[9px] uppercase font-black tracking-wider mb-0.5 ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>{row.label}</div>
                              <div className={`font-semibold flex items-center gap-1.5 ${th === 'light' ? 'text-neutral-800' : 'text-neutral-200'}`}>
                                <span className={`truncate ${row.copy ? 'font-mono text-[10px]' : ''}`}>{row.copy && row.value !== 'N/A' ? row.value.slice(0, 20) + '...' : row.value}</span>
                                {row.copy && row.value !== 'N/A' && <CopyBtn id={row.value} />}
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>

                    {/* Sub-tabs */}
                    {availableTabs.length > 0 && (
                      <div className="flex flex-col gap-4">
                        <div className="flex flex-col sm:flex-row sm:items-center gap-3">
                          {/* tab toggles */}
                          <div className={`flex p-1 rounded-2xl border text-xs font-bold w-max ${th === 'light' ? 'bg-neutral-100 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                            {availableTabs.map(tab => (
                              <button key={tab} onClick={() => { setUserPopupTab(tab); setPopupSubSearch(''); }} className={`px-4 py-1.5 rounded-xl transition-all cursor-pointer capitalize ${userPopupTab === tab ? 'bg-indigo-600 text-white shadow-sm' : th === 'light' ? 'text-neutral-600 hover:text-neutral-900' : 'text-neutral-400 hover:text-white'}`}>{tab}</button>
                            ))}
                          </div>
                          {/* sub-search */}
                          <div className="relative flex-1">
                            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-neutral-400" />
                            <input
                              type="text"
                              placeholder={`Search ${activeSubTab}...`}
                              value={popupSubSearch}
                              onChange={e => setPopupSubSearch(e.target.value)}
                              className={inputCls}
                              onClick={e => e.stopPropagation()}
                            />
                          </div>
                        </div>

                        {/* mines sub-tab */}
                        {activeSubTab === 'mines' && (
                          <div className={`overflow-x-auto border rounded-2xl ${th === 'light' ? 'border-neutral-200' : 'border-neutral-800'}`}>
                            <table className="w-full text-left border-collapse min-w-[400px]">
                              <thead><tr className={theadTr}>
                                <th className="py-3 px-4">Mine Name</th>
                                <th className="py-3 px-4">Stock</th>
                                <th className="py-3 px-4">Max</th>
                                <th className="py-3 px-4">ID</th>
                              </tr></thead>
                              <tbody className={`divide-y text-xs ${th === 'light' ? 'divide-neutral-100' : 'divide-neutral-800/50'}`}>
                                {filteredSubMines.length === 0 ? (
                                  <tr><td colSpan={4} className="py-6 text-center text-neutral-400">No mines match search.</td></tr>
                                ) : filteredSubMines.map(m => (
                                  <tr key={m.mine_id} onClick={() => { setSubPopupItem(m); setSubPopupType('mine'); }} className={trHover}>
                                    <td className={`py-3 px-4 font-semibold ${th === 'light' ? 'text-neutral-800' : 'text-neutral-200'}`}>{m.mine_name}</td>
                                    <td className={`py-3 px-4 font-mono ${th === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>{m.current_cubes} m³</td>
                                    <td className={`py-3 px-4 font-mono ${th === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>{m.maximum_cubes} m³</td>
                                    <td className="py-3 px-4">
                                      <div className="flex items-center gap-1.5">
                                        <span className="font-mono text-[10px] text-neutral-400 truncate max-w-[80px]">{(m.mine_id || '').slice(0, 10)}...</span>
                                        {m.mine_id && <CopyBtn id={m.mine_id} />}
                                      </div>
                                    </td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                          </div>
                        )}

                        {/* hardwares sub-tab */}
                        {activeSubTab === 'hardwares' && (
                          <div className={`overflow-x-auto border rounded-2xl ${th === 'light' ? 'border-neutral-200' : 'border-neutral-800'}`}>
                            <table className="w-full text-left border-collapse min-w-[400px]">
                              <thead><tr className={theadTr}>
                                <th className="py-3 px-4">Hardware Name</th>
                                <th className="py-3 px-4">Stock</th>
                                <th className="py-3 px-4">Max</th>
                                <th className="py-3 px-4">ID</th>
                              </tr></thead>
                              <tbody className={`divide-y text-xs ${th === 'light' ? 'divide-neutral-100' : 'divide-neutral-800/50'}`}>
                                {filteredSubHardwares.length === 0 ? (
                                  <tr><td colSpan={4} className="py-6 text-center text-neutral-400">No hardwares match search.</td></tr>
                                ) : filteredSubHardwares.map(h => (
                                  <tr key={h.hardware_id} onClick={() => { setSubPopupItem(h); setSubPopupType('hardware'); }} className={trHover}>
                                    <td className={`py-3 px-4 font-semibold ${th === 'light' ? 'text-neutral-800' : 'text-neutral-200'}`}>{h.hardware_name}</td>
                                    <td className={`py-3 px-4 font-mono ${th === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>{h.current_cubes} m³</td>
                                    <td className={`py-3 px-4 font-mono ${th === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>{h.maximum_cubes} m³</td>
                                    <td className="py-3 px-4">
                                      <div className="flex items-center gap-1.5">
                                        <span className="font-mono text-[10px] text-neutral-400 truncate max-w-[80px]">{(h.hardware_id || '').slice(0, 10)}...</span>
                                        {h.hardware_id && <CopyBtn id={h.hardware_id} />}
                                      </div>
                                    </td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                          </div>
                        )}

                        {/* trucks sub-tab */}
                        {activeSubTab === 'trucks' && (
                          <div className={`overflow-x-auto border rounded-2xl ${th === 'light' ? 'border-neutral-200' : 'border-neutral-800'}`}>
                            <table className="w-full text-left border-collapse min-w-[300px]">
                              <thead><tr className={theadTr}>
                                <th className="py-3 px-4">Number Plate</th>
                                <th className="py-3 px-4">Capacity</th>
                              </tr></thead>
                              <tbody className={`divide-y text-xs ${th === 'light' ? 'divide-neutral-100' : 'divide-neutral-800/50'}`}>
                                {filteredSubTrucks.length === 0 ? (
                                  <tr><td colSpan={2} className="py-6 text-center text-neutral-400">No trucks match search.</td></tr>
                                ) : filteredSubTrucks.map((t, i) => (
                                  <tr key={t.truck_id || i} onClick={() => { setSubPopupItem(t); setSubPopupType('truck'); }} className={trHover}>
                                    <td className={`py-3 px-4 font-mono font-bold ${th === 'light' ? 'text-neutral-800' : 'text-neutral-200'}`}>{t.number_plate || 'N/A'}</td>
                                    <td className={`py-3 px-4 font-mono ${th === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>{t.capacity != null ? `${t.capacity} m³` : 'N/A'}</td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                          </div>
                        )}
                      </div>
                    )}
                    {availableTabs.length === 0 && (
                      <p className={`text-xs text-center py-4 ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>No associated mines, hardwares, or trucks found.</p>
                    )}
                  </motion.div>
                );
              })()}

              {/* ── MINE POPUP ── */}
              {popupType === 'mine' && (() => {
                const m = popupItem;
                const owner = dbUsers.find(u => u.user_id === m.user_id || u.id === m.user_id);
                const fill = m.maximum_cubes > 0 ? Math.round((m.current_cubes / m.maximum_cubes) * 100) : 0;
                const isOver = m.current_cubes > m.maximum_cubes;
                const hasCoords = m.latitude != null && m.longitude != null;
                return (
                  <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.16 }}
                    className="flex flex-col md:flex-row gap-6 w-full max-w-5xl max-h-[90vh] items-stretch justify-center relative p-4"
                    onClick={e => e.stopPropagation()}
                  >
                    {/* Left: Info card */}
                    <div
                      className={`relative flex-1 rounded-3xl border shadow-2xl p-6 sm:p-8 flex flex-col justify-between gap-5 overflow-y-auto ${th === 'light' ? 'bg-white border-neutral-200' : 'bg-neutral-900 border-neutral-800'}`}
                    >
                      <button
                        onClick={() => { setPopupItem(null); setPopupType(null); }}
                        className={`absolute top-4 right-4 p-2 rounded-xl border transition-colors cursor-pointer z-20 ${th === 'light' ? 'border-neutral-200 bg-white hover:bg-neutral-100 text-neutral-600' : 'border-neutral-800 bg-neutral-950 hover:bg-neutral-800 text-neutral-400 hover:text-white'}`}
                      >
                        <X className="w-4 h-4" />
                      </button>
                      <div className="flex flex-col gap-5">
                        <div className="flex items-center gap-3 pr-8">
                          <div className={`w-12 h-12 rounded-2xl flex items-center justify-center shrink-0 ${th === 'light' ? 'bg-emerald-100' : 'bg-emerald-500/15'}`}>
                            <HardHat className={`w-6 h-6 ${th === 'light' ? 'text-emerald-700' : 'text-emerald-400'}`} />
                          </div>
                          <div>
                            <span className={`text-[10px] font-black uppercase tracking-wider ${th === 'light' ? 'text-emerald-600' : 'text-emerald-400'}`}>Mine</span>
                            <h2 className={`text-xl font-black leading-snug ${th === 'light' ? 'text-neutral-900' : 'text-white'}`}>{m.mine_name || 'Unnamed Mine'}</h2>
                          </div>
                        </div>
                        <div className="grid grid-cols-2 gap-3">
                          {[
                            { label: 'Current Stock', value: `${m.current_cubes ?? 'N/A'} m³`, color: isOver ? (th === 'light' ? 'text-rose-700' : 'text-rose-400') : '' },
                            { label: 'Maximum Capacity', value: `${m.maximum_cubes ?? 'N/A'} m³` },
                            { label: 'Owner', value: owner ? (owner.name || 'Unknown') : 'Unassigned' },
                            { label: 'Owner NIC', value: owner ? (owner.nic || 'N/A') : 'N/A' },
                          ].map(row => (
                            <div key={row.label} className={`p-3.5 rounded-2xl border flex flex-col gap-1 ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                              <span className={`text-[9px] uppercase font-black tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>{row.label}</span>
                              <span className={`font-bold text-sm ${row.color || (th === 'light' ? 'text-neutral-800' : 'text-neutral-200')}`}>{row.value}</span>
                            </div>
                          ))}
                          {/* Mine ID with copy */}
                          <div className={`col-span-2 p-3.5 rounded-2xl border flex flex-col gap-1 ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                            <span className={`text-[9px] uppercase font-black tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>Mine ID</span>
                            <div className="flex items-center gap-2">
                              <span className={`font-mono text-xs truncate ${th === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>{m.mine_id || 'N/A'}</span>
                              {m.mine_id && <CopyBtn id={m.mine_id} />}
                            </div>
                          </div>
                        </div>
                        {/* Capacity bar */}
                        <div className={`p-4 rounded-2xl border ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                          <div className="flex justify-between mb-2 text-xs font-bold">
                            <span className={th === 'light' ? 'text-neutral-600' : 'text-neutral-400'}>Capacity Fill</span>
                            <span className={isOver ? (th === 'light' ? 'text-rose-700' : 'text-rose-400') : (th === 'light' ? 'text-emerald-700' : 'text-emerald-400')}>{fill}% {isOver ? '⚠ OVERLOADED' : ''}</span>
                          </div>
                          <div className={`w-full h-2.5 rounded-full ${th === 'light' ? 'bg-neutral-200' : 'bg-neutral-800'}`}>
                            <div className={`h-2.5 rounded-full transition-all ${isOver ? 'bg-rose-500' : fill > 75 ? 'bg-amber-500' : 'bg-emerald-500'}`} style={{ width: `${Math.min(fill, 100)}%` }}></div>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Right: Map card */}
                    {hasCoords ? (
                      <div
                        className={`flex-1 rounded-3xl border shadow-2xl p-4 flex flex-col gap-3 min-h-[300px] md:min-h-0 ${th === 'light' ? 'bg-white border-neutral-200' : 'bg-neutral-900 border-neutral-800'}`}
                      >
                        <div className="flex items-center gap-2 px-2 shrink-0">
                          <MapPin className={`w-4 h-4 ${th === 'light' ? 'text-indigo-600' : 'text-indigo-400'}`} />
                          <span className={`font-black text-xs uppercase tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Location Map</span>
                          <span className={`font-mono text-xs ml-auto ${th === 'light' ? 'text-neutral-400' : 'text-neutral-500'}`}>{Number(m.latitude).toFixed(5)}, {Number(m.longitude).toFixed(5)}</span>
                        </div>
                        <div className="flex-1 rounded-2xl overflow-hidden border border-neutral-200/50 dark:border-neutral-800/80">
                          <PopupMap lat={Number(m.latitude)} lng={Number(m.longitude)} label={m.mine_name || 'Mine'} theme={th} />
                        </div>
                      </div>
                    ) : (
                      <div className={`flex-1 rounded-3xl border p-8 flex items-center justify-center ${th === 'light' ? 'bg-white border-neutral-200' : 'bg-neutral-900 border-neutral-800'}`}>
                        <p className={`text-sm font-semibold ${th === 'light' ? 'text-neutral-400' : 'text-neutral-600'}`}>No location coordinates available.</p>
                      </div>
                    )}
                  </motion.div>
                );
              })()}


              {/* ── HARDWARE POPUP (side-by-side with map) ── */}
              {/* ── HARDWARE POPUP ── */}
              {popupType === 'hardware' && (() => {
                const h = popupItem;
                const owner = dbUsers.find(u => u.user_id === h.user_id || u.id === h.user_id);
                const fill = h.maximum_cubes > 0 ? Math.round((h.current_cubes / h.maximum_cubes) * 100) : 0;
                const isOver = h.current_cubes > h.maximum_cubes;
                const hasCoords = h.latitude != null && h.longitude != null;
                return (
                  <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.16 }}
                    className="flex flex-col md:flex-row gap-6 w-full max-w-5xl max-h-[90vh] items-stretch justify-center relative p-4"
                    onClick={e => e.stopPropagation()}
                  >
                    {/* Left: Info card */}
                    <div
                      className={`relative flex-1 rounded-3xl border shadow-2xl p-6 sm:p-8 flex flex-col justify-between gap-5 overflow-y-auto ${th === 'light' ? 'bg-white border-neutral-200' : 'bg-neutral-900 border-neutral-800'}`}
                    >
                      <button
                        onClick={() => { setPopupItem(null); setPopupType(null); }}
                        className={`absolute top-4 right-4 p-2 rounded-xl border transition-colors cursor-pointer z-20 ${th === 'light' ? 'border-neutral-200 bg-white hover:bg-neutral-100 text-neutral-600' : 'border-neutral-800 bg-neutral-950 hover:bg-neutral-800 text-neutral-400 hover:text-white'}`}
                      >
                        <X className="w-4 h-4" />
                      </button>
                      <div className="flex flex-col gap-5">
                        <div className="flex items-center gap-3 pr-8">
                          <div className={`w-12 h-12 rounded-2xl flex items-center justify-center shrink-0 ${th === 'light' ? 'bg-indigo-100' : 'bg-indigo-500/15'}`}>
                            <Building2 className={`w-6 h-6 ${th === 'light' ? 'text-indigo-700' : 'text-indigo-400'}`} />
                          </div>
                          <div>
                            <span className={`text-[10px] font-black uppercase tracking-wider ${th === 'light' ? 'text-indigo-600' : 'text-indigo-400'}`}>Hardware Store</span>
                            <h2 className={`text-xl font-black leading-snug ${th === 'light' ? 'text-neutral-900' : 'text-white'}`}>{h.hardware_name || 'Unnamed Store'}</h2>
                          </div>
                        </div>
                        <div className="grid grid-cols-2 gap-3">
                          {[
                            { label: 'Current Stock', value: `${h.current_cubes ?? 'N/A'} m³`, color: isOver ? (th === 'light' ? 'text-rose-700' : 'text-rose-400') : '' },
                            { label: 'Maximum Capacity', value: `${h.maximum_cubes ?? 'N/A'} m³` },
                            { label: 'Owner', value: owner ? (owner.name || 'Unknown') : 'Unassigned' },
                            { label: 'Owner NIC', value: owner ? (owner.nic || 'N/A') : 'N/A' },
                          ].map(row => (
                            <div key={row.label} className={`p-3.5 rounded-2xl border flex flex-col gap-1 ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                              <span className={`text-[9px] uppercase font-black tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>{row.label}</span>
                              <span className={`font-bold text-sm ${row.color || (th === 'light' ? 'text-neutral-800' : 'text-neutral-200')}`}>{row.value}</span>
                            </div>
                          ))}
                          {/* Hardware ID with copy */}
                          <div className={`col-span-2 p-3.5 rounded-2xl border flex flex-col gap-1 ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                            <span className={`text-[9px] uppercase font-black tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>Hardware ID</span>
                            <div className="flex items-center gap-2">
                              <span className={`font-mono text-xs truncate ${th === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>{h.hardware_id || 'N/A'}</span>
                              {h.hardware_id && <CopyBtn id={h.hardware_id} />}
                            </div>
                          </div>
                        </div>
                        {/* Capacity bar */}
                        <div className={`p-4 rounded-2xl border ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                          <div className="flex justify-between mb-2 text-xs font-bold">
                            <span className={th === 'light' ? 'text-neutral-600' : 'text-neutral-400'}>Capacity Fill</span>
                            <span className={isOver ? (th === 'light' ? 'text-rose-700' : 'text-rose-400') : (th === 'light' ? 'text-emerald-700' : 'text-emerald-400')}>{fill}% {isOver ? '⚠ OVERLOADED' : ''}</span>
                          </div>
                          <div className={`w-full h-2.5 rounded-full ${th === 'light' ? 'bg-neutral-200' : 'bg-neutral-800'}`}>
                            <div className={`h-2.5 rounded-full transition-all ${isOver ? 'bg-rose-500' : fill > 75 ? 'bg-amber-500' : 'bg-emerald-500'}`} style={{ width: `${Math.min(fill, 100)}%` }}></div>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Right: Map card */}
                    {hasCoords ? (
                      <div
                        className={`flex-1 rounded-3xl border shadow-2xl p-4 flex flex-col gap-3 min-h-[300px] md:min-h-0 ${th === 'light' ? 'bg-white border-neutral-200' : 'bg-neutral-900 border-neutral-800'}`}
                      >
                        <div className="flex items-center gap-2 px-2 shrink-0">
                          <MapPin className={`w-4 h-4 ${th === 'light' ? 'text-indigo-600' : 'text-indigo-400'}`} />
                          <span className={`font-black text-xs uppercase tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Location Map</span>
                          <span className={`font-mono text-xs ml-auto ${th === 'light' ? 'text-neutral-400' : 'text-neutral-500'}`}>{Number(h.latitude).toFixed(5)}, {Number(h.longitude).toFixed(5)}</span>
                        </div>
                        <div className="flex-1 rounded-2xl overflow-hidden border border-neutral-200/50 dark:border-neutral-800/80">
                          <PopupMap lat={Number(h.latitude)} lng={Number(h.longitude)} label={h.hardware_name || 'Hardware Store'} theme={th} />
                        </div>
                      </div>
                    ) : (
                      <div className={`flex-1 rounded-3xl border p-8 flex items-center justify-center ${th === 'light' ? 'bg-white border-neutral-200' : 'bg-neutral-900 border-neutral-800'}`}>
                        <p className={`text-sm font-semibold ${th === 'light' ? 'text-neutral-400' : 'text-neutral-600'}`}>No location coordinates available.</p>
                      </div>
                    )}
                  </motion.div>
                );
              })()}

              {/* ── TRUCK POPUP ── */}
              {popupType === 'truck' && (() => {
                const t = popupItem;
                const owner = dbUsers.find(u => u.user_id === t.user_id || u.id === t.user_id);
                return (
                  <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.15 }}
                    className={`relative w-full max-w-2xl max-h-[90vh] overflow-y-auto rounded-3xl border shadow-2xl p-6 sm:p-8 flex flex-col gap-5 ${th === 'light' ? 'bg-white border-neutral-200' : 'bg-neutral-900 border-neutral-800'}`}
                    onClick={e => e.stopPropagation()}
                  >
                    <button
                      onClick={() => { setPopupItem(null); setPopupType(null); }}
                      className={`absolute top-4 right-4 p-2 rounded-xl border transition-colors cursor-pointer z-10 ${th === 'light' ? 'border-neutral-200 bg-white hover:bg-neutral-100 text-neutral-600' : 'border-neutral-800 bg-neutral-950 hover:bg-neutral-800 text-neutral-400 hover:text-white'}`}
                    >
                      <X className="w-4 h-4" />
                    </button>
                    <div className="flex items-center gap-3">
                      <div className={`w-12 h-12 rounded-2xl flex items-center justify-center ${th === 'light' ? 'bg-amber-100' : 'bg-amber-500/15'}`}>
                        <Truck className={`w-6 h-6 ${th === 'light' ? 'text-amber-700' : 'text-amber-400'}`} />
                      </div>
                      <div>
                        <span className={`text-[10px] font-black uppercase tracking-wider ${th === 'light' ? 'text-amber-600' : 'text-amber-400'}`}>Truck</span>
                        <h2 className={`text-xl font-black leading-snug font-mono ${th === 'light' ? 'text-neutral-900' : 'text-white'}`}>{t.number_plate || 'Unknown Plate'}</h2>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      {[
                        { label: 'Number Plate', value: t.number_plate || 'N/A' },
                        { label: 'Capacity', value: t.capacity != null ? `${t.capacity} m³` : 'N/A' },
                        { label: 'Owner', value: owner ? (owner.name || 'Unknown') : 'Unassigned' },
                        { label: 'Owner NIC', value: owner ? (owner.nic || 'N/A') : 'N/A' },
                      ].map(row => (
                        <div key={row.label} className={`p-3.5 rounded-2xl border flex flex-col gap-1 ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                          <span className={`text-[9px] uppercase font-black tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>{row.label}</span>
                          <span className={`font-bold text-sm ${th === 'light' ? 'text-neutral-800' : 'text-neutral-200'}`}>{row.value}</span>
                        </div>
                      ))}
                    </div>
                  </motion.div>
                );
              })()}
            </motion.div>
          )}
        </AnimatePresence>

        {/* ── Sub-item popup (mine/hardware/truck inside user popup) ── */}
        <AnimatePresence>
          {subPopupItem && subPopupType && (
            <motion.div
              key="sub-popup-backdrop"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-[100000] flex items-center justify-center p-4"
              style={{ backdropFilter: 'blur(5px)', WebkitBackdropFilter: 'blur(5px)', backgroundColor: th === 'light' ? 'rgba(255,255,255,0.65)' : 'rgba(10,10,14,0.82)' }}
              onClick={e => { if (e.target === e.currentTarget) { setSubPopupItem(null); setSubPopupType(null); } }}
            >
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.15 }}
                className={`relative w-full max-h-[85vh] overflow-y-auto rounded-3xl border shadow-2xl p-6 flex flex-col gap-4 ${(subPopupType === 'mine' || subPopupType === 'hardware') ? 'max-w-5xl' : 'max-w-md'
                  } ${th === 'light' ? 'bg-white border-neutral-200' : 'bg-neutral-900 border-neutral-800'}`}
                onClick={e => e.stopPropagation()}
              >
                <button onClick={() => { setSubPopupItem(null); setSubPopupType(null); }} className={`absolute top-4 right-4 p-2 rounded-xl border transition-colors cursor-pointer z-20 ${th === 'light' ? 'border-neutral-200 bg-white hover:bg-neutral-100 text-neutral-600' : 'border-neutral-800 bg-neutral-950 hover:bg-neutral-800 text-neutral-400'}`}>
                  <X className="w-4 h-4" />
                </button>

                {subPopupType === 'mine' && (() => {
                  const m = subPopupItem;
                  const fill = m.maximum_cubes > 0 ? Math.round((m.current_cubes / m.maximum_cubes) * 100) : 0;
                  const isOver = m.current_cubes > m.maximum_cubes;
                  const hasCoords = m.latitude != null && m.longitude != null;
                  return (
                    <div className="flex flex-col md:flex-row gap-6 items-stretch justify-center">
                      {/* Left: details */}
                      <div className="flex-1 flex flex-col gap-4">
                        <div className="flex items-center gap-3 pr-8">
                          <div className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${th === 'light' ? 'bg-emerald-100' : 'bg-emerald-500/15'}`}><HardHat className={`w-5 h-5 ${th === 'light' ? 'text-emerald-700' : 'text-emerald-400'}`} /></div>
                          <div><span className={`text-[10px] font-black uppercase tracking-wider ${th === 'light' ? 'text-emerald-600' : 'text-emerald-400'}`}>Mine</span><h3 className={`text-lg font-black ${th === 'light' ? 'text-neutral-900' : 'text-white'}`}>{m.mine_name}</h3></div>
                        </div>
                        <div className="grid grid-cols-2 gap-2.5">
                          {[{ label: 'Current Stock', value: `${m.current_cubes} m³`, hl: isOver }, { label: 'Max Capacity', value: `${m.maximum_cubes} m³` }].map(r => (
                            <div key={r.label} className={`p-3 rounded-xl border flex flex-col gap-0.5 ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                              <span className={`text-[9px] uppercase font-black tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>{r.label}</span>
                              <span className={`font-bold text-sm ${r.hl ? (th === 'light' ? 'text-rose-700' : 'text-rose-400') : (th === 'light' ? 'text-neutral-800' : 'text-neutral-200')}`}>{r.value}</span>
                            </div>
                          ))}
                          <div className={`col-span-2 p-3 rounded-xl border flex flex-col gap-0.5 ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                            <span className={`text-[9px] uppercase font-black tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>Mine ID</span>
                            <div className="flex items-center gap-2">
                              <span className={`font-mono text-xs truncate ${th === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>{m.mine_id || 'N/A'}</span>
                              {m.mine_id && <CopyBtn id={m.mine_id} />}
                            </div>
                          </div>
                        </div>
                        <div className={`p-3 rounded-xl border ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                          <div className="flex justify-between mb-1.5 text-xs font-bold"><span className={th === 'light' ? 'text-neutral-600' : 'text-neutral-400'}>Fill Level</span><span className={isOver ? (th === 'light' ? 'text-rose-700' : 'text-rose-400') : (th === 'light' ? 'text-emerald-700' : 'text-emerald-400')}>{fill}%</span></div>
                          <div className={`w-full h-2 rounded-full ${th === 'light' ? 'bg-neutral-200' : 'bg-neutral-800'}`}><div className={`h-2 rounded-full ${isOver ? 'bg-rose-500' : fill > 75 ? 'bg-amber-500' : 'bg-emerald-500'}`} style={{ width: `${Math.min(fill, 100)}%` }}></div></div>
                        </div>
                      </div>

                      {/* Right: Map */}
                      {hasCoords ? (
                        <div className={`flex-1 rounded-2xl p-4 flex flex-col gap-3 min-h-[300px] md:min-h-0 ${th === 'light' ? 'bg-neutral-50' : 'bg-neutral-950'}`}>
                          <div className="flex items-center gap-2 shrink-0">
                            <MapPin className={`w-4 h-4 ${th === 'light' ? 'text-indigo-600' : 'text-indigo-400'}`} />
                            <span className={`font-black text-xs uppercase tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Location Map</span>
                            <span className={`font-mono text-xs ml-auto ${th === 'light' ? 'text-neutral-400' : 'text-neutral-500'}`}>{Number(m.latitude).toFixed(5)}, {Number(m.longitude).toFixed(5)}</span>
                          </div>
                          <div className="flex-1 rounded-xl overflow-hidden border border-neutral-200/50 dark:border-neutral-800/80">
                            <PopupMap lat={Number(m.latitude)} lng={Number(m.longitude)} label={m.mine_name || 'Mine'} theme={th} />
                          </div>
                        </div>
                      ) : (
                        <div className={`flex-1 rounded-2xl p-8 flex items-center justify-center ${th === 'light' ? 'bg-neutral-50' : 'bg-neutral-950'}`}>
                          <p className={`text-xs text-center ${th === 'light' ? 'text-neutral-400' : 'text-neutral-600'}`}>No coordinates available for map.</p>
                        </div>
                      )}
                    </div>
                  );
                })()}

                {subPopupType === 'hardware' && (() => {
                  const h = subPopupItem;
                  const fill = h.maximum_cubes > 0 ? Math.round((h.current_cubes / h.maximum_cubes) * 100) : 0;
                  const isOver = h.current_cubes > h.maximum_cubes;
                  const hasCoords = h.latitude != null && h.longitude != null;
                  return (
                    <div className="flex flex-col md:flex-row gap-6 items-stretch justify-center">
                      {/* Left: details */}
                      <div className="flex-1 flex flex-col gap-4">
                        <div className="flex items-center gap-3 pr-8">
                          <div className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${th === 'light' ? 'bg-indigo-100' : 'bg-indigo-500/15'}`}><Building2 className={`w-5 h-5 ${th === 'light' ? 'text-indigo-700' : 'text-indigo-400'}`} /></div>
                          <div><span className={`text-[10px] font-black uppercase tracking-wider ${th === 'light' ? 'text-indigo-600' : 'text-indigo-400'}`}>Hardware Store</span><h3 className={`text-lg font-black ${th === 'light' ? 'text-neutral-900' : 'text-white'}`}>{h.hardware_name}</h3></div>
                        </div>
                        <div className="grid grid-cols-2 gap-2.5">
                          {[{ label: 'Current Stock', value: `${h.current_cubes} m³`, hl: isOver }, { label: 'Max Capacity', value: `${h.maximum_cubes} m³` }].map(r => (
                            <div key={r.label} className={`p-3 rounded-xl border flex flex-col gap-0.5 ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                              <span className={`text-[9px] uppercase font-black tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>{r.label}</span>
                              <span className={`font-bold text-sm ${r.hl ? (th === 'light' ? 'text-rose-700' : 'text-rose-400') : (th === 'light' ? 'text-neutral-800' : 'text-neutral-200')}`}>{r.value}</span>
                            </div>
                          ))}
                          <div className={`col-span-2 p-3 rounded-xl border flex flex-col gap-0.5 ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                            <span className={`text-[9px] uppercase font-black tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>Hardware ID</span>
                            <div className="flex items-center gap-2">
                              <span className={`font-mono text-xs truncate ${th === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>{h.hardware_id || 'N/A'}</span>
                              {h.hardware_id && <CopyBtn id={h.hardware_id} />}
                            </div>
                          </div>
                        </div>
                        <div className={`p-3 rounded-xl border ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                          <div className="flex justify-between mb-1.5 text-xs font-bold"><span className={th === 'light' ? 'text-neutral-600' : 'text-neutral-400'}>Fill Level</span><span className={isOver ? (th === 'light' ? 'text-rose-700' : 'text-rose-400') : (th === 'light' ? 'text-emerald-700' : 'text-emerald-400')}>{fill}%</span></div>
                          <div className={`w-full h-2 rounded-full ${th === 'light' ? 'bg-neutral-200' : 'bg-neutral-800'}`}><div className={`h-2 rounded-full ${isOver ? 'bg-rose-500' : fill > 75 ? 'bg-amber-500' : 'bg-emerald-500'}`} style={{ width: `${Math.min(fill, 100)}%` }}></div></div>
                        </div>
                      </div>

                      {/* Right: Map */}
                      {hasCoords ? (
                        <div className={`flex-1 rounded-2xl p-4 flex flex-col gap-3 min-h-[300px] md:min-h-0 ${th === 'light' ? 'bg-neutral-50' : 'bg-neutral-950'}`}>
                          <div className="flex items-center gap-2 shrink-0">
                            <MapPin className={`w-4 h-4 ${th === 'light' ? 'text-indigo-600' : 'text-indigo-400'}`} />
                            <span className={`font-black text-xs uppercase tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Location Map</span>
                            <span className={`font-mono text-xs ml-auto ${th === 'light' ? 'text-neutral-400' : 'text-neutral-500'}`}>{Number(h.latitude).toFixed(5)}, {Number(h.longitude).toFixed(5)}</span>
                          </div>
                          <div className="flex-1 rounded-xl overflow-hidden border border-neutral-200/50 dark:border-neutral-800/80">
                            <PopupMap lat={Number(h.latitude)} lng={Number(h.longitude)} label={h.hardware_name || 'Hardware Store'} theme={th} />
                          </div>
                        </div>
                      ) : (
                        <div className={`flex-1 rounded-2xl p-8 flex items-center justify-center ${th === 'light' ? 'bg-neutral-50' : 'bg-neutral-950'}`}>
                          <p className={`text-xs text-center ${th === 'light' ? 'text-neutral-400' : 'text-neutral-600'}`}>No coordinates available for map.</p>
                        </div>
                      )}
                    </div>
                  );
                })()}

                {subPopupType === 'truck' && (() => {
                  const t = subPopupItem;
                  return (
                    <div className="p-6 flex flex-col gap-4">
                      <div className="flex items-center gap-3 pr-8">
                        <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${th === 'light' ? 'bg-amber-100' : 'bg-amber-500/15'}`}><Truck className={`w-5 h-5 ${th === 'light' ? 'text-amber-700' : 'text-amber-400'}`} /></div>
                        <div><span className={`text-[10px] font-black uppercase tracking-wider ${th === 'light' ? 'text-amber-600' : 'text-amber-400'}`}>Truck</span><h3 className={`text-lg font-black font-mono ${th === 'light' ? 'text-neutral-900' : 'text-white'}`}>{t.number_plate || 'Unknown'}</h3></div>
                      </div>
                      <div className="grid grid-cols-2 gap-2.5">
                        {[{ label: 'Number Plate', value: t.number_plate || 'N/A' }, { label: 'Capacity', value: t.capacity != null ? `${t.capacity} m³` : 'N/A' }].map(r => (
                          <div key={r.label} className={`p-3 rounded-xl border flex flex-col gap-0.5 ${th === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                            <span className={`text-[9px] uppercase font-black tracking-wider ${th === 'light' ? 'text-neutral-500' : 'text-neutral-500'}`}>{r.label}</span>
                            <span className={`font-bold text-sm ${th === 'light' ? 'text-neutral-800' : 'text-neutral-200'}`}>{r.value}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  );
                })()}
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    );
  };



  const renderRegister = () => {
    return (
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 w-full">
        {/* Form Section */}
        <div className={`lg:col-span-8 p-6 sm:p-8 rounded-3xl shadow-2xl flex flex-col gap-6 relative overflow-hidden border site-reg-card transition-all duration-300 ${theme === 'light'
          ? 'bg-white border-neutral-200 shadow-md'
          : 'bg-neutral-900 border-neutral-800 shadow-2xl'
          }`}>
          <div>
            <span className="px-3.5 py-1 bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 text-[10px] font-black rounded-full border border-indigo-500/20 uppercase tracking-widest">
              REGULATION REGISTRY
            </span>
            <h1 className={`text-3xl font-black mt-4 tracking-tight transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Register New Site</h1>
            <p className={`text-sm max-w-xl mt-2 leading-relaxed transition-colors ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
              Add new sand quarries, aggregate mines, or hardware distribution hubs to the active GSMB telemetry and compliance database.
            </p>
          </div>

          {regSuccess && (
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              className={`p-4 rounded-2xl flex items-start gap-3 border ${theme === 'light' ? 'bg-emerald-50 border-emerald-200' : 'bg-emerald-500/10 border-emerald-500/20'}`}
            >
              <CheckCircle2 className={`w-5 h-5 shrink-0 mt-0.5 ${theme === 'light' ? 'text-emerald-600' : 'text-emerald-400'}`} />
              <div>
                <strong className={`text-sm font-bold block ${theme === 'light' ? 'text-emerald-900' : 'text-white'}`}>Site registered successfully!</strong>
                <span className={`text-xs ${theme === 'light' ? 'text-emerald-800' : 'text-emerald-300/80'}`}>
                  The node has been written to the central Geological Survey & Mines Bureau database and is now live on the telemetry dashboard.
                </span>
              </div>
            </motion.div>
          )}

          {regError && (
            <div className={`p-4 rounded-2xl flex items-start gap-3 border ${theme === 'light' ? 'bg-rose-50 border-rose-200' : 'bg-rose-500/10 border-rose-500/20'}`}>
              <XCircle className={`w-5 h-5 shrink-0 mt-0.5 ${theme === 'light' ? 'text-rose-600' : 'text-rose-400'}`} />
              <div>
                <strong className={`text-sm font-bold block ${theme === 'light' ? 'text-rose-900' : 'text-white'}`}>Registration Failed</strong>
                <span className={`text-xs ${theme === 'light' ? 'text-rose-800' : 'text-rose-300/80'}`}>{regError}</span>
              </div>
            </div>
          )}

          <form onSubmit={handleRegisterSubmit} className="flex flex-col gap-5">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* Node ID */}
              <div className="flex flex-col gap-1.5">
                <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Node / Location ID</label>
                <input
                  required
                  type="text"
                  placeholder="e.g. 1d9a8d96-6f43-4e67-b74f-f3d0f9e8f08c"
                  value={regId}
                  onChange={(e) => setRegId(e.target.value.toUpperCase())}
                  className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 font-mono transition-colors border ${theme === 'light'
                    ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                    : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                    }`}
                />
                <span className={`text-[10px] ${theme === 'light' ? 'text-neutral-400' : 'text-neutral-500'}`}>Unique UUID identifier for database lookups.</span>
              </div>

              {/* Site Type */}
              <div className="flex flex-col gap-1.5">
                <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Operational Node Type</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      setRegType('MINE');
                      setRegMaxCapacity('100');
                    }}
                    className={`py-2 px-3 rounded-xl border text-xs font-bold uppercase transition-all flex items-center justify-center gap-1.5 ${regType === 'MINE'
                      ? 'bg-indigo-600/15 border-indigo-500 text-indigo-600 dark:text-white'
                      : theme === 'light'
                        ? 'bg-white border-neutral-200 text-neutral-600 hover:text-neutral-900 hover:border-neutral-300'
                        : 'bg-neutral-950 border-neutral-800 text-neutral-400 hover:text-white hover:border-neutral-700'
                      }`}
                  >
                    <HardHat className="w-3.5 h-3.5" />
                    Mine / Quarry
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setRegType('HARDWARE');
                      setRegMaxCapacity('20');
                    }}
                    className={`py-2 px-3 rounded-xl border text-xs font-bold uppercase transition-all flex items-center justify-center gap-1.5 ${regType === 'HARDWARE'
                      ? 'bg-indigo-600/15 border-indigo-500 text-indigo-600 dark:text-white'
                      : theme === 'light'
                        ? 'bg-white border-neutral-200 text-neutral-600 hover:text-neutral-900 hover:border-neutral-300'
                        : 'bg-neutral-950 border-neutral-800 text-neutral-400 hover:text-white hover:border-neutral-700'
                      }`}
                  >
                    <Building2 className="w-3.5 h-3.5" />
                    Hardware Store
                  </button>
                </div>
              </div>
            </div>

            {/* Site Name */}
            <div className="flex flex-col gap-1.5">
              <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Site Name / Title</label>
              <input
                required
                type="text"
                placeholder="e.g. Anuradhapura Aggregate Quarry"
                value={regName}
                onChange={(e) => setRegName(e.target.value)}
                className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 transition-colors border ${theme === 'light'
                  ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                  : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                  }`}
              />
            </div>

            {/* Owner's NIC */}
            <div className="flex flex-col gap-1.5">
              <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Owner's NIC / National Identity Card</label>
              <input
                required
                type="text"
                placeholder="e.g. 981234567V or 199812345678"
                value={regUserNic}
                onChange={(e) => setRegUserNic(e.target.value)}
                className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 transition-colors border ${theme === 'light'
                  ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                  : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                  }`}
              />
              <span className={`text-[10px] ${theme === 'light' ? 'text-neutral-400' : 'text-neutral-500'}`}>Must match a registered user account NIC.</span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* Current Stock */}
              <div className="flex flex-col gap-1.5">
                <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Current Stock (m³)</label>
                <input
                  required
                  type="number"
                  min="0"
                  value={regInventory}
                  onChange={(e) => setRegInventory(e.target.value)}
                  className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 font-mono transition-colors border ${theme === 'light'
                    ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                    : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                    }`}
                />
              </div>

              {/* Max Capacity */}
              <div className="flex flex-col gap-1.5">
                <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Maximum Capacity (m³)</label>
                <input
                  required
                  type="number"
                  min="1"
                  value={regMaxCapacity}
                  onChange={(e) => setRegMaxCapacity(e.target.value)}
                  className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 font-mono transition-colors border ${theme === 'light'
                    ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                    : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                    }`}
                />
                <span className={`text-[10px] ${theme === 'light' ? 'text-neutral-400' : 'text-neutral-500'}`}>
                  {regType === 'MINE' ? 'Statutory default is 100 m³' : 'Statutory default is 20 m³'}
                </span>
              </div>
            </div>

            {/* Coordinates Selection & Presets */}
            <div className={`border rounded-2xl p-4 transition-colors flex flex-col gap-3 ${theme === 'light' ? 'border-neutral-200 bg-neutral-50/50' : 'border-neutral-800/80 bg-neutral-950/40'}`}>
              <span className={`text-[9px] font-black tracking-wider uppercase ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>District Presets & Telemetry Coordinates</span>

              <div className="flex flex-wrap gap-1.5">
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
                    onClick={() => {
                      setRegLat(preset.lat);
                      setRegLng(preset.lng);
                    }}
                    className={`px-3 py-1.5 rounded-lg text-[10px] font-bold border transition-all cursor-pointer ${regLat === preset.lat && regLng === preset.lng
                      ? 'bg-indigo-600/20 border-indigo-500 text-indigo-600 dark:text-white'
                      : theme === 'light'
                        ? 'bg-white border-neutral-200 text-neutral-600 hover:text-neutral-900 hover:border-neutral-300'
                        : 'bg-neutral-900 border-neutral-800 text-neutral-400 hover:text-white hover:border-neutral-700'
                      }`}
                  >
                    {preset.name}
                  </button>
                ))}
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-1">
                <div className="flex flex-col gap-1">
                  <label className="text-[9px] font-bold text-neutral-500 uppercase">Latitude</label>
                  <input
                    required
                    type="text"
                    value={regLat}
                    onChange={(e) => setRegLat(e.target.value)}
                    className={`rounded-lg p-2 text-xs font-mono transition-colors focus:outline-none border ${theme === 'light' ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-1 focus:ring-indigo-500' : 'bg-neutral-950 border-neutral-800 text-neutral-200'}`}
                  />
                </div>
                <div className="flex flex-col gap-1">
                  <label className="text-[9px] font-bold text-neutral-500 uppercase">Longitude</label>
                  <input
                    required
                    type="text"
                    value={regLng}
                    onChange={(e) => setRegLng(e.target.value)}
                    className={`rounded-lg p-2 text-xs font-mono transition-colors focus:outline-none border ${theme === 'light' ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-1 focus:ring-indigo-500' : 'bg-neutral-950 border-neutral-800 text-neutral-200'}`}
                  />
                </div>
              </div>
            </div>

            {/* Warning Box for Overload */}
            {Number(regInventory) > Number(regMaxCapacity) && (
              <div className="p-3 bg-rose-500/10 border border-rose-500/20 rounded-xl flex items-center gap-2 text-xs text-rose-300 animate-pulse">
                <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0" />
                <span>
                  <strong>Overload Warning:</strong> Current stock ({regInventory} m³) exceeds maximum allowed capacity ({regMaxCapacity} m³). This site will be flagged as <strong>high warning (overloaded)</strong> on the portal dashboard.
                </span>
              </div>
            )}

            {/* Register action */}
            <div className="flex justify-end gap-3 mt-2">
              <button
                type="button"
                onClick={() => setActivePage('dashboard')}
                className={`px-5 py-2.5 rounded-xl text-xs font-semibold transition-all cursor-pointer border ${theme === 'light'
                  ? 'bg-white hover:bg-neutral-100 text-neutral-700 border-neutral-200'
                  : 'bg-neutral-950 hover:bg-neutral-800 text-neutral-300 hover:text-white border-neutral-800 hover:border-neutral-700'
                  }`}
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={regSubmitting}
                className="px-6 py-2.5 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white rounded-xl text-xs font-bold transition-all cursor-pointer shadow-md shadow-indigo-600/25 flex items-center gap-1.5"
              >
                {regSubmitting ? (
                  <>
                    <RotateCw className="w-3.5 h-3.5 animate-spin" />
                    Registering Site...
                  </>
                ) : (
                  <>
                    <Send className="w-3.5 h-3.5" />
                    Complete Registration
                  </>
                )}
              </button>
            </div>
          </form>
          <div className="absolute right-[-40px] bottom-[-40px] w-64 h-64 bg-indigo-500/[0.03] rounded-full blur-3xl"></div>
        </div>

        {/* Guide Card Column */}
        <div className="lg:col-span-4 flex flex-col gap-6">
          <div className={`p-6 rounded-3xl flex flex-col gap-4 border transition-all ${theme === 'light'
            ? 'bg-white border-neutral-200 shadow-md'
            : 'bg-neutral-900 border-neutral-800 shadow-xl'
            }`}>
            <span className="text-[10px] text-indigo-600 dark:text-indigo-400 font-black tracking-widest uppercase font-bold">REGULATORY COMPLIANCE</span>
            <h2 className={`text-xl font-bold tracking-tight transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Capacity Standards</h2>
            <p className={`text-xs leading-relaxed transition-colors ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
              National aggregate guidelines govern the maximum capacity values configured on central telemetry nodes:
            </p>

            <div className={`border rounded-2xl p-4 flex flex-col gap-3 transition-colors ${theme === 'light' ? 'border-neutral-200 bg-neutral-50/50' : 'border-neutral-800/80 bg-neutral-950'}`}>
              <div>
                <h4 className={`text-xs font-extrabold flex items-center gap-1.5 ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>
                  <HardHat className="w-3.5 h-3.5 text-indigo-500 dark:text-indigo-400" />
                  Quarry / Mine standard
                </h4>
                <p className={`text-[11px] mt-1 leading-relaxed ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
                  Mines use a statutory default of 100 m³. Mines are penalized only when they are near empty (disrupting vital logistics supply chains) or overloaded.
                </p>
              </div>

              <hr className={`transition-colors ${theme === 'light' ? 'border-neutral-200' : 'border-neutral-800/80'}`} />

              <div>
                <h4 className={`text-xs font-extrabold flex items-center gap-1.5 ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>
                  <Building2 className="w-3.5 h-3.5 text-emerald-500 dark:text-emerald-400" />
                  Hardware Store limit
                </h4>
                <p className={`text-[11px] mt-1 leading-relaxed ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
                  Hardware stores have strict limits of 20 m³. Stocks exceeding capacity trigger environmental violation flags, and empty stores are completely ignored.
                </p>
              </div>
            </div>
          </div>

          <div className={`p-6 rounded-3xl flex flex-col gap-3 border transition-all ${theme === 'light'
            ? 'bg-white border-neutral-200 shadow-md'
            : 'bg-neutral-900 border-neutral-800 shadow-xl'
            }`}>
            <h3 className={`text-sm font-extrabold transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Need Inspector Dispatch?</h3>
            <p className={`text-xs ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
              If telemetry indicators suggest a node is spoofing coordinate data or operating with revoked mining licenses, immediately initiate an official report.
            </p>
            <button
              onClick={() => setActivePage('contact')}
              className={`mt-2 w-full py-2 text-xs font-bold rounded-xl transition-all cursor-pointer text-center border ${theme === 'light'
                ? 'bg-neutral-100 hover:bg-neutral-200 text-indigo-600 border-neutral-200'
                : 'bg-neutral-950 hover:bg-neutral-800 text-indigo-400 hover:text-white border-neutral-800 hover:border-neutral-700'
                }`}
            >
              File Regulatory Report
            </button>
          </div>
        </div>
      </div>
    );
  };

  const renderAbout = () => {
    return (
      <div className="flex flex-col gap-6 w-full">

        <div className={`rounded-3xl p-8 relative overflow-hidden transition-all duration-300 border ${theme === 'light'
          ? 'bg-white border-neutral-200 shadow-md'
          : 'bg-neutral-900 border-neutral-800 shadow-xl'
          }`}>
          <span className="px-3.5 py-1 bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 text-[10px] font-black rounded-full border border-indigo-500/20 uppercase tracking-widest">
            STATUTORY FRAMEWORK
          </span>
          <h1 className={`text-3xl font-black mt-4 tracking-tight transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Geological Survey & Mines Bureau (GSMB)</h1>
          <p className={`text-sm max-w-2xl mt-2 leading-relaxed transition-colors ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
            Established under the Mines and Minerals Act No. 33 of 1992, the GSMB is the prime authority responsible for regulating mining exploration, license issuance, and safe transit protocols in Sri Lanka.
          </p>
          <div className="absolute right-[-20px] bottom-[-20px] w-48 h-48 bg-indigo-500/[0.03] rounded-full blur-2xl"></div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">

          {/* Protocol Card 1 */}
          <article className={`p-6 rounded-3xl flex flex-col gap-4 border transition-all duration-300 ${theme === 'light'
            ? 'bg-white border-neutral-200 shadow-md'
            : 'bg-neutral-900 border-neutral-800 shadow-lg'
            }`}>
            <div className="w-10 h-10 rounded-xl bg-indigo-600/10 border border-indigo-500/20 flex items-center justify-center">
              <HardHat className="w-5 h-5 text-indigo-500 dark:text-indigo-400" />
            </div>
            <h3 className={`text-lg font-bold transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>License Issuance Guidelines</h3>
            <p className={`text-xs leading-relaxed transition-colors ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
              The Bureau issues mining licenses for industrial minerals, sand, gravel, and construction aggregates. Each licensed quarry or mine undergoes strict environmental assessment audits before being issued a digital regulatory profile in our tracking database.
            </p>
            <ul className={`text-xs space-y-2 mt-2 font-medium transition-colors ${theme === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>
              <li className="flex items-center gap-2">
                <Check className="w-4 h-4 text-indigo-500 dark:text-indigo-400 shrink-0" />
                Category A: Large industrial mining operations.
              </li>
              <li className="flex items-center gap-2">
                <Check className="w-4 h-4 text-indigo-500 dark:text-indigo-400 shrink-0" />
                Category B: Semi-mechanized aggregate locations.
              </li>
              <li className="flex items-center gap-2">
                <Check className="w-4 h-4 text-indigo-500 dark:text-indigo-400 shrink-0" />
                Category C: Artisanal family quarries and sand miners.
              </li>
            </ul>
          </article>

          {/* Protocol Card 2 */}
          <article className={`p-6 rounded-3xl flex flex-col gap-4 border transition-all duration-300 ${theme === 'light'
            ? 'bg-white border-neutral-200 shadow-md'
            : 'bg-neutral-900 border-neutral-800 shadow-lg'
            }`}>
            <div className="w-10 h-10 rounded-xl bg-emerald-600/10 border border-emerald-500/20 flex items-center justify-center">
              <ShieldCheck className="w-5 h-5 text-emerald-500 dark:text-emerald-400" />
            </div>
            <h3 className={`text-lg font-bold transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Preventing Transit Exploitation</h3>
            <p className={`text-xs leading-relaxed transition-colors ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
              Overloading aggregates damages vital provincial road networks and leads to rapid ecological degradation along Sri Lankan riverbeds. To counter this, GSMB enforces standard cargo weight limitations:
            </p>
            <ul className={`text-xs space-y-2 mt-2 font-medium transition-colors ${theme === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>
              <li className="flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-rose-500 dark:text-rose-400 shrink-0" />
                Overload limits: Maximum allowed transport volume is capped at 5.0 cubes.
              </li>
              <li className="flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-amber-500 dark:text-amber-400 shrink-0" />
                Digital Stamps: Electronic permits must detail destination and license plate coordinates.
              </li>
              <li className="flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-indigo-500 dark:text-indigo-400 shrink-0" />
                License Suspension: Mines repeatedly violating loading limits face immediate operational blacklisting.
              </li>
            </ul>
          </article>

          {/* Protocol Card 3 */}
          <article className={`p-6 rounded-3xl md:col-span-2 flex flex-col gap-4 border transition-all duration-300 ${theme === 'light'
            ? 'bg-white border-neutral-200 shadow-md'
            : 'bg-neutral-900 border-neutral-800 shadow-lg'
            }`}>
            <h3 className={`text-lg font-bold flex items-center gap-2 transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>
              <Activity className={`w-5 h-5 animate-pulse ${theme === 'light' ? 'text-indigo-500' : 'text-indigo-400'}`} />
              GeoTrust Telemetry Implementation
            </h3>
            <p className={`text-xs leading-relaxed transition-colors ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
              This GeoTrust digital dashboard represents a critical national security leap, connecting Sri Lanka's central mineral registry directly with satellite telemetry. Every transit truck is monitored from origin mine check-outs to the authorized hardware store destinations. Mismatched unloading zones or cancelled permits automatically trigger inspector dispatches.
            </p>
          </article>

        </div>

      </div>
    );
  };

  const renderContact = () => {
    return (
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 w-full animate-fadeIn">

        {/* Left Column: Office locations and Regional info */}
        <div className="lg:col-span-4 flex flex-col gap-6">

          <div className={`p-6 rounded-3xl flex flex-col gap-4 border transition-all duration-300 ${theme === 'light'
            ? 'bg-white border-neutral-200 shadow-md'
            : 'bg-neutral-900 border-neutral-800 shadow-lg'
            }`}>
            <span className="text-[10px] text-indigo-600 dark:text-indigo-400 font-black tracking-widest uppercase">REGIONAL SUPPORT</span>
            <h2 className={`text-xl font-bold tracking-normal transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Regional Offices</h2>
            <p className={`text-xs leading-relaxed transition-colors ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
              Contact the central headquarters or get in touch with specialized mining inspectors positioned at district administrative offices.
            </p>
          </div>

          {/* Office 1 */}
          <div className={`p-5 rounded-2xl flex flex-col gap-3 border transition-all duration-300 ${theme === 'light'
            ? 'bg-white border-neutral-200 shadow-sm'
            : 'bg-neutral-900 border-neutral-800 shadow-md'
            }`}>
            <h3 className={`text-sm font-extrabold transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Central Head Office</h3>
            <p className={`text-xs ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>No. 569, Epitamulla Road, Pitakotte, Sri Lanka.</p>
            <div className={`flex flex-col gap-1 text-[11px] font-mono transition-colors ${theme === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>
              <span className="flex items-center gap-1.5"><Phone className="w-3 h-3 text-neutral-400" /> +94 11 2886289</span>
              <span className="flex items-center gap-1.5"><Mail className="w-3 h-3 text-neutral-400" /> info@gsmb.gov.lk</span>
            </div>
          </div>

          {/* Office 2 */}
          <div className={`p-5 rounded-2xl flex flex-col gap-3 border transition-all duration-300 ${theme === 'light'
            ? 'bg-white border-neutral-200 shadow-sm'
            : 'bg-neutral-900 border-neutral-800 shadow-md'
            }`}>
            <h3 className={`text-sm font-extrabold transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Kandy District Office</h3>
            <p className={`text-xs ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>No. 12, William Gopallawa Mawatha, Kandy.</p>
            <div className={`flex flex-col gap-1 text-[11px] font-mono transition-colors ${theme === 'light' ? 'text-neutral-700' : 'text-neutral-300'}`}>
              <span className="flex items-center gap-1.5"><Phone className="w-3 h-3 text-neutral-400" /> +94 81 2235901</span>
              <span className="flex items-center gap-1.5"><Mail className="w-3 h-3 text-neutral-400" /> kandy@gsmb.gov.lk</span>
            </div>
          </div>

        </div>

        <div className={`lg:col-span-8 p-6 rounded-3xl shadow-xl flex flex-col gap-6 border incident-report-card transition-all duration-300 ${theme === 'light'
          ? 'bg-white border-neutral-200'
          : 'bg-neutral-900 border-neutral-800'
          }`}>
          <div>
            <p className="text-[10px] font-black text-indigo-600 dark:text-indigo-400 tracking-widest uppercase font-bold">COMPLIANCE REPORTING</p>
            <h2 className={`text-2xl font-black tracking-normal transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Submit Incident Report</h2>
            <p className={`text-xs mt-1 leading-relaxed transition-colors ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
              Submit quarry violations, transport overloading logs, or hardware store registry feedback. Submissions are processed by district inspectors.
            </p>
          </div>

          <form onSubmit={handleFeedbackSubmit} className="flex flex-col gap-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="flex flex-col gap-1">
                <label className={`text-[10px] font-bold uppercase ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Your Name</label>
                <input
                  required
                  type="text"
                  placeholder="Officer Name"
                  value={fbName}
                  onChange={(e) => setFbName(e.target.value)}
                  className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 transition-colors border ${theme === 'light'
                    ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                    : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                    }`}
                />
              </div>
              <div className="flex flex-col gap-1">
                <label className={`text-[10px] font-bold uppercase flex items-center gap-1.5 ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>
                  Your Official Email
                  <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded-full ${theme === 'light' ? 'bg-neutral-100 text-neutral-400' : 'bg-neutral-800 text-neutral-500'}`}>LOCKED</span>
                </label>
                <input
                  readOnly
                  type="email"
                  placeholder="username@gsmb.gov.lk"
                  value={fbEmail}
                  className={`rounded-xl p-3 text-xs border cursor-not-allowed opacity-75 transition-colors ${theme === 'light'
                    ? 'bg-neutral-100 border-neutral-200 text-neutral-600'
                    : 'bg-neutral-900 border-neutral-800 text-neutral-400'
                    }`}
                />
              </div>
            </div>

            <div className="flex flex-col gap-1">
              <label className={`text-[10px] font-bold uppercase ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Incident Topic</label>
              <select
                value={fbSubject}
                onChange={(e) => setFbSubject(e.target.value)}
                className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 cursor-pointer transition-colors border ${theme === 'light'
                  ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                  : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                  }`}
              >
                <option value="Overloading Report">Overloading Volume Violation (&gt; 5 cubes)</option>
                <option value="Coordinate Mismatch Alert">Unloading Location GPS Mismatch</option>
                <option value="Illegal Mining Site">Unlicensed Extraction Quarry Identified</option>
                <option value="General Query">General Administration Query</option>
              </select>
            </div>

            <div className="flex flex-col gap-1 relative">
              <label className={`text-[10px] font-bold uppercase ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Associated Geological / Distribution Node</label>

              {/* Dropdown Toggle Trigger Button */}
              <div
                onClick={() => setIsNodeDropdownOpen(!isNodeDropdownOpen)}
                className={`rounded-xl p-3 text-xs border flex items-center justify-between cursor-pointer transition-colors ${theme === 'light'
                  ? 'bg-white border-neutral-200 text-neutral-800'
                  : 'bg-neutral-950 border-neutral-800 text-neutral-200'
                  }`}
              >
                <span>
                  {fbLocationId
                    ? (() => {
                      const matched = data.records.find(r => r.id === fbLocationId);
                      return matched
                        ? `[${(matched.type || '').toUpperCase()}] ${matched.name || ''} (${matched.region || ''})`
                        : '-- Select Administrative Node --';
                    })()
                    : '-- Select Administrative Node (Auto-assigned if empty) --'
                  }
                </span>
                <ChevronDown className="w-4 h-4 text-neutral-400" />
              </div>

              {/* Dropdown Options Popup */}
              {isNodeDropdownOpen && (
                <div className={`absolute left-0 right-0 top-[100%] mt-1 z-[9999] rounded-2xl border p-3 flex flex-col gap-2 shadow-2xl transition-all ${theme === 'light'
                  ? 'bg-white border-neutral-200 bg-white'
                  : 'bg-neutral-950 border-neutral-900 shadow-black/80'
                  }`}>

                  {/* Search Input Box */}
                  <div className="relative">
                    <Search className="w-3.5 h-3.5 text-neutral-400 absolute left-2.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="text"
                      placeholder="Search nodes by name or district..."
                      value={nodeSearchQuery}
                      onChange={(e) => setNodeSearchQuery(e.target.value)}
                      onClick={(e) => e.stopPropagation()} // Prevent closing dropdown on input click
                      className={`w-full rounded-lg pl-8 pr-3 py-2 text-xs focus:outline-none border ${theme === 'light'
                        ? 'bg-neutral-50 border-neutral-200 text-neutral-800 focus:ring-1 focus:ring-indigo-500'
                        : 'bg-neutral-900 border-neutral-800 text-neutral-200 focus:ring-1 focus:ring-indigo-500'
                        }`}
                    />
                  </div>

                  {/* Scrollable List of Options */}
                  <div className="flex flex-col gap-1 max-h-[200px] overflow-y-auto pr-1">
                    <div
                      onClick={(e) => {
                        e.stopPropagation();
                        setFbLocationId('');
                        setIsNodeDropdownOpen(false);
                        setNodeSearchQuery('');
                      }}
                      className={`p-2 rounded-lg text-xs cursor-pointer hover:bg-indigo-600/10 transition-colors ${!fbLocationId ? 'font-black text-indigo-500 bg-indigo-500/5' : ''}`}
                    >
                      -- Select Administrative Node (Auto-assigned if empty) --
                    </div>
                    {(data.records || []).filter(rec => {
                      const query = nodeSearchQuery.toLowerCase().trim();
                      if (!query) return true;
                      return (rec.name || '').toLowerCase().includes(query) ||
                        (rec.type || '').toLowerCase().includes(query) ||
                        (rec.region || '').toLowerCase().includes(query);
                    }).map((rec) => (
                      <div
                        key={rec.id}
                        onClick={(e) => {
                          e.stopPropagation();
                          setFbLocationId(rec.id);
                          setIsNodeDropdownOpen(false);
                          setNodeSearchQuery('');
                        }}
                        className={`p-2 rounded-lg text-xs cursor-pointer hover:bg-indigo-600/10 transition-colors ${fbLocationId === rec.id ? 'font-black text-indigo-500 bg-indigo-500/5' : ''}`}
                      >
                        <span className="font-bold">[{(rec.type || '').toUpperCase()}]</span> {rec.name || ''} <span className="text-neutral-500">({rec.region || ''})</span>
                      </div>
                    ))}
                    {(data.records || []).filter(rec => {
                      const query = nodeSearchQuery.toLowerCase().trim();
                      if (!query) return true;
                      return (rec.name || '').toLowerCase().includes(query) ||
                        (rec.type || '').toLowerCase().includes(query) ||
                        (rec.region || '').toLowerCase().includes(query);
                    }).length === 0 && (
                        <div className="p-2 text-xs text-neutral-500 text-center">No matching nodes found</div>
                      )}
                  </div>
                </div>
              )}
            </div>

            <div className="flex flex-col gap-1">
              <label className={`text-[10px] font-bold uppercase ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Incident Details & Observations</label>
              <textarea
                required
                rows={4}
                placeholder="Specify licence coordinates, truck plate numbers, and volume load observations..."
                value={fbMessage}
                onChange={(e) => setFbMessage(e.target.value)}
                className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 transition-colors border ${theme === 'light'
                  ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                  : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                  }`}
              ></textarea>
            </div>

            {fbSubmitted ? (
              <div className={`p-4 text-xs flex items-center gap-2 font-semibold border rounded-xl ${theme === 'light' ? 'bg-emerald-50 border-emerald-200 text-emerald-800' : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-300'}`}>
                <CheckCircle2 className={`w-4 h-4 shrink-0 animate-bounce ${theme === 'light' ? 'text-emerald-600' : 'text-emerald-400'}`} />
                Report submitted successfully. Registry dispatched to relevant Regional Office.
              </div>
            ) : (
              <button
                type="submit"
                className="px-6 py-3 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2 cursor-pointer shadow-lg shadow-indigo-600/20"
              >
                <Send className="w-3.5 h-3.5" />
                Send Inspector
              </button>
            )}
          </form>

          {/* Support Active Ticket List */}
          <div className={`flex flex-col gap-3 mt-4 border-t pt-6 ${theme === 'light' ? 'border-neutral-200' : 'border-neutral-800'}`}>
            <h3 className={`text-xs font-bold uppercase tracking-wider flex items-center gap-2 ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>
              <MessageSquare className="w-4 h-4 text-indigo-500 dark:text-indigo-400" /> Active Dispatches
            </h3>

            <div className="flex flex-col gap-3">
              {supportTickets.map((ticket, index) => (
                <div key={index} className={`p-4 rounded-xl flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border transition-colors ${theme === 'light' ? 'bg-neutral-50 border-neutral-200' : 'bg-neutral-950 border-neutral-800'}`}>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-[10px] text-neutral-500 font-bold">{ticket.id}</span>
                      <span className={`px-2 py-0.5 rounded text-[8px] font-black tracking-wider border ${ticket.status === 'RESOLVED' ? (theme === 'light' ? 'bg-emerald-50 text-emerald-800 border-emerald-200' : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20') : (theme === 'light' ? 'bg-rose-50 text-rose-800 border-rose-200' : 'bg-rose-500/10 text-rose-400 border-rose-500/20')}`}>{ticket.status}</span>
                    </div>
                    <h4 className={`text-xs font-extrabold mt-1 ${theme === 'light' ? 'text-neutral-900' : 'text-neutral-200'}`}>{ticket.subject}</h4>
                    <p className={`text-[11px] mt-1 leading-relaxed ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>{ticket.message}</p>
                  </div>
                  <span className={`text-[10px] shrink-0 font-mono ${theme === 'light' ? 'text-neutral-400' : 'text-neutral-500'}`}>{ticket.date}</span>
                </div>
              ))}
            </div>
          </div>

        </div>

      </div>
    );
  };

  const handleUserRegisterSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!userRegName.trim() || !userRegNic.trim() || !userRegEmail.trim() || !userRegPassword.trim()) {
      setUserRegError('All fields are required.');
      return;
    }

    setUserRegSubmitting(true);
    setUserRegError(null);
    setUserRegSuccess(false);

    try {
      // 1. Check if NIC already exists in dbUsers to prevent duplicates
      const isNicDuplicate = dbUsers.some(
        u => String(u.nic || u.nic_number || u.owner_nic || '').trim().toLowerCase() === userRegNic.trim().toLowerCase()
      );
      if (isNicDuplicate) {
        throw new Error(`A user account with NIC "${userRegNic}" already exists.`);
      }

      let generatedUserId = generateUUID();

      // 2. Try to create the user in Supabase Auth
      try {
        const authResponse = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_ANON_KEY,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            email: userRegEmail.trim(),
            password: userRegPassword,
            options: {
              data: {
                full_name: userRegName.trim(),
                nic: userRegNic.trim(),
                role: 'USER'
              }
            }
          })
        });

        const authData = await authResponse.json();
        if (authResponse.ok) {
          generatedUserId = authData.id || authData.user?.id || generatedUserId;
        } else {
          console.warn('Supabase Auth signup failed, falling back to direct database insertion. Error:', authData);
        }
      } catch (authErr) {
        console.warn('Supabase Auth signup network request failed, falling back to direct database insertion. Error:', authErr);
      }

      // 3. Insert user details into public.user_accounts
      const restResponse = await fetch(`${SUPABASE_URL}/rest/v1/user_accounts`, {
        method: 'POST',
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: JSON.stringify({
          user_id: generatedUserId,
          name: userRegName.trim(),
          nic: userRegNic.trim(),
          email: userRegEmail.trim(),
          password_hashed: userRegPassword,
          profile_picture: ''
        })
      });

      if (!restResponse.ok) {
        const restErrText = await restResponse.text();
        let parsedMessage = '';
        try {
          const parsed = JSON.parse(restErrText);
          parsedMessage = parsed.message || parsed.details || restErrText;
        } catch {
          parsedMessage = restErrText;
        }
        throw new Error(parsedMessage || `Supabase database insertion returned status ${restResponse.status}`);
      }

      setUserRegSuccess(true);
      setUserRegName('');
      setUserRegNic('');
      setUserRegEmail('');
      setUserRegPassword('');
      // Reload dbUsers
      await loadData();
    } catch (err: any) {
      console.error('Failed to register user:', err);
      setUserRegError(err.message || 'User registration transaction failed.');
    } finally {
      setUserRegSubmitting(false);
    }
  };

  const renderUsers = () => {
    return (
      <div className="flex flex-col items-center w-full animate-fadeIn">
        {/* Form Section */}
        <div className={`w-full max-w-4xl p-6 sm:p-8 rounded-3xl shadow-2xl flex flex-col gap-6 relative overflow-hidden border user-reg-card transition-all duration-300 ${theme === 'light'
          ? 'bg-white border-neutral-200 shadow-md'
          : 'bg-neutral-900 border-neutral-800 shadow-2xl'
          }`}>
          <div>
            <span className="px-3.5 py-1 bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 text-[10px] font-black rounded-full border border-indigo-500/20 uppercase tracking-widest">
              USER MANAGEMENT
            </span>
            <h1 className={`text-3xl font-black mt-4 tracking-tight transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-white'}`}>Register New User</h1>
            <p className={`text-sm max-w-xl mt-2 leading-relaxed transition-colors ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'}`}>
              Create credentialed operators, miners, or hardware dealers in the central database to link them to operational locations.
            </p>
          </div>

          {userRegSuccess && (
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              className={`p-4 rounded-2xl flex items-start gap-3 border ${theme === 'light' ? 'bg-emerald-50 border-emerald-200' : 'bg-emerald-500/10 border-emerald-500/20'}`}
            >
              <CheckCircle2 className={`w-5 h-5 shrink-0 mt-0.5 ${theme === 'light' ? 'text-emerald-600' : 'text-emerald-400'}`} />
              <div>
                <strong className={`text-sm font-bold block ${theme === 'light' ? 'text-emerald-900' : 'text-white'}`}>User registered successfully!</strong>
                <span className={`text-xs ${theme === 'light' ? 'text-emerald-800' : 'text-emerald-300/80'}`}>
                  The account has been created in Supabase Auth and synced to the Geological Survey & Mines Bureau user list.
                </span>
              </div>
            </motion.div>
          )}

          {userRegError && (
            <div className={`p-4 rounded-2xl flex items-start gap-3 border ${theme === 'light' ? 'bg-rose-50 border-rose-200' : 'bg-rose-500/10 border-rose-500/20'}`}>
              <XCircle className={`w-5 h-5 shrink-0 mt-0.5 ${theme === 'light' ? 'text-rose-600' : 'text-rose-400'}`} />
              <div>
                <strong className={`text-sm font-bold block ${theme === 'light' ? 'text-rose-900' : 'text-white'}`}>User Registration Failed</strong>
                <span className={`text-xs ${theme === 'light' ? 'text-rose-800' : 'text-rose-300/80'}`}>{userRegError}</span>
              </div>
            </div>
          )}

          <form onSubmit={handleUserRegisterSubmit} className="flex flex-col gap-5">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* Full Name */}
              <div className="flex flex-col gap-1.5">
                <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Full Name</label>
                <input
                  required
                  type="text"
                  placeholder="e.g. Priyantha Bandara"
                  value={userRegName}
                  onChange={(e) => setUserRegName(e.target.value)}
                  className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 transition-colors border ${theme === 'light'
                    ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                    : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                    }`}
                />
              </div>

              {/* NIC */}
              <div className="flex flex-col gap-1.5">
                <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>NIC / National Identity Card</label>
                <input
                  required
                  type="text"
                  placeholder="e.g. 981234567V or 199812345678"
                  value={userRegNic}
                  onChange={(e) => setUserRegNic(e.target.value)}
                  className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 transition-colors border ${theme === 'light'
                    ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                    : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                    }`}
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* Email */}
              <div className="flex flex-col gap-1.5">
                <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Email Address</label>
                <input
                  required
                  type="email"
                  placeholder="e.g. operator@geotrust.com"
                  value={userRegEmail}
                  onChange={(e) => setUserRegEmail(e.target.value)}
                  className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 transition-colors border ${theme === 'light'
                    ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                    : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                    }`}
                />
              </div>

              {/* Password */}
              <div className="flex flex-col gap-1.5">
                <label className={`text-[10px] font-black uppercase tracking-wider ${theme === 'light' ? 'text-neutral-500' : 'text-neutral-400'}`}>Temporary Password</label>
                <input
                  required
                  type="password"
                  placeholder="Minimum 6 characters"
                  value={userRegPassword}
                  onChange={(e) => setUserRegPassword(e.target.value)}
                  className={`rounded-xl p-3 text-xs focus:outline-none focus:ring-1 font-mono transition-colors border ${theme === 'light'
                    ? 'bg-white border-neutral-200 text-neutral-800 focus:ring-indigo-500 focus:border-indigo-500'
                    : 'bg-neutral-950 border-neutral-800 text-neutral-200 focus:ring-indigo-500'
                    }`}
                />
              </div>
            </div>


            {/* Register action */}
            <div className="flex justify-end gap-3 mt-2">
              <button
                type="button"
                onClick={() => setActivePage('dashboard')}
                className={`px-5 py-2.5 rounded-xl text-xs font-semibold transition-all cursor-pointer border ${theme === 'light'
                  ? 'bg-white hover:bg-neutral-100 text-neutral-700 border-neutral-200'
                  : 'bg-neutral-950 hover:bg-neutral-800 text-neutral-300 hover:text-white border-neutral-800 hover:border-neutral-700'
                  }`}
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={userRegSubmitting}
                className="px-6 py-2.5 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white rounded-xl text-xs font-bold transition-all cursor-pointer shadow-md shadow-indigo-600/25 flex items-center gap-1.5"
              >
                {userRegSubmitting ? (
                  <>
                    <RotateCw className="w-3.5 h-3.5 animate-spin" />
                    Registering...
                  </>
                ) : (
                  'Register User'
                )}
              </button>
            </div>
          </form>
        </div>
      </div>
    );
  };

  const renderNewRegister = () => {
    return (
      <div className="flex flex-col gap-6 w-full animate-fadeIn">
        {/* Toggle Selector */}
        <div className="flex justify-center mb-2">
          <div className={`p-1.5 rounded-2xl border flex items-center gap-1.5 shadow-sm transition-all duration-300 ${theme === 'light' ? 'bg-white border-neutral-200' : 'bg-neutral-900 border-neutral-800'}`}>
            <button
              onClick={() => setRegisterTab('site')}
              className={`py-2 px-6 rounded-xl text-xs font-bold uppercase transition-all flex items-center gap-2 cursor-pointer ${registerTab === 'site'
                ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/25'
                : theme === 'light'
                  ? 'text-neutral-600 hover:text-neutral-900 hover:bg-neutral-100'
                  : 'text-neutral-400 hover:text-white hover:bg-neutral-800'
                }`}
            >
              <HardHat className="w-3.5 h-3.5" />
              Register Site
            </button>
            <button
              onClick={() => setRegisterTab('user')}
              className={`py-2 px-6 rounded-xl text-xs font-bold uppercase transition-all flex items-center gap-2 cursor-pointer ${registerTab === 'user'
                ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/25'
                : theme === 'light'
                  ? 'text-neutral-600 hover:text-neutral-900 hover:bg-neutral-100'
                  : 'text-neutral-400 hover:text-white hover:bg-neutral-800'
                }`}
            >
              <User className="w-3.5 h-3.5" />
              Register User
            </button>
          </div>
        </div>

        {/* Render Active Subsection */}
        {registerTab === 'site' ? renderRegister() : renderUsers()}
      </div>
    );
  };

  if (authLoading && !authToken) {
    return (
      <div className={`min-h-screen flex flex-col items-center justify-center gap-4 relative overflow-hidden font-sans ${theme === 'light' ? 'bg-white' : 'bg-neutral-950'}`}>
        <div className="fixed inset-0 pointer-events-none z-0">
          <div className="absolute inset-0 bg-[#0a0a0a]"></div>
          <div
            className="absolute inset-0 bg-[linear-gradient(rgba(255,255,255,0.012)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.012)_1px,transparent_1px)] bg-[size:44px_44px]"
            style={{ maskImage: 'radial-gradient(ellipse at center, black, transparent 95%)' }}
          ></div>
        </div>
        <div className="relative z-10 flex flex-col items-center justify-center gap-3">
          <Activity className="w-10 h-10 text-indigo-500 animate-pulse" />
          <span className="text-[10px] text-neutral-400 font-mono tracking-widest">VERIFYING CREDENTIAL TELEMETRY...</span>
        </div>
      </div>
    );
  }

  if (!authToken || !authUser) {
    return renderAuth();
  }

  return (
    <div className={`relative min-h-screen selection:bg-indigo-500 selection:text-white flex flex-col justify-between transition-colors duration-300 ${theme === 'light' ? 'theme-light text-neutral-800 bg-gray-50' : 'text-white bg-neutral-950'
      }`}>

      {/* Premium Fine Bento Grid Background Overlay */}
      <div className="fixed inset-0 pointer-events-none z-0">
        <div className={`absolute inset-0 transition-colors duration-300 ${theme === 'light' ? 'bg-gray-50' : 'bg-[#0a0a0a]'}`}></div>
        <div
          className={`absolute inset-0 transition-colors duration-300 ${theme === 'light'
            ? 'bg-[linear-gradient(rgba(0,0,0,0.015)_1px,transparent_1px),linear-gradient(90deg,rgba(0,0,0,0.015)_1px,transparent_1px)]'
            : 'bg-[linear-gradient(rgba(255,255,255,0.012)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.012)_1px,transparent_1px)]'
            } bg-[size:44px_44px]`}
          style={{ maskImage: 'radial-gradient(ellipse at center, black, transparent 95%)' }}
        ></div>
        <div className={`absolute top-[-20%] left-[-10%] w-[60%] h-[60%] rounded-full blur-[135px] ${theme === 'light' ? 'bg-indigo-500/[0.01]' : 'bg-indigo-500/[0.03]'}`}></div>
        <div className={`absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full blur-[135px] ${theme === 'light' ? 'bg-indigo-500/[0.01]' : 'bg-indigo-500/[0.02]'}`}></div>
      </div>

      <div className="relative z-10 w-full">
        {/* Top Header Navigation */}
        <header className={`border-b backdrop-blur-md sticky top-0 z-[9999] transition-all duration-300 ${theme === 'light' ? 'border-neutral-200 bg-white/80' : 'border-neutral-900 bg-neutral-950/80'
          }`}>
          <div className="max-w-[95%] xl:max-w-[1700px] mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">

            <div className="flex items-center gap-3 cursor-pointer" onClick={() => setActivePage('dashboard')}>
              <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center shadow-lg shadow-indigo-500/25">
                <ShieldAlert className="w-4 h-4 text-white" />
              </div>
              <div>
                <span className={`text-sm font-black tracking-wider uppercase transition-colors ${theme === 'light' ? 'text-neutral-900' : 'text-neutral-100'
                  }`}>GSMB GeoTrust</span>
                <p className="text-[9px] text-indigo-400 font-mono tracking-widest uppercase font-bold">Oversight Portal</p>
              </div>
            </div>

            {/* Navigation links */}
            <nav className={`hidden md:flex items-center gap-2 text-[13px] font-bold uppercase transition-colors ${theme === 'light' ? 'text-neutral-600' : 'text-neutral-400'
              }`}>
              <button
                onClick={() => setActivePage('dashboard')}
                className={`px-5 py-2.5 rounded-2xl transition-all border duration-300 ${activePage === 'dashboard'
                  ? theme === 'light'
                    ? 'text-indigo-700 bg-indigo-50 border-indigo-200/60 font-black shadow-sm'
                    : 'text-white bg-neutral-900 border-neutral-800 shadow-md shadow-black/45'
                  : theme === 'light'
                    ? 'border-transparent hover:text-neutral-900 hover:bg-neutral-200/50'
                    : 'border-transparent hover:text-neutral-200 hover:bg-neutral-900/50'
                  }`}
              >
                Dashboard
              </button>
              <button
                onClick={() => setActivePage('data-explorer')}
                className={`px-5 py-2.5 rounded-2xl transition-all border duration-300 ${activePage === 'data-explorer'
                  ? theme === 'light'
                    ? 'text-indigo-700 bg-indigo-50 border-indigo-200/60 font-black shadow-sm'
                    : 'text-white bg-neutral-900 border-neutral-800 shadow-md shadow-black/45'
                  : theme === 'light'
                    ? 'border-transparent hover:text-neutral-900 hover:bg-neutral-200/50'
                    : 'border-transparent hover:text-neutral-200 hover:bg-neutral-900/50'
                  }`}
              >
                Data Explorer
              </button>
              <button
                onClick={() => setActivePage('registry')}
                className={`px-5 py-2.5 rounded-2xl transition-all border duration-300 ${activePage === 'registry'
                  ? theme === 'light'
                    ? 'text-indigo-700 bg-indigo-50 border-indigo-200/60 font-black shadow-sm'
                    : 'text-white bg-neutral-900 border-neutral-800 shadow-md shadow-black/45'
                  : theme === 'light'
                    ? 'border-transparent hover:text-neutral-900 hover:bg-neutral-200/50'
                    : 'border-transparent hover:text-neutral-200 hover:bg-neutral-900/50'
                  }`}
              >
                Permit List
              </button>
              <button
                onClick={() => setActivePage('new-register')}
                className={`px-5 py-2.5 rounded-2xl transition-all border duration-300 ${activePage === 'new-register'
                  ? theme === 'light'
                    ? 'text-indigo-700 bg-indigo-50 border-indigo-200/60 font-black shadow-sm'
                    : 'text-white bg-neutral-900 border-neutral-800 shadow-md shadow-black/45'
                  : theme === 'light'
                    ? 'border-transparent hover:text-neutral-900 hover:bg-neutral-200/50'
                    : 'border-transparent hover:text-neutral-200 hover:bg-neutral-900/50'
                  }`}
              >
                New Register
              </button>
              <button
                onClick={() => setActivePage('about')}
                className={`px-5 py-2.5 rounded-2xl transition-all border duration-300 ${activePage === 'about'
                  ? theme === 'light'
                    ? 'text-indigo-700 bg-indigo-50 border-indigo-200/60 font-black shadow-sm'
                    : 'text-white bg-neutral-900 border-neutral-800 shadow-md shadow-black/45'
                  : theme === 'light'
                    ? 'border-transparent hover:text-neutral-900 hover:bg-neutral-200/50'
                    : 'border-transparent hover:text-neutral-200 hover:bg-neutral-900/50'
                  }`}
              >
                Guidelines
              </button>
              <button
                onClick={() => setActivePage('contact')}
                className={`px-5 py-2.5 rounded-2xl transition-all border duration-300 ${activePage === 'contact'
                  ? theme === 'light'
                    ? 'text-indigo-700 bg-indigo-50 border-indigo-200/60 font-black shadow-sm'
                    : 'text-white bg-neutral-900 border-neutral-800 shadow-md shadow-black/45'
                  : theme === 'light'
                    ? 'border-transparent hover:text-neutral-900 hover:bg-neutral-200/50'
                    : 'border-transparent hover:text-neutral-200 hover:bg-neutral-900/50'
                  }`}
              >
                Support & Reports
              </button>
            </nav>

            <div className="flex items-center gap-3">
              {/* Global Quick Action Buttons */}
              <button
                onClick={() => loadData(false)}
                disabled={loading || isSyncing}
                className={`px-3.5 py-2 disabled:opacity-50 rounded-xl text-xs font-semibold transition-all cursor-pointer flex items-center gap-1.5 shadow-sm border ${theme === 'light'
                  ? 'bg-white hover:bg-neutral-50 text-neutral-700 border-neutral-200 hover:border-neutral-300 hover:text-indigo-600'
                  : 'bg-neutral-900 hover:bg-neutral-800 text-white border-neutral-800/80 hover:border-neutral-700 hover:text-indigo-400'
                  }`}
                title="Refresh Data"
              >
                <RotateCw className={`w-3.5 h-3.5 ${loading || isSyncing ? 'animate-spin' : ''}`} />
                <span className="hidden sm:inline">Refresh Data</span>
              </button>
              <button
                onClick={handleExport}
                disabled={filteredRecords.length === 0}
                className="px-3.5 py-2 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white rounded-xl text-xs font-bold transition-all cursor-pointer shadow-md flex items-center gap-1.5 shadow-indigo-600/25"
                title="Save Report"
              >
                <Download className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Save Report</span>
              </button>

              {/* Theme Toggle Button */}
              <button
                onClick={() => setTheme((prev) => (prev === 'dark' ? 'light' : 'dark'))}
                className={`p-2 rounded-xl border transition-all duration-300 flex items-center justify-center cursor-pointer shadow-md group relative overflow-hidden ${theme === 'light'
                  ? 'bg-white hover:bg-neutral-50 text-neutral-600 border-neutral-200 hover:border-neutral-300 hover:text-neutral-900'
                  : 'bg-neutral-900 hover:bg-neutral-800 border border-neutral-800/80 hover:border-neutral-700 text-neutral-400 hover:text-white'
                  }`}
                title={theme === 'dark' ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
                id="theme-toggle-btn"
              >
                <div className="relative w-5 h-5 flex items-center justify-center">
                  <Sun className={`w-4 h-4 absolute text-amber-500 transition-all duration-500 ease-out ${theme === 'light' ? 'rotate-0 scale-100 opacity-100' : 'rotate-90 scale-0 opacity-0'
                    }`} />
                  <Moon className={`w-4 h-4 absolute text-indigo-400 transition-all duration-500 ease-out ${theme === 'dark' ? 'rotate-0 scale-100 opacity-100' : '-rotate-90 scale-0 opacity-0'
                    }`} />
                </div>
              </button>

              {/* Sign Out Button */}
              <button
                onClick={handleLogout}
                className={`p-2 rounded-xl border transition-all duration-300 flex items-center justify-center cursor-pointer shadow-md group relative overflow-hidden ${theme === 'light'
                  ? 'bg-white hover:bg-neutral-50 text-neutral-600 border-neutral-200 hover:border-neutral-300 hover:text-rose-600'
                  : 'bg-neutral-900 hover:bg-neutral-800 border border-neutral-800/80 hover:border-neutral-700 text-neutral-400 hover:text-rose-400'
                  }`}
                title="Sign Out"
              >
                <XCircle className="w-4.5 h-4.5" />
              </button>

              <div className={`inline-flex items-center gap-2 px-2.5 py-1 rounded-full text-[10px] font-mono font-bold border ${error
                ? 'bg-rose-500/10 border-rose-500/20 text-rose-400'
                : (loading || isSyncing)
                  ? 'bg-amber-500/10 border-amber-500/20 text-amber-400 animate-pulse'
                  : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400'
                }`}>
                <span className={`w-1.5 h-1.5 rounded-full ${error ? 'bg-rose-50' : (loading || isSyncing) ? 'bg-amber-500 animate-pulse' : 'bg-emerald-500'}`}></span>
                {error ? 'Offline' : (loading || isSyncing) ? 'Syncing...' : `Connected`}
              </div>
            </div>

          </div>
        </header>

        {/* Mobile Navigation Drawer - Sticky and elevated above Map elements */}
        <div className={`md:hidden border-b px-4 py-2 flex items-center justify-around gap-1 text-[10px] font-black uppercase tracking-wider sticky top-16 z-[9998] transition-colors duration-300 ${theme === 'light'
          ? 'border-neutral-200 bg-white/80 text-neutral-600'
          : 'border-neutral-900 bg-neutral-950/80 text-neutral-400'
          }`}>
          <button
            onClick={() => setActivePage('dashboard')}
            className={`py-1.5 px-2.5 rounded-lg transition-all ${activePage === 'dashboard' ? (theme === 'light' ? 'text-indigo-600 bg-indigo-50 font-black font-extrabold' : 'text-indigo-400 bg-indigo-500/10 font-black font-extrabold') : ''}`}
          >
            Home
          </button>
          <button
            onClick={() => setActivePage('data-explorer')}
            className={`py-1.5 px-2.5 rounded-lg transition-all ${activePage === 'data-explorer' ? (theme === 'light' ? 'text-indigo-600 bg-indigo-50 font-black font-extrabold' : 'text-indigo-400 bg-indigo-500/10 font-black font-extrabold') : ''}`}
          >
            Explorer
          </button>
          <button
            onClick={() => setActivePage('registry')}
            className={`py-1.5 px-2.5 rounded-lg transition-all ${activePage === 'registry' ? (theme === 'light' ? 'text-indigo-600 bg-indigo-50 font-black font-extrabold' : 'text-indigo-400 bg-indigo-500/10 font-black font-extrabold') : ''}`}
          >
            Permits
          </button>
          <button
            onClick={() => setActivePage('new-register')}
            className={`py-1.5 px-2.5 rounded-lg transition-all ${activePage === 'new-register' ? (theme === 'light' ? 'text-indigo-600 bg-indigo-50 font-black font-extrabold' : 'text-indigo-400 bg-indigo-500/10 font-black font-extrabold') : ''}`}
          >
            Register
          </button>
          <button
            onClick={() => setActivePage('contact')}
            className={`py-1.5 px-2.5 rounded-lg transition-all ${activePage === 'contact' ? (theme === 'light' ? 'text-indigo-600 bg-indigo-50 font-black font-extrabold' : 'text-indigo-400 bg-indigo-500/10 font-black font-extrabold') : ''}`}
          >
            Support
          </button>
        </div>

        {/* MAIN ROUTED CONTENT */}
        <main className="max-w-[95%] xl:max-w-[1700px] mx-auto px-4 sm:px-6 lg:px-8 py-6 flex flex-col gap-6 min-h-[70vh]">
          <AnimatePresence mode="wait">
            {activePage === 'dashboard' && (
              <motion.div
                key="dashboard"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.28, ease: "easeInOut" }}
                className="flex flex-col gap-6 w-full"
              >
                {renderDashboard()}
              </motion.div>
            )}

            {/* ==================== 2. DATA EXPLORER ==================== */}
            {activePage === 'data-explorer' && (
              <motion.div
                key="data-explorer"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.28, ease: "easeInOut" }}
                className="w-full page-font-large"
              >
                {renderDataExplorer()}
              </motion.div>
            )}

            {/* ==================== 3. PERMIT LEDGER REGISTRY ==================== */}
            {activePage === 'registry' && (
              <motion.div
                key="registry"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.28, ease: "easeInOut" }}
                className="w-full page-font-large"
              >
                {renderRegistry()}
              </motion.div>
            )}

            {/* ==================== 3. COMBINED NEW REGISTRATION ==================== */}
            {activePage === 'new-register' && (
              <motion.div
                key="new-register"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.28, ease: "easeInOut" }}
                className="w-full page-font-large"
              >
                {renderNewRegister()}
              </motion.div>
            )}

            {/* ==================== 4. STATUTORY GUIDELINES ==================== */}
            {activePage === 'about' && (
              <motion.div
                key="about"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.28, ease: "easeInOut" }}
                className="w-full page-font-large"
              >
                {renderAbout()}
              </motion.div>
            )}

            {/* ==================== 5. INSPECTOR DISPATCHES & SUPPORT ==================== */}
            {activePage === 'contact' && (
              <motion.div
                key="contact"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.28, ease: "easeInOut" }}
                className="w-full page-font-large"
              >
                {renderContact()}
              </motion.div>
            )}
          </AnimatePresence>
        </main>
      </div>

      {/* FOOTER */}
      <footer className={`py-6 mt-12 relative z-10 text-center text-xs border-t transition-colors duration-300 ${theme === 'light'
        ? 'border-neutral-200 bg-white text-neutral-500 shadow-inner'
        : 'border-neutral-900 bg-neutral-950 text-neutral-500'
        }`}>
        <div className="max-w-[95%] xl:max-w-[1700px] mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row justify-between items-center gap-4">
          <p>© 2026 Geological Survey & Mines Bureau (GSMB), Sri Lanka. All Rights Reserved.</p>
          <div className="flex items-center gap-3">
            <span className={`text-[10px] border px-3 py-1 rounded-full font-mono font-bold tracking-widest uppercase transition-colors duration-300 ${theme === 'light'
              ? 'bg-neutral-50 border-neutral-200 text-neutral-500'
              : 'bg-neutral-900 border-neutral-800 text-neutral-400'
              }`}>
              OVERSIGHT VERSION 2.0.4-STABLE
            </span>
          </div>
        </div>
      </footer>

      <style>{`
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        @media (max-width: 1100px) {
          .map-row { grid-template-columns: 1fr !important; }
        }
      `}</style>
    </div>
  );
}         