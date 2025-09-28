// lib/mood_service.dart

import 'package:flutter/material.dart';

class Mood {
  final IconData icon;
  final String name;
  final Color color;
  final double value; // A numerical value for charting (e.g., 1-5 scale)

  Mood({
    required this.icon,
    required this.name,
    required this.color,
    required this.value,
  });
}

class MoodService {
  // --- CHANGED: Updated the list to the 5 specified moods ---
  static final List<Mood> moods = [
    Mood(name: 'Very Low', icon: Icons.sentiment_very_dissatisfied, color: const Color(0xFF607D8B), value: 1.0), // Blue Grey
    Mood(name: 'Low', icon: Icons.sentiment_dissatisfied, color: const Color(0xFF4FC3F7), value: 2.0),      // Light Blue
    Mood(name: 'Neutral', icon: Icons.sentiment_neutral, color: const Color(0xFFFFCA28), value: 3.0),        // Amber
    Mood(name: 'Good', icon: Icons.sentiment_satisfied_alt, color: const Color(0xFF9CCC65), value: 4.0),     // Light Green
    Mood(name: 'Very Good', icon: Icons.sentiment_very_satisfied, color: const Color(0xFF66BB6A), value: 5.0), // Green
  ];

  static double moodToValue(String moodName) {
    // The default 'orElse' will now correctly point to 'Neutral' (index 2)
    return moods.firstWhere((m) => m.name == moodName, orElse: () => moods[2]).value;
  }

  static String valueToMood(double moodValue) {
    return moods.reduce((a, b) => (a.value - moodValue).abs() < (b.value - moodValue).abs() ? a : b).name;
  }

  // --- CHANGED: Updated colors to match the new mood palette ---
  static Color getCalendarColor(int moodValue) {
    if (moodValue <= 1) return const Color(0xFF607D8B); // Very Low
    if (moodValue <= 2) return const Color(0xFF4FC3F7); // Low
    if (moodValue <= 3) return const Color(0xFFFFCA28); // Neutral
    if (moodValue <= 4) return const Color(0xFF9CCC65); // Good
    return const Color(0xFF66BB6A); // Very Good
  }

  static String getChartEmoji(int value) {
    switch (value) {
      case 1: return '😢';
      case 2: return '😟';
      case 3: return '😐';
      case 4: return '😊';
      case 5: return '😃';
      default: return '';
    }
  }
}