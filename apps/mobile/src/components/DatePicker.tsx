import React from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { format, addDays, subDays, isToday } from 'date-fns';
import { Ionicons } from '@expo/vector-icons';

interface DatePickerProps {
  date: Date;
  onDateChange: (date: Date) => void;
}

export function DatePicker({ date, onDateChange }: DatePickerProps) {
  const isTodaySelected = isToday(date);
  const displayDate = format(date, 'EEE, MMM d');

  return (
    <View className="flex-row items-center justify-center gap-4 py-4 px-6">
      <TouchableOpacity
        onPress={() => onDateChange(subDays(date, 1))}
        className="p-2 rounded-full bg-earth-800/50"
      >
        <Ionicons name="chevron-back" size={20} color="#a09080" />
      </TouchableOpacity>

      <TouchableOpacity
        onPress={() => onDateChange(new Date())}
        className={`px-4 py-2 rounded-lg min-w-[140px] items-center
          ${isTodaySelected
            ? 'bg-saffron-500/20 border border-saffron-500/30'
            : 'bg-earth-800/50'
          }`}
      >
        <Text className={isTodaySelected ? 'text-saffron-400' : 'text-earth-300'}>
          {isTodaySelected ? 'Today' : displayDate}
        </Text>
      </TouchableOpacity>

      <TouchableOpacity
        onPress={() => !isTodaySelected && onDateChange(addDays(date, 1))}
        disabled={isTodaySelected}
        className={`p-2 rounded-full bg-earth-800/50 ${isTodaySelected ? 'opacity-30' : ''}`}
      >
        <Ionicons name="chevron-forward" size={20} color="#a09080" />
      </TouchableOpacity>
    </View>
  );
}
