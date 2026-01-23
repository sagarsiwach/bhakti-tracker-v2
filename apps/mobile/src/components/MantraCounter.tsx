import React from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import * as Haptics from 'expo-haptics';
import Svg, { Circle, Defs, LinearGradient, Stop } from 'react-native-svg';

interface MantraCounterProps {
  name: string;
  count: number;
  target: number;
  onIncrement: () => void;
  disabled?: boolean;
}

export function MantraCounter({ name, count, target, onIncrement, disabled }: MantraCounterProps) {
  const percentage = Math.min((count / target) * 100, 100);
  const isComplete = count >= target;

  const radius = 120;
  const strokeWidth = 12;
  const circumference = 2 * Math.PI * radius;
  const dashOffset = circumference - (percentage / 100) * circumference;

  const handlePress = async () => {
    if (disabled) return;
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    onIncrement();
  };

  const displayName = name.charAt(0).toUpperCase() + name.slice(1);

  return (
    <View className="items-center">
      {/* Progress Ring */}
      <View className="relative items-center justify-center" style={{ width: 280, height: 280 }}>
        <Svg width={280} height={280} style={{ transform: [{ rotate: '-90deg' }] }}>
          <Defs>
            <LinearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="100%">
              <Stop offset="0%" stopColor="#ff9d37" />
              <Stop offset="50%" stopColor="#ff8210" />
              <Stop offset="100%" stopColor="#f06806" />
            </LinearGradient>
          </Defs>

          {/* Background ring */}
          <Circle
            cx={140}
            cy={140}
            r={radius}
            fill="none"
            stroke="#3d3128"
            strokeWidth={strokeWidth}
          />

          {/* Progress ring */}
          <Circle
            cx={140}
            cy={140}
            r={radius}
            fill="none"
            stroke="url(#progressGradient)"
            strokeWidth={strokeWidth}
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={dashOffset}
          />
        </Svg>

        {/* Center Button */}
        <TouchableOpacity
          onPress={handlePress}
          disabled={disabled}
          activeOpacity={0.8}
          className={`absolute w-52 h-52 rounded-full items-center justify-center shadow-lg
            ${disabled
              ? 'bg-earth-800/50'
              : isComplete
                ? 'bg-saffron-500/30'
                : 'bg-earth-700/80'
            }`}
          style={{
            shadowColor: '#000',
            shadowOffset: { width: 0, height: 4 },
            shadowOpacity: 0.3,
            shadowRadius: 8,
          }}
        >
          <Text className={`text-5xl font-semibold ${isComplete ? 'text-saffron-400' : 'text-earth-100'}`}>
            {count}
          </Text>
          <Text className="text-earth-400 text-sm mt-1">
            of {target}
          </Text>
          <Text className={`text-xs mt-3 ${isComplete ? 'text-saffron-500' : 'text-earth-500'}`}>
            {disabled ? 'Past date' : isComplete ? 'Complete' : 'Tap to count'}
          </Text>
        </TouchableOpacity>
      </View>

      {/* Mantra Name */}
      <View className="mt-6 items-center">
        <Text className="text-2xl font-medium text-earth-200">
          {displayName}
        </Text>
        <Text className="text-sm text-earth-500 mt-1">
          {percentage.toFixed(0)}% complete
        </Text>
      </View>
    </View>
  );
}
