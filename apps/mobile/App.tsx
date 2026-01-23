import './global.css';
import React, { useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { isToday } from 'date-fns';

import { Header } from './src/components/Header';
import { DatePicker } from './src/components/DatePicker';
import { MantraCounter } from './src/components/MantraCounter';
import { useMantras } from './src/hooks/useMantras';

export default function App() {
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [activeIndex, setActiveIndex] = useState(0);
  const { mantras, loading, error, refresh, increment } = useMantras(selectedDate);

  const isCurrentDay = isToday(selectedDate);

  return (
    <View className="flex-1 bg-earth-950">
      <StatusBar style="light" />

      <Header />

      <DatePicker date={selectedDate} onDateChange={setSelectedDate} />

      <ScrollView
        className="flex-1"
        contentContainerStyle={{ flexGrow: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 24, paddingBottom: 32 }}
        refreshControl={
          <RefreshControl
            refreshing={loading}
            onRefresh={refresh}
            tintColor="#ff9d37"
          />
        }
      >
        {loading && mantras.length === 0 ? (
          <ActivityIndicator size="large" color="#ff9d37" />
        ) : error ? (
          <View className="items-center">
            <Text className="text-earth-400">{error}</Text>
            <TouchableOpacity
              onPress={refresh}
              className="mt-4 px-6 py-2 bg-earth-800 rounded-full"
            >
              <Text className="text-earth-200">Retry</Text>
            </TouchableOpacity>
          </View>
        ) : mantras.length > 0 ? (
          <>
            {/* Mantra tabs */}
            <View className="flex-row gap-2 mb-8">
              {mantras.map((mantra, i) => (
                <TouchableOpacity
                  key={mantra.name}
                  onPress={() => setActiveIndex(i)}
                  className={`px-4 py-2 rounded-full
                    ${i === activeIndex
                      ? 'bg-saffron-500/20 border border-saffron-500/40'
                      : 'bg-earth-800/50 border border-transparent'
                    }`}
                >
                  <Text
                    className={`text-sm font-medium
                      ${i === activeIndex ? 'text-saffron-400' : 'text-earth-400'}`}
                  >
                    {mantra.name.charAt(0).toUpperCase() + mantra.name.slice(1)}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Active mantra counter */}
            <MantraCounter
              name={mantras[activeIndex].name}
              count={mantras[activeIndex].count}
              target={mantras[activeIndex].target}
              onIncrement={() => increment(mantras[activeIndex].name)}
              disabled={!isCurrentDay}
            />

            {/* Swipe hint */}
            <Text className="mt-6 text-earth-500 text-sm">
              Tap tabs to switch
            </Text>
          </>
        ) : (
          <Text className="text-earth-400">No mantras configured</Text>
        )}
      </ScrollView>

      {/* Navigation dots */}
      {mantras.length > 1 && (
        <View className="flex-row justify-center gap-2 pb-8">
          {mantras.map((_, i) => (
            <TouchableOpacity
              key={i}
              onPress={() => setActiveIndex(i)}
              className={`h-2 rounded-full
                ${i === activeIndex ? 'w-6 bg-saffron-500' : 'w-2 bg-earth-600'}`}
            />
          ))}
        </View>
      )}
    </View>
  );
}
