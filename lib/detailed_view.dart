// lib/detailed_view.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

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

  String _valueToMood(double value) {
    switch (value.round()) {
      case 5:
        return "Very Good";
      case 4:
        return "Good";
      case 3:
        return "Neutral";
      case 2:
        return "Low";
      case 1:
        return "Very Low";
      default:
        return "Unknown";
    }
  }

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

  double _moodToValue(String mood) {
    switch (mood) {
      case "Very Good":
        return 5.0;
      case "Good":
        return 4.0;
      case "Neutral":
        return 3.0;
      case "Low":
        return 2.0;
      case "Very Low":
        return 1.0;
      default:
        return 0.0;
    }
  }

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
      final moodValue = _moodToValue(doc.data()['mood']);
      final hour = localTimestamp.hour.toDouble() + (localTimestamp.minute.toDouble() / 60.0);
      return FlSpot(hour, moodValue);
    }).toList();

    final currentHour = nowLocal.hour.toDouble() + (nowLocal.minute.toDouble() / 60.0);
    final currentMoodValue = _moodToValue(widget.mood);
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
      final moodValue = _moodToValue(data['mood']);

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
      final moodValue = _moodToValue(data['mood']);
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
        title: const Text('Entry Saved!'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade800],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(screenWidth * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Mood Today:',
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
                    fontSize: baseFontSize * 1.8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  'Your Notes:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: baseFontSize,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
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
    final List<Widget> calendarDays = [];
    final int streakBlock = ((widget.currentStreak - 1) / 10).floor();
    final DateTime calendarStartDate =
    widget.streakStartDate.add(Duration(days: streakBlock * 10));

    final baseFontSize = screenWidth * 0.04;

    for (int i = 0; i < 10; i++) {
      final date = calendarStartDate.add(Duration(days: i));
      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      final bool isMarked = date.isBefore(now) || isToday;

      calendarDays.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015, horizontal: screenWidth * 0.02),
          width: screenWidth * 0.16,
          decoration: BoxDecoration(
            color: isMarked
                ? Colors.deepPurple.shade300.withOpacity(0.8)
                : Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: isToday
                ? Border.all(color: Colors.deepPurple.shade200, width: 2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat.E().format(date),
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: baseFontSize * 0.9),
              ),
              SizedBox(height: screenHeight * 0.005),
              Text(
                date.day.toString(),
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: baseFontSize * 1.1),
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

    return Column(
      children: [
        Text(
          "Your Streak Calendar",
          style: TextStyle(color: Colors.white70, fontSize: baseFontSize * 0.9),
        ),
        SizedBox(height: screenHeight * 0.015),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: calendarDays),
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
            // ✨ REMOVED the boxShadow property to ditch the glow
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
                      final mood = _valueToMood(barSpot.y);
                      return LineTooltipItem(
                        '$mood\n',
                        TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          // ✨ Responsive font size
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
                  barWidth: 0,
                  color: Colors.transparent,
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
                      final mood = _valueToMood(barSpot.y);
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
                      final mood = _valueToMood(barSpot.y);
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
                  isCurved: true,
                  color: Colors.amber,
                  barWidth: 3,
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
                    show: true,
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
      reservedSize: 55,
      interval: 1,
      getTitlesWidget: (value, meta) {
        String emoji;
        switch (value.toInt()) {
          case 1:
            emoji = '😞';
            break;
          case 2:
            emoji = '🙁';
            break;
          case 3:
            emoji = '😐';
            break;
          case 4:
            emoji = '😊';
            break;
          case 5:
            emoji = '😁';
            break;
          default:
            return Container();
        }
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