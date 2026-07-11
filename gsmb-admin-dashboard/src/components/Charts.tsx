import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip as RechartsTooltip,
  Legend,
  PieChart,
  Pie,
  Cell,
} from 'recharts';
import { IncidentSeries, StatusCounts } from '../types';

interface IncidentTrendChartProps {
  data: IncidentSeries;
  theme?: 'dark' | 'light';
}

export function IncidentTrendChart({ data, theme = 'dark' }: IncidentTrendChartProps) {
  // Map monthly data into an array of objects for Recharts
  const chartData = data.labels.map((label, index) => ({
    name: label,
    Overloads: data.overloads[index] || 0,
    'Fraud Flags': data.frauds[index] || 0,
  }));

  const isEmpty = chartData.length === 0;

  const isLight = theme === 'light';
  const gridStroke = isLight ? 'rgba(0, 0, 0, 0.06)' : 'rgba(255, 255, 255, 0.04)';
  const textStroke = isLight ? '#4b5563' : '#a3a3a3';
  const tooltipBg = isLight ? '#ffffff' : '#171717';
  const tooltipColor = isLight ? '#111827' : '#f5f5f5';
  const tooltipBorder = isLight ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.08)';

  return (
    <div className="w-full h-[260px] flex items-center justify-center">
      {isEmpty ? (
        <p className="text-slate-400 text-sm">No operational incident history available.</p>
      ) : (
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart
            data={chartData}
            margin={{ top: 10, right: 10, left: -25, bottom: 0 }}
          >
            <defs>
              <linearGradient id="colorOverloads" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#fb7185" stopOpacity={0.25} />
                <stop offset="95%" stopColor="#fb7185" stopOpacity={0.0} />
              </linearGradient>
              <linearGradient id="colorFrauds" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#34d399" stopOpacity={0.25} />
                <stop offset="95%" stopColor="#34d399" stopOpacity={0.0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke={gridStroke} vertical={false} />
            <XAxis
              dataKey="name"
              stroke={textStroke}
              fontSize={10}
              tickLine={false}
              axisLine={false}
              dy={8}
            />
            <YAxis
              stroke={textStroke}
              fontSize={10}
              tickLine={false}
              axisLine={false}
              allowDecimals={false}
            />
            <RechartsTooltip
              contentStyle={{
                backgroundColor: tooltipBg,
                borderColor: tooltipBorder,
                borderRadius: '16px',
                color: tooltipColor,
                fontSize: '12px',
                boxShadow: isLight ? '0 10px 25px -5px rgba(0, 0, 0, 0.1)' : '0 20px 40px -10px rgba(0, 0, 0, 0.7)',
              }}
            />
            <Legend
              verticalAlign="top"
              height={36}
              iconType="circle"
              iconSize={8}
              wrapperStyle={{ fontSize: '11px', color: textStroke }}
            />
            <Area
              type="monotone"
              dataKey="Overloads"
              stroke="#fb7185"
              strokeWidth={2}
              fillOpacity={1}
              fill="url(#colorOverloads)"
              activeDot={{ r: 5 }}
            />
            <Area
              type="monotone"
              dataKey="Fraud Flags"
              stroke="#34d399"
              strokeWidth={2}
              fillOpacity={1}
              fill="url(#colorFrauds)"
              activeDot={{ r: 5 }}
            />
          </AreaChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}

interface PermitStatusChartProps {
  data: StatusCounts;
  theme?: 'dark' | 'light';
}

export function PermitStatusChart({ data, theme = 'dark' }: PermitStatusChartProps) {
  const chartData = [
    { name: 'Pending', value: data.Pending, color: '#fbbf24' },  // Amber
    { name: 'Active', value: data.Active, color: '#6366f1' },   // Indigo
    { name: 'Completed', value: data.Completed, color: '#737373' }, // Neutral-500
    { name: 'Cancelled', value: data.Cancelled, color: '#f43f5e' }, // Rose/Red
  ].filter((item) => item.value > 0);

  const isEmpty = chartData.length === 0;

  const isLight = theme === 'light';
  const textStroke = isLight ? '#4b5563' : '#a3a3a3';
  const tooltipBg = isLight ? '#ffffff' : '#171717';
  const tooltipColor = isLight ? '#111827' : '#f5f5f5';
  const tooltipBorder = isLight ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.08)';

  return (
    <div className="w-full h-[260px] flex items-center justify-center">
      {isEmpty ? (
        <p className="text-neutral-400 text-sm">No permit data available for outcomes.</p>
      ) : (
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={chartData}
              cx="50%"
              cy="45%"
              innerRadius={65}
              outerRadius={85}
              paddingAngle={4}
              dataKey="value"
            >
              {chartData.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.color} stroke="none" />
              ))}
            </Pie>
            <RechartsTooltip
              contentStyle={{
                backgroundColor: tooltipBg,
                borderColor: tooltipBorder,
                borderRadius: '16px',
                color: tooltipColor,
                fontSize: '12px',
                boxShadow: isLight ? '0 10px 25px -5px rgba(0, 0, 0, 0.1)' : '0 20px 40px -10px rgba(0, 0, 0, 0.7)',
              }}
            />
            <Legend
              verticalAlign="bottom"
              height={36}
              iconType="circle"
              iconSize={8}
              wrapperStyle={{ fontSize: '11px', color: textStroke }}
            />
          </PieChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}
