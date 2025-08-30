// lib/mood_service.dart

import 'package:flutter/material.dart';

class MoodService {
  static const List<String> moodTexts = [
    "Very Low",
    "Low",
    "Neutral",
    "Good",
    "Very Good"
  ];

  static const List<String> moodEmojis = [
    "😢",
    "☹️",
    "😐",
    "🙂",
    "😄"
  ];

  static const List<String> chartEmojis = [
    "😞",
    "🙁",
    "😐",
    "😊",
    "😁"
  ];

  static const List<List<Color>> moodColors = [
    [Color(0xff2c3e50), Color(0xff4b6584)],  // Very Low
    [Color(0xff89909c), Color(0xffb3b9c4)],  // Low
    [Color(0xff2980b9), Color(0xff6dd5fa)],  // Neutral
    [Color(0xfff1c40f), Color(0xfff39c12)],  // Good
    [Color(0xffff5f6d), Color(0xffffc371)],  // Very Good
  ];

  static const Map<int, Color> calendarColors = {
    1: Color.fromRGBO(63, 81, 181, 0.8),      // Very Low - Indigo
    2: Color.fromRGBO(103, 58, 183, 0.8),     // Low - Deep Purple
    3: Color.fromRGBO(121, 85, 72, 0.8),      // Neutral - Brown
    4: Color.fromRGBO(255, 152, 0, 0.8),      // Good - Deep Orange 300
    5: Color.fromRGBO(255, 87, 34, 0.8),      // Very Good - Deep Orange 800
  };

  /// Convert slider value (0.0-1.0) to mood text
  static String getMoodText(double value) {
    if (value < 0.2) return moodTexts[0];
    if (value < 0.4) return moodTexts[1];
    if (value < 0.6) return moodTexts[2];
    if (value < 0.8) return moodTexts[3];
    return moodTexts[4];
  }

  /// Convert slider value (0.0-1.0) to mood emoji
  static String getMoodEmoji(double value) {
    if (value < 0.2) return moodEmojis[0];
    if (value < 0.4) return moodEmojis[1];
    if (value < 0.6) return moodEmojis[2];
    if (value < 0.8) return moodEmojis[3];
    return moodEmojis[4];
  }

  /// Convert mood text to numeric value (1.0-5.0) for charts
  static double moodToValue(String mood) {
    switch (mood) {
      case "Very Good": return 5.0;
      case "Good": return 4.0;
      case "Neutral": return 3.0;
      case "Low": return 2.0;
      case "Very Low": return 1.0;
      default: return 0.0;
    }
  }

  /// Convert numeric value (1.0-5.0) back to mood text
  static String valueToMood(double value) {
    switch (value.round()) {
      case 5: return "Very Good";
      case 4: return "Good";
      case 3: return "Neutral";
      case 2: return "Low";
      case 1: return "Very Low";
      default: return "Unknown";
    }
  }

  /// Get chart emoji for given numeric value
  static String getChartEmoji(int value) {
    switch (value) {
      case 1: return chartEmojis[0];
      case 2: return chartEmojis[1];
      case 3: return chartEmojis[2];
      case 4: return chartEmojis[3];
      case 5: return chartEmojis[4];
      default: return chartEmojis[2]; // Default to neutral
    }
  }

  /// Get calendar color for mood value
  static Color getCalendarColor(int moodValue) {
    return calendarColors[moodValue] ?? Colors.black.withOpacity(0.1);
  }

  /// Calculate animated gradient for slider background
  static LinearGradient calculateAnimatedGradient(double sliderValue) {
    final position = sliderValue * (moodColors.length - 1);
    final fromIndex = position.floor();
    final toIndex = position.ceil();
    final t = position - fromIndex;

    if (fromIndex == toIndex) {
      return LinearGradient(
        colors: moodColors[fromIndex],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    final topColor = Color.lerp(moodColors[fromIndex][0], moodColors[toIndex][0], t);
    final bottomColor = Color.lerp(moodColors[fromIndex][1], moodColors[toIndex][1], t);

    return LinearGradient(
      colors: [topColor!, bottomColor!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}