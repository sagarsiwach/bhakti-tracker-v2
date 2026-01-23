import { useState, useEffect, useCallback } from 'react';
import { getMantras, incrementMantra as apiIncrement, Mantra } from '../utils/api';

export function useMantras(date: Date) {
  const [mantras, setMantras] = useState<Mantra[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchMantras = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getMantras(date);
      setMantras(data.mantras);
    } catch (e) {
      setError('Failed to load mantras');
      console.error(e);
    } finally {
      setLoading(false);
    }
  }, [date]);

  useEffect(() => {
    fetchMantras();
  }, [fetchMantras]);

  const increment = useCallback(async (name: string) => {
    // Optimistic update
    setMantras(prev =>
      prev.map(m => (m.name === name ? { ...m, count: m.count + 1 } : m))
    );

    try {
      await apiIncrement(name, date);
    } catch (e) {
      // Revert on error
      setMantras(prev =>
        prev.map(m => (m.name === name ? { ...m, count: m.count - 1 } : m))
      );
      console.error(e);
    }
  }, [date]);

  return { mantras, loading, error, refresh: fetchMantras, increment };
}
