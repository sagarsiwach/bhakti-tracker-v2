"use client";

import { useState, useEffect, useCallback } from "react";
import { format, isToday, addDays, subDays } from "date-fns";

interface Mantra {
  name: string;
  count: number;
  target: number | null;
}

interface Activity {
  name: string;
  displayName: string;
  category: string;
  completed: boolean;
}

const API_BASE = "/api";

const MANTRA_DISPLAY: Record<string, { label: string; icon: string }> = {
  first: { label: "First", icon: "🙏" },
  third: { label: "Third", icon: "📿" },
  dandavat: { label: "Dandavat", icon: "🙇" },
};

const ACTIVITY_ICONS: Record<string, string> = {
  morning_aarti: "🌅",
  afternoon_aarti: "☀️",
  evening_aarti: "🌇",
  before_food_aarti: "🍽️",
  after_food_aarti: "🙏",
  mangalacharan: "📖",
};

export default function Home() {
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [activeTab, setActiveTab] = useState<"practice" | "daily">("practice");
  const [activeMantraIndex, setActiveMantraIndex] = useState(0);
  const [mantras, setMantras] = useState<Mantra[]>([]);
  const [activities, setActivities] = useState<Activity[]>([]);
  const [loading, setLoading] = useState(true);
  const [isOnline, setIsOnline] = useState(true);

  const dateString = format(selectedDate, "yyyy-MM-dd");
  const isTodaySelected = isToday(selectedDate);

  // Fetch data
  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [mantrasRes, activitiesRes] = await Promise.all([
        fetch(`${API_BASE}/mantras/${dateString}`),
        fetch(`${API_BASE}/activities/${dateString}`),
      ]);

      if (mantrasRes.ok) {
        const data = await mantrasRes.json();
        setMantras(data.mantras);
        setIsOnline(true);
      }

      if (activitiesRes.ok) {
        const data = await activitiesRes.json();
        setActivities(data.activities);
      }
    } catch {
      setIsOnline(false);
    } finally {
      setLoading(false);
    }
  }, [dateString]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Update active mantra on server
  useEffect(() => {
    if (mantras[activeMantraIndex]) {
      fetch(`${API_BASE}/active-mantra`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: mantras[activeMantraIndex].name }),
      }).catch(() => {});
    }
  }, [activeMantraIndex, mantras]);

  // Increment mantra
  const incrementMantra = async () => {
    if (!isTodaySelected || !mantras[activeMantraIndex]) return;

    const name = mantras[activeMantraIndex].name;

    // Optimistic update
    setMantras((prev) =>
      prev.map((m) => (m.name === name ? { ...m, count: m.count + 1 } : m))
    );

    // Haptic
    if (navigator.vibrate) navigator.vibrate(10);

    // Sync
    try {
      await fetch(`${API_BASE}/mantras/increment`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, date: dateString }),
      });
    } catch {
      // Revert on error
      setMantras((prev) =>
        prev.map((m) => (m.name === name ? { ...m, count: m.count - 1 } : m))
      );
    }
  };

  // Toggle activity
  const toggleActivity = async (activityName: string) => {
    const activity = activities.find((a) => a.name === activityName);
    if (!activity) return;

    // Optimistic update
    setActivities((prev) =>
      prev.map((a) =>
        a.name === activityName ? { ...a, completed: !a.completed } : a
      )
    );

    // Haptic
    if (navigator.vibrate) navigator.vibrate(10);

    // Sync
    try {
      await fetch(`${API_BASE}/activities`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: activityName,
          date: dateString,
          completed: !activity.completed,
        }),
      });
    } catch {
      // Revert
      setActivities((prev) =>
        prev.map((a) =>
          a.name === activityName ? { ...a, completed: activity.completed } : a
        )
      );
    }
  };

  const currentMantra = mantras[activeMantraIndex];
  const hasTarget = currentMantra?.target !== null;
  const percentage = hasTarget
    ? Math.min((currentMantra?.count / (currentMantra?.target || 1)) * 100, 100)
    : 0;
  const isComplete = hasTarget && currentMantra?.count >= (currentMantra?.target || 0);

  const aartiActivities = activities.filter((a) => a.category === "aarti");
  const satsangActivities = activities.filter((a) => a.category === "satsang");

  return (
    <div className="flex flex-col h-screen">
      {/* Header */}
      <header className="flex items-center justify-between px-5 pt-12 pb-4">
        <h1 className="text-2xl font-semibold text-earth-100">
          {activeTab === "practice" ? "Practice" : "Daily"}
        </h1>
        {!isOnline && (
          <span className="text-xs px-2 py-1 bg-saffron-500/20 text-saffron-400 rounded-full">
            Offline
          </span>
        )}
      </header>

      {/* Date Picker */}
      <div className="flex items-center justify-center gap-4 py-3 px-5">
        <button
          onClick={() => setSelectedDate(subDays(selectedDate, 1))}
          className="p-2 rounded-full bg-earth-800/50 text-earth-300"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>

        <button
          onClick={() => setSelectedDate(new Date())}
          className={`px-4 py-2 rounded-lg min-w-[120px] text-center ${
            isTodaySelected
              ? "bg-saffron-500/20 text-saffron-400 border border-saffron-500/30"
              : "bg-earth-800/50 text-earth-300"
          }`}
        >
          {isTodaySelected ? "Today" : format(selectedDate, "EEE, MMM d")}
        </button>

        <button
          onClick={() => !isTodaySelected && setSelectedDate(addDays(selectedDate, 1))}
          disabled={isTodaySelected}
          className="p-2 rounded-full bg-earth-800/50 text-earth-300 disabled:opacity-30"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto px-5 pb-24">
        {loading ? (
          <div className="flex items-center justify-center h-64">
            <div className="w-12 h-12 border-4 border-saffron-500/30 border-t-saffron-500 rounded-full animate-spin" />
          </div>
        ) : activeTab === "practice" ? (
          <div className="flex flex-col items-center pt-4">
            {/* Mantra Tabs */}
            <div className="flex gap-2 mb-8">
              {mantras.map((m, i) => (
                <button
                  key={m.name}
                  onClick={() => setActiveMantraIndex(i)}
                  className={`px-4 py-2 rounded-full text-sm font-medium transition-all ${
                    i === activeMantraIndex
                      ? "bg-saffron-500/20 text-saffron-400 border border-saffron-500/40"
                      : "bg-earth-800/50 text-earth-400 border border-transparent"
                  }`}
                >
                  {MANTRA_DISPLAY[m.name]?.label || m.name}
                </button>
              ))}
            </div>

            {/* Counter Circle */}
            {currentMantra && (
              <div className="relative flex items-center justify-center">
                {/* Progress Ring */}
                {hasTarget && (
                  <svg className="w-72 h-72 -rotate-90" viewBox="0 0 280 280">
                    <circle
                      cx="140"
                      cy="140"
                      r="120"
                      fill="none"
                      stroke="#664d39"
                      strokeWidth="12"
                    />
                    <circle
                      cx="140"
                      cy="140"
                      r="120"
                      fill="none"
                      stroke="url(#grad)"
                      strokeWidth="12"
                      strokeLinecap="round"
                      strokeDasharray={2 * Math.PI * 120}
                      strokeDashoffset={2 * Math.PI * 120 * (1 - percentage / 100)}
                      className="transition-all duration-300"
                    />
                    <defs>
                      <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" stopColor="#ff9d37" />
                        <stop offset="100%" stopColor="#f06806" />
                      </linearGradient>
                    </defs>
                  </svg>
                )}

                {!hasTarget && (
                  <div className="w-72 h-72 rounded-full border-[12px] border-earth-800" />
                )}

                {/* Tap Button */}
                <button
                  onClick={incrementMantra}
                  disabled={!isTodaySelected}
                  className={`absolute flex flex-col items-center justify-center w-52 h-52 rounded-full transition-transform active:scale-95 ${
                    !isTodaySelected
                      ? "bg-earth-800/50 cursor-not-allowed"
                      : isComplete
                      ? "bg-gradient-to-br from-saffron-500/30 to-saffron-600/20"
                      : "bg-gradient-to-br from-earth-700/80 to-earth-800/80"
                  } shadow-lg`}
                >
                  <span className="text-4xl mb-2">
                    {MANTRA_DISPLAY[currentMantra.name]?.icon}
                  </span>
                  <span
                    className={`text-5xl font-semibold ${
                      isComplete ? "text-saffron-400" : "text-earth-100"
                    }`}
                  >
                    {currentMantra.count}
                  </span>
                  {hasTarget && (
                    <span className="mt-1 text-earth-400 text-sm">
                      of {currentMantra.target}
                    </span>
                  )}
                  {!hasTarget && (
                    <span className="mt-1 text-earth-500 text-sm">total</span>
                  )}
                  <span
                    className={`mt-2 text-xs ${
                      isComplete ? "text-saffron-500" : "text-earth-500"
                    }`}
                  >
                    {!isTodaySelected
                      ? "Past date"
                      : isComplete
                      ? "Complete"
                      : "Tap to count"}
                  </span>
                </button>
              </div>
            )}

            {/* Mantra Name */}
            {currentMantra && (
              <h2 className="mt-6 text-center">
                <span className="text-2xl font-medium text-earth-200">
                  {MANTRA_DISPLAY[currentMantra.name]?.label}
                </span>
                {hasTarget && (
                  <span className="block mt-1 text-sm text-earth-500">
                    {percentage.toFixed(0)}% complete
                  </span>
                )}
              </h2>
            )}
          </div>
        ) : (
          <div className="space-y-6 pt-2">
            {/* Aarti Section */}
            {aartiActivities.length > 0 && (
              <section>
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <span className="text-xl">🪔</span>
                    <h2 className="font-semibold text-earth-200">Aarti</h2>
                  </div>
                  <span className="text-sm text-earth-500">
                    {aartiActivities.filter((a) => a.completed).length}/{aartiActivities.length}
                  </span>
                </div>
                <div className="space-y-2">
                  {aartiActivities.map((activity) => (
                    <button
                      key={activity.name}
                      onClick={() => toggleActivity(activity.name)}
                      className="w-full flex items-center gap-4 px-4 py-4 bg-earth-800/50 rounded-xl active:scale-[0.98] transition-transform"
                    >
                      <span className="text-2xl">{ACTIVITY_ICONS[activity.name]}</span>
                      <span
                        className={`flex-1 text-left font-medium ${
                          activity.completed ? "text-earth-500 line-through" : "text-earth-200"
                        }`}
                      >
                        {activity.displayName}
                      </span>
                      <div
                        className={`w-7 h-7 rounded-full border-2 flex items-center justify-center ${
                          activity.completed
                            ? "bg-green-500/20 border-green-500"
                            : "border-earth-600"
                        }`}
                      >
                        {activity.completed && (
                          <svg className="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                          </svg>
                        )}
                      </div>
                    </button>
                  ))}
                </div>
              </section>
            )}

            {/* Satsang Section */}
            {satsangActivities.length > 0 && (
              <section>
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <span className="text-xl">📖</span>
                    <h2 className="font-semibold text-earth-200">Satsang</h2>
                  </div>
                  <span className="text-sm text-earth-500">
                    {satsangActivities.filter((a) => a.completed).length}/{satsangActivities.length}
                  </span>
                </div>
                <div className="space-y-2">
                  {satsangActivities.map((activity) => (
                    <button
                      key={activity.name}
                      onClick={() => toggleActivity(activity.name)}
                      className="w-full flex items-center gap-4 px-4 py-4 bg-earth-800/50 rounded-xl active:scale-[0.98] transition-transform"
                    >
                      <span className="text-2xl">{ACTIVITY_ICONS[activity.name]}</span>
                      <span
                        className={`flex-1 text-left font-medium ${
                          activity.completed ? "text-earth-500 line-through" : "text-earth-200"
                        }`}
                      >
                        {activity.displayName}
                      </span>
                      <div
                        className={`w-7 h-7 rounded-full border-2 flex items-center justify-center ${
                          activity.completed
                            ? "bg-green-500/20 border-green-500"
                            : "border-earth-600"
                        }`}
                      >
                        {activity.completed && (
                          <svg className="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                          </svg>
                        )}
                      </div>
                    </button>
                  ))}
                </div>
              </section>
            )}
          </div>
        )}
      </main>

      {/* Bottom Nav */}
      <nav className="fixed bottom-0 left-0 right-0 bg-earth-900/95 backdrop-blur-lg border-t border-earth-800/50 pb-[env(safe-area-inset-bottom)]">
        <div className="flex justify-around items-center h-16 max-w-lg mx-auto">
          <button
            onClick={() => setActiveTab("practice")}
            className={`flex flex-col items-center gap-1 px-6 py-2 ${
              activeTab === "practice" ? "text-saffron-400" : "text-earth-500"
            }`}
          >
            <span className="text-xl">🙏</span>
            <span className="text-xs font-medium">Practice</span>
          </button>
          <button
            onClick={() => setActiveTab("daily")}
            className={`flex flex-col items-center gap-1 px-6 py-2 ${
              activeTab === "daily" ? "text-saffron-400" : "text-earth-500"
            }`}
          >
            <span className="text-xl">📋</span>
            <span className="text-xs font-medium">Daily</span>
          </button>
        </div>
      </nav>
    </div>
  );
}
