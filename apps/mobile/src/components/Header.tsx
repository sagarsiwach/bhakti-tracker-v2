import React from 'react';
import { View, Text } from 'react-native';
import { format, isToday } from 'date-fns';

export function Header() {
  const now = new Date();
  const time = format(now, 'HH:mm');
  const dateDisplay = isToday(now) ? 'Today' : format(now, 'EEEE, d MMMM');

  return (
    <View className="pt-16 pb-4 px-6 items-center">
      <Text className="text-3xl font-semibold text-earth-100 tracking-wide">
        Bhakti
      </Text>
      <Text className="mt-1 text-earth-400 text-sm">
        {dateDisplay} • {time}
      </Text>
    </View>
  );
}
