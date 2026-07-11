export interface RawLocation {
  id: string;
  name: string | null;
  location_type: string | null;
  inventory_cubes: string | number | null;
  latitude: string | number | null;
  longitude: string | number | null;
  address?: string | null;
  district?: string | null;
  max_capacity?: string | number | null;
  user_id?: string | null;
  raw?: any;
}

export interface RawPermit {
  id: string;
  permit_code: string | null;
  truck_number: string | null;
  volume_cubes: string | number | null;
  transport_date: string;
  expiration_date: string | null;
  status: string | null;
  origin_location_id: string | null;
  unload_latitude: number | null;
  unload_longitude: number | null;
  unloaded_at: string | null;
}

export interface ProcessedPermit {
  id: string;
  permitCode: string;
  truckNumber: string;
  volumeCubes: number;
  transportDate: Date;
  expirationDate: Date | null;
  status: 'PENDING' | 'ACTIVE' | 'COMPLETED' | 'CANCELLED';
  originLocationId: string | null;
  unloadLatitude: number | null;
  unloadLongitude: number | null;
  unloadedAt: string | null;
  gpsMismatch: boolean;
  originLocationName?: string;
}

export interface ProcessedLocationRecord {
  id: string;
  name: string;
  type: 'Mine' | 'Hardware';
  region: string;
  inventory: number;
  maxCapacity: number;
  incidents: number;
  risk: 'low' | 'medium' | 'high';
  status: string;
  coordinates: [number, number];
  permit: string;
  truck: string;
  timeline: Array<{ label: string; value: string }>;
  isOverloaded?: boolean;
  user_id?: string | null;
  raw?: any;
}

export interface DashboardMetrics {
  label: string;
  value: number;
  note: string;
}

export interface IncidentSeries {
  labels: string[];
  overloads: number[];
  frauds: number[];
}

export interface StatusCounts {
  Pending: number;
  Active: number;
  Completed: number;
  Cancelled: number;
}

export interface DashboardData {
  generatedAt: Date;
  metrics: DashboardMetrics[];
  records: ProcessedLocationRecord[];
  incidentSeries: IncidentSeries;
  statusCounts: StatusCounts;
}
