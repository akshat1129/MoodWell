// lib/detailed_view.dart

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'mood_service.dart'; // ✨ IMPORT the new service

class EntryDetailsPage extends StatefulWidget {
  final String mood;
  final String notes;
  final bool hasLoggedToday;
  final int currentStreak;
  final DateTime streakStartDate;

  const EntryDetailsPage({
    super.key,
    required this.mood,
    required this.notes,
    required this.hasLoggedToday,
    required this.currentStreak,
    required this.streakStartDate,
  });

  @override
  State<EntryDetailsPage> createState() => _EntryDetailsPageState();
}

class _EntryDetailsPageState extends State<EntryDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<FlSpot>> _weeklyMoodData;
  late Future<List<FlSpot>> _dailyMoodData;
  late Future<List<FlSpot>> _monthlyMoodData;

  final GlobalKey _streakCounterKey = GlobalKey();

  Future<Map<DateTime, int>> _fetchLast10DaysMood() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 9));

    final querySnapshot = await FirebaseFirestore.instance
        .collection('entries')
        .where('userId', isEqualTo: user.uid)
        .where('timestamp', isGreaterThanOrEqualTo: startDate)
        .get();

    final Map<DateTime, List<double>> moodValuesByDate = {};

    for (var doc in querySnapshot.docs) {
      final serverTimestamp = (doc.data()['timestamp'] as Timestamp).toDate();
      final localTimestamp = serverTimestamp.toLocal();
      final dateKey = DateTime(localTimestamp.year, localTimestamp.month, localTimestamp.day);
      // ✨ USE MoodService
      final moodValue = MoodService.moodToValue(doc.data()['mood']);
      moodValuesByDate.update(dateKey, (value) => [...value, moodValue], ifAbsent: () => [moodValue]);
    }

    final Map<DateTime, int> dailyMoods = {};
    moodValuesByDate.forEach((date, moods) {
      final avgMood = moods.reduce((a, b) => a + b) / moods.length;
      dailyMoods[date] = avgMood.round();
    });

    return dailyMoods;
  }

  Future<String> _calculateAverageMood() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Not available";

    final querySnapshot = await FirebaseFirestore.instance
        .collection('entries')
        .where('userId', isEqualTo: user.uid)
        .where('timestamp', isGreaterThanOrEqualTo: widget.streakStartDate)
        .get();

    if (querySnapshot.docs.isEmpty) {
      // ✨ USE MoodService
      return MoodService.valueToMood(MoodService.moodToValue(widget.mood));
    }

    double totalMoodValue = 0;
    for (var doc in querySnapshot.docs) {
      // ✨ USE MoodService
      totalMoodValue += MoodService.moodToValue(doc.data()['mood']);
    }

    final averageValue = totalMoodValue / querySnapshot.docs.length;

    // ✨ USE MoodService
    return MoodService.valueToMood(averageValue);
  }

  void _showStreakDetailsDialog() async {
    final String averageMood = await _calculateAverageMood();

    final RenderBox renderBox = _streakCounterKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final baseFontSize = screenWidth * 0.04;
        final formattedDate = DateFormat.yMMMMd().format(widget.streakStartDate);

        final scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        );

        return ScaleTransition(
          scale: scaleAnimation,
          alignment: Alignment(
            (position.dx + size.width / 2) / screenWidth * 2 - 1,
            (position.dy + size.height / 2) / MediaQuery.of(context).size.height * 2 - 1,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade800],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(color: Colors.deepPurple.shade300, width: 2),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(screenWidth * 0.06),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department_rounded, color: Colors.orange.shade400, size: baseFontSize * 3),
                          const SizedBox(height: 16),
                          Text(
                            "You're on a ${widget.currentStreak}-day streak!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: baseFontSize * 1.4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "This streak started on $formattedDate.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: baseFontSize * 0.9),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 20),
                          Text(
                            "Your average mood during this streak has been:",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: baseFontSize * 0.9),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            averageMood,
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: baseFontSize * 1.3,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[400]),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _customDistanceCalculator(Offset touchPoint, Offset spotPixelCoordinates) {
    final dx = touchPoint.dx - spotPixelCoordinates.dx;
    final dy = touchPoint.dy - spotPixelCoordinates.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabController = TabController(length: 3, vsync: this);
    _weeklyMoodData = _fetchWeeklyMoodData();
    _dailyMoodData = _fetchDailyMoodData();
    _monthlyMoodData = _fetchMonthlyMoodData();
  }

  // ✨ REMOVED _valueToMood function

  String _formatHour(double hourValue) {
    int hours = hourValue.floor();
    int minutes = ((hourValue - hours) * 60).round();
    String period = 'AM';

    if (hours >= 12) {
      period = 'PM';
      if (hours > 12) {
        hours -= 12;
      }
    }
    if (hours == 0) {
      hours = 12;
    }
    return "${hours.toString()}:${minutes.toString().padLeft(2, '0')} $period";
  }

  // ✨ REMOVED _moodToValue function

  Future<List<FlSpot>> _fetchDailyMoodData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final nowLocal = DateTime.now();
    final startOfTodayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final startOfNextDayLocal = startOfTodayLocal.add(const Duration(days: 1));

    final querySnapshot = await FirebaseFirestore.instance
        .collection('entries')
        .where('userId', isEqualTo: user.uid)
        .where('timestamp', isGreaterThanOrEqualTo: startOfTodayLocal)
        .where('timestamp', isLessThan: startOfNextDayLocal)
        .orderBy('timestamp')
        .get();

    List<FlSpot> spots = querySnapshot.docs.map((doc) {
      final serverTimestamp = (doc.data()['timestamp'] as Timestamp).toDate();
      final localTimestamp = serverTimestamp.toLocal();
      // ✨ USE MoodService
      final moodValue = MoodService.moodToValue(doc.data()['mood']);
      final hour = localTimestamp.hour.toDouble() + (localTimestamp.minute.toDouble() / 60.0);
      return FlSpot(hour, moodValue);
    }).toList();

    final currentHour = nowLocal.hour.toDouble() + (nowLocal.minute.toDouble() / 60.0);
    // ✨ USE MoodService
    final currentMoodValue = MoodService.moodToValue(widget.mood);
    final currentSpot = FlSpot(currentHour, currentMoodValue);

    spots.add(currentSpot);
    final uniqueSpots = spots.toSet().toList();
    uniqueSpots.sort((a,b) => a.x.compareTo(b.x));

    return uniqueSpots;
  }

  Future<List<FlSpot>> _fetchWeeklyMoodData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final startOfPeriod = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    final querySnapshot = await FirebaseFirestore.instance
        .collection('entries')
        .where('userId', isEqualTo: user.uid)
        .where('timestamp', isGreaterThanOrEqualTo: startOfPeriod)
        .orderBy('timestamp', descending: false)
        .get();

    if (querySnapshot.docs.isEmpty) return [];

    final Map<String, List<double>> moodValuesByDate = {};

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final serverTimestamp = (data['timestamp'] as Timestamp).toDate();
      final localTimestamp = serverTimestamp.toLocal();
      final dateKey = DateFormat('yyyy-MM-dd').format(localTimestamp);
      // ✨ USE MoodService
      final moodValue = MoodService.moodToValue(data['mood']);

      moodValuesByDate.update(dateKey, (value) => [...value, moodValue], ifAbsent: () => [moodValue]);
    }

    final List<FlSpot> spots = [];
    final localNow = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = localNow.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final double xAxisDay = 6.0 - i;

      if (moodValuesByDate.containsKey(dateKey)) {
        final moodsForDay = moodValuesByDate[dateKey]!;
        final avgMood = moodsForDay.reduce((a, b) => a + b) / moodsForDay.length;
        spots.add(FlSpot(xAxisDay, avgMood));
      }
    }

    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  Future<List<FlSpot>> _fetchMonthlyMoodData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final querySnapshot = await FirebaseFirestore.instance
        .collection('entries')
        .where('userId', isEqualTo: user.uid)
        .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
        .orderBy('timestamp')
        .get();

    if (querySnapshot.docs.isEmpty) return [];

    final Map<int, List<double>> moodValuesByDay = {};

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final timestamp = (data['timestamp'] as Timestamp).toDate().toLocal();
      // ✨ USE MoodService
      final moodValue = MoodService.moodToValue(data['mood']);
      final dayOfMonth = timestamp.day;

      moodValuesByDay.update(dayOfMonth, (value) => [...value, moodValue], ifAbsent: () => [moodValue]);
    }

    final List<FlSpot> spots = [];
    moodValuesByDay.forEach((day, moods) {
      final avgMood = moods.reduce((a, b) => a + b) / moods.length;
      spots.add(FlSpot(day.toDouble(), avgMood));
    });

    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final baseFontSize = screenWidth * 0.04;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.deepPurple.shade200,
      appBar: AppBar(
        title: const Text('Log Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff8c6ebf), Color(0xff5c88bb)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: screenWidth * 0.05),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Mood:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: baseFontSize,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Text(
                            widget.mood,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: baseFontSize * 2.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    InkWell(
                      key: _streakCounterKey,
                      onTap: _showStreakDetailsDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Row(
                          children: [
                            Text(
                              '${widget.currentStreak}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: baseFontSize * 2.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.4),
                                    blurRadius: 12.0,
                                    spreadRadius: 1.0,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.local_fire_department_rounded,
                                color: Colors.orange.shade400,
                                size: baseFontSize * 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  'Your Notes:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: baseFontSize,
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.notes.isNotEmpty ? widget.notes : 'No notes added.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: baseFontSize * 0.9,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                _buildCalendar(screenWidth, screenHeight),
                SizedBox(height: screenHeight * 0.04),
                _buildGraphSection(screenWidth, screenHeight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(double screenWidth, double screenHeight) {
    final baseFontSize = screenWidth * 0.04;

    // ✨ REMOVED local colorThresholds map

    return Column(
      children: [
        Text(
          "Your Calendar Heatmap",
          style: TextStyle(color: Colors.white70, fontSize: baseFontSize * 0.9),
        ),
        SizedBox(height: screenHeight * 0.015),
        FutureBuilder<Map<DateTime, int>>(
          future: _fetchLast10DaysMood(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }

            final dailyMoods = snapshot.data!;
            final List<Widget> calendarDays = [];
            final int streakBlock = ((widget.currentStreak - 1) / 10).floor();
            final DateTime calendarStartDate = widget.streakStartDate.add(Duration(days: streakBlock * 10));

            for (int i = 0; i < 10; i++) {
              final date = calendarStartDate.add(Duration(days: i));
              final dateKey = DateTime(date.year, date.month, date.day);
              final now = DateTime.now();
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
              final bool isMarked = date.isBefore(now) || isToday;
              final moodValue = dailyMoods[dateKey];

              Color backgroundColor;
              if (isMarked && moodValue != null) {
                // ✨ USE MoodService
                backgroundColor = MoodService.getCalendarColor(moodValue);
              } else if (isMarked) {
                backgroundColor = Colors.deepPurple.shade300.withOpacity(0.8);
              } else {
                backgroundColor = Colors.black.withOpacity(0.1);
              }

              calendarDays.add(
                Container(
                  margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015, horizontal: screenWidth * 0.02),
                  width: screenWidth * 0.16,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: isToday ? Border.all(color: Colors.deepPurple.shade200, width: 2) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.E().format(date),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: baseFontSize * 0.9),
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        date.day.toString(),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: baseFontSize * 1.1),
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      if (isMarked)
                        Icon(Icons.check_circle, color: Colors.white, size: baseFontSize)
                      else
                        SizedBox(height: baseFontSize),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: calendarDays),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGraphSection(double screenWidth, double screenHeight) {
    final baseFontSize = screenWidth * 0.04;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Mood History',
          style: TextStyle(
              color: Colors.white, fontSize: baseFontSize * 1.2, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: screenHeight * 0.015),
        TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black.withOpacity(0.2),
            border: Border.all(color: Colors.deepPurple.shade200, width: 2),
          ),
          tabs: [
            Tab(
              child: SizedBox(
                width: screenWidth * 0.25,
                child: const Center(child: Text('Day')),
              ),
            ),
            Tab(
              child: SizedBox(
                width: screenWidth * 0.25,
                child: const Center(child: Text('Week')),
              ),
            ),
            Tab(
              child: SizedBox(
                width: screenWidth * 0.25,
                child: const Center(child: Text('Month')),
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.02),
        SizedBox(
          height: screenHeight * 0.33,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDailyChart(screenWidth),
              _buildWeeklyChart(screenWidth),
              _buildMonthlyChart(screenWidth),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyChart(double screenWidth) {
    return FutureBuilder<List<FlSpot>>(
      future: _dailyMoodData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text("No mood entries for today yet.",
                  style: TextStyle(color: Colors.white70)));
        }

        return Padding(
          padding: EdgeInsets.only(top: screenWidth * 0.04, right: screenWidth * 0.04),
          child: LineChart(
            LineChartData(
              clipData: FlClipData.none(),
              lineTouchData: LineTouchData(
                distanceCalculator: _customDistanceCalculator,
                enabled: true,
                handleBuiltInTouches: true,
                touchSpotThreshold: 25,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(color: Colors.transparent),
                      FlDotData(
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: Colors.red,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.black.withOpacity(0.8),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipMargin: 12,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((barSpot) {
                      final time = _formatHour(barSpot.x);
                      // ✨ USE MoodService
                      final mood = MoodService.valueToMood(barSpot.y);
                      return LineTooltipItem(
                        '$mood\n',
                        TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.035,
                        ),
                        children: [
                          TextSpan(
                            text: time,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: screenWidth * 0.03,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              minY: 0.5,
              maxY: 5,
              minX: -2.5,
              maxX: 26,
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: _leftTitles(screenWidth)),
                bottomTitles: AxisTitles(sideTitles: _bottomTitlesDaily(screenWidth)),
                rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 55)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.white12, width: 1),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: snapshot.data!,
                  isCurved: false,
                  barWidth: 1,
                  color: Colors.yellow,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 3,
                          color: Colors.amber,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyChart(double screenWidth) {
    return FutureBuilder<List<FlSpot>>(
      future: _weeklyMoodData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text("Not enough data for the week.",
                  style: TextStyle(color: Colors.white70)));
        }

        return Padding(
          padding: EdgeInsets.only(top: screenWidth * 0.04, right: screenWidth * 0.04),
          child: LineChart(
            LineChartData(
              clipData: FlClipData.none(),
              lineTouchData: LineTouchData(
                distanceCalculator: _customDistanceCalculator,
                enabled: true,
                handleBuiltInTouches: true,
                touchSpotThreshold: 25,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(color: Colors.transparent),
                      FlDotData(
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: Colors.red,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.black.withOpacity(0.8),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipMargin: 12,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((barSpot) {
                      // ✨ USE MoodService
                      final mood = MoodService.valueToMood(barSpot.y);
                      final dayIndex = 6 - barSpot.x.toInt();
                      final day = DateFormat.E().format(DateTime.now().subtract(Duration(days: dayIndex)));

                      return LineTooltipItem(
                        '$mood\n',
                        TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.035,
                        ),
                        children: [
                          TextSpan(
                            text: 'Avg on $day',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: screenWidth * 0.03,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              minY: 0.5,
              maxY: 5,
              minX: 0.5,
              maxX: 7.5,
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: _leftTitles(screenWidth)),
                bottomTitles: AxisTitles(sideTitles: _bottomTitlesWeekly(screenWidth)),
                rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.white12, width: 1),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: snapshot.data!,
                  isCurved: false,
                  barWidth: 1,
                  color: Colors.yellow,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 3,
                          color: Colors.amber,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthlyChart(double screenWidth) {
    return FutureBuilder<List<FlSpot>>(
      future: _monthlyMoodData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text("Not enough data for the month.",
                  style: TextStyle(color: Colors.white70)));
        }

        return Padding(
          padding: EdgeInsets.only(top: screenWidth * 0.04, right: screenWidth * 0.04),
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                distanceCalculator: _customDistanceCalculator,
                touchSpotThreshold: 25,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(color: Colors.transparent),
                      FlDotData(
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: Colors.red,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.black.withOpacity(0.8),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((barSpot) {
                      // ✨ USE MoodService
                      final mood = MoodService.valueToMood(barSpot.y);
                      final dayOfMonth = barSpot.x.toInt();
                      final now = DateTime.now();
                      final date = DateTime(now.year, now.month, dayOfMonth);
                      final formattedDate = DateFormat.yMMMd().format(date);

                      return LineTooltipItem(
                        '$mood\n',
                        TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.035,
                        ),
                        children: [
                          TextSpan(
                            text: formattedDate,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: screenWidth * 0.03,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              minY: 0.5,
              maxY: 5,
              minX: -1,
              maxX: 32,
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: _leftTitles(screenWidth)),
                bottomTitles: AxisTitles(sideTitles: _bottomTitlesMonthly(screenWidth)),
                rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.white12, width: 1),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: snapshot.data!,
                  isCurved: false,
                  color: Colors.yellow,
                  barWidth: 1,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 3,
                          color: Colors.amber,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: false,
                    color: Colors.amber.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  SideTitles _bottomTitlesMonthly(double screenWidth) {
    return SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: 1,
      getTitlesWidget: (value, meta) {
        if ((value - 1) % 7 == 0) {
          return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 8.0,
              child: Text(value.toInt().toString(),
                  style: TextStyle(color: Colors.white70, fontSize: screenWidth * 0.03)));
        }
        return Container();
      },
    );
  }

  SideTitles _bottomTitlesWeekly(double screenWidth) {
    return SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: 1,
      getTitlesWidget: (value, meta) {
        if (value < 1 || value > 7) {
          return Container();
        }

        final now = DateTime.now();
        final dayToShow = now.subtract(Duration(days: 7 - value.toInt()));
        final text = DateFormat.E().format(dayToShow);

        return SideTitleWidget(
            axisSide: meta.axisSide,
            space: 8.0,
            child: Text(text,
                style: TextStyle(color: Colors.white70, fontSize: screenWidth * 0.03)));
      },
    );
  }

  SideTitles _bottomTitlesDaily(double screenWidth) {
    return SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: 6,
      getTitlesWidget: (value, meta) {
        String text;
        switch (value.toInt()) {
          case 0: text = '12am'; break;
          case 6: text = '6am'; break;
          case 12: text = '12pm'; break;
          case 18: text = '6pm'; break;
          case 24: text = '12am'; break;
          default: return Container();
        }
        return SideTitleWidget(
            axisSide: meta.axisSide,
            space: 8.0,
            child: Text(text,
                style: TextStyle(color: Colors.white70, fontSize: screenWidth * 0.03)));
      },
    );
  }

  SideTitles _leftTitles(double screenWidth) {
    return SideTitles(
      showTitles: true,
      reservedSize: 39,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final intValue = value.toInt();
        if (intValue < 1 || intValue > 5) {
          return Container();
        }
        // ✨ USE MoodService to get the emoji
        final emoji = MoodService.getChartEmoji(intValue);
        return SideTitleWidget(
          axisSide: meta.axisSide,
          space: 8.0,
          child: Text(
            emoji,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}