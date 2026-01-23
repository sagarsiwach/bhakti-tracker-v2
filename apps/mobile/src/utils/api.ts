import { format } from 'date-fns';

// Configure this to your server URL
// For development, use your Mac's IP address (not localhost) so the phone can reach it
// For production, use your server's public URL
const API_BASE = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:3000';

export interface Mantra {
  name: string;
  count: number;
  target: number;
}

export interface MantrasResponse {
  date: string;
  mantras: Mantra[];
}

export async function getMantras(date: Date): Promise<MantrasResponse> {
  const dateStr = format(date, 'yyyy-MM-dd');
  const res = await fetch(`${API_BASE}/api/mantras/${dateStr}`);
  if (!res.ok) throw new Error('Failed to fetch mantras');
  return res.json();
}

export async function incrementMantra(name: string, date: Date): Promise<Mantra> {
  const dateStr = format(date, 'yyyy-MM-dd');
  const res = await fetch(`${API_BASE}/api/mantras/increment`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, date: dateStr }),
  });
  if (!res.ok) throw new Error('Failed to increment mantra');
  return res.json();
}

export async function setMantraCount(name: string, date: Date, count: number): Promise<Mantra> {
  const dateStr = format(date, 'yyyy-MM-dd');
  const res = await fetch(`${API_BASE}/api/mantras`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, date: dateStr, count }),
  });
  if (!res.ok) throw new Error('Failed to set mantra count');
  return res.json();
}
