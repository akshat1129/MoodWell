// lib/main.dart - Complete Code with New UI and Model Logic
import 'dart:math';
import 'dart:ui';
import 'package:animated_digit/animated_digit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:simple_animations/simple_animations.dart';

// Assuming you have these files in your project
import 'detailed_view.dart';
import 'mood_service.dart'; // Restored import
import 'sentiment_analyzer.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoodWell',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink.shade200),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // --- State Variables ---
  final PageController _pageController = PageController(viewportFraction: 0.35);
  final TextEditingController _notesController = TextEditingController();
  final SentimentAnalyzer _analyzer = SentimentAnalyzer();

  int _selectedMoodIndex = 2; // Default to 'Neutral'
  late Color _backgroundColor;
  bool _isModelLoaded = false;
  bool _isSubmitting = false;
  bool _isAuthReady = false;

  final List<Mood> _moods = MoodService.moods;

  @override
  void initState() {
    super.initState();
    _backgroundColor = _moods[_selectedMoodIndex].color;
    _ensureUserIsSignedIn();
    _loadModel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.animateToPage(
        _selectedMoodIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  Route _createBlurInRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final blurTween = Tween<double>(begin: 5.0, end: 0.0);
        final blurAnimation =
        animation.drive(blurTween.chain(CurveTween(curve: Curves.easeInOut)));

        return FadeTransition(
          opacity: animation,
          child: AnimatedBuilder(
            animation: blurAnimation,
            builder: (context, child) {
              return ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: blurAnimation.value,
                  sigmaY: blurAnimation.value,
                ),
                child: child,
              );
            },
            child: child,
          ),
        );
      },
    );
  }

  Future<Map<String, int>> _updateStreak(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final streakDocRef = FirebaseFirestore.instance.collection('streaks').doc(userId);

    try {
      final streakDoc = await streakDocRef.get();

      int oldStreak = 0;
      int newStreak = 1;
      DateTime streakStartDate = today;

      if (streakDoc.exists && streakDoc.data() != null) {
        final data = streakDoc.data()!;
        oldStreak = data['currentStreak'] as int? ?? 0;

        // Handle lastEntryDate properly
        if (data['lastEntryDate'] != null) {
          final lastEntryTimestamp = data['lastEntryDate'] as Timestamp;
          final lastEntryDate = lastEntryTimestamp.toDate().toLocal();
          final lastEntryDay = DateTime(lastEntryDate.year, lastEntryDate.month, lastEntryDate.day);

          final difference = today.difference(lastEntryDay).inDays;

          if (difference == 0) {
            newStreak = oldStreak; // Same day
          } else if (difference == 1) {
            newStreak = oldStreak + 1; // Consecutive day
          } else {
            newStreak = 1; // Streak broken
          }

          // Get existing streak start date if continuing
          if (newStreak > 1 && data['streakStartDate'] != null) {
            streakStartDate = (data['streakStartDate'] as Timestamp).toDate();
          }
        }
      }

      // Save with proper timestamp
      await streakDocRef.set({
        'currentStreak': newStreak,
        'lastEntryDate': Timestamp.now(), // Use Timestamp.now() instead of FieldValue
        'userId': userId,
        'streakStartDate': Timestamp.fromDate(streakStartDate),
      });

      return {'old': oldStreak, 'new': newStreak};
    } catch (e) {
      print('Error updating streak: $e');
      return {'old': 0, 'new': 1};
    }
  }

  Future<void> _showStreakDialog(int oldStreak, int newStreak) async {
    // Only show if streak actually increased
    if (newStreak <= oldStreak) return;

    if (!mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          // Auto-close after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          });

          return AlertDialog(
            backgroundColor: Colors.deepPurple.shade400,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Streak Increased!",
                  style: TextStyle(
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                      color: Colors.white
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Simple text display instead of AnimatedDigit if that's causing issues
                    Text(
                      newStreak.toString(),
                      style: TextStyle(
                          fontSize: screenWidth * 0.15,
                          color: Colors.yellowAccent,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      "🔥",
                      style: TextStyle(fontSize: screenWidth * 0.12),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Days in a row!",
                  style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      color: Colors.white70
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print("Error showing streak dialog: $e");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _notesController.dispose();
    _analyzer.close();
    super.dispose();
  }

  // --- Logic Methods ---

  Future<void> _loadModel() async {
    final bool success = await _analyzer.loadModel();
    if (success && mounted) {
      setState(() {
        _isModelLoaded = true;
      });
    }
  }

  Future<void> _ensureUserIsSignedIn() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Only sign in if no user is found
        await FirebaseAuth.instance.signInAnonymously();
        print("User signed in anonymously.");
      } else {
        print("User ${user.uid} is already signed in.");
      }

      if (mounted) {
        setState(() { _isAuthReady = true; });
      }
    } catch (e) {
      print("Failed to ensure user is signed in: $e");
    }
  }

  Future<void> _submitEntry() async {
    if (!_isModelLoaded || !_isAuthReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the app to initialize...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication error. Please restart the app.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() { _isSubmitting = true; });

    final notes = _notesController.text.trim();
    final selectedMood = _moods[_selectedMoodIndex];

    try {
      // Analyze sentiment
      String textSentiment = "neutral";
      if (notes.isNotEmpty) {
        final predictionMap = _analyzer.predict(notes);
        textSentiment = predictionMap['label'] as String? ?? "neutral";
      }

      // First, save the entry
      await FirebaseFirestore.instance.collection('entries').add({
        'userId': user.uid,
        'mood': selectedMood.name,
        'notes': notes,
        'predictedSentiment': textSentiment,
        'timestamp': Timestamp.now(), // Use Timestamp.now() directly
      });

      // Then update streak
      final streakValues = await _updateStreak(user.uid);
      final int oldStreak = streakValues['old']!;
      final int newStreak = streakValues['new']!;

      // Show streak dialog if increased
      if (mounted && newStreak > oldStreak) {
        await _showStreakDialog(oldStreak, newStreak);
      }

      // Get final streak data
      final streakDoc = await FirebaseFirestore.instance
          .collection('streaks')
          .doc(user.uid)
          .get();

      final int finalStreak = streakDoc.data()?['currentStreak'] ?? 1;
      final DateTime streakStartDate = streakDoc.data()?['streakStartDate'] != null
          ? (streakDoc.data()!['streakStartDate'] as Timestamp).toDate()
          : DateTime.now();

      if (!mounted) return;

      // Navigate to details page
      await Navigator.push(
        context,
        _createBlurInRoute(
          EntryDetailsPage(
            mood: selectedMood.name,
            notes: notes,
            hasLoggedToday: true,
            currentStreak: finalStreak,
            streakStartDate: streakStartDate,
          ),
        ),
      );

      // Clear form after returning
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _notesController.clear();
        });
      }

    } catch (e, stackTrace) {
      print("🚨 ERROR DURING SUBMISSION: $e");
      print("🚨 STACK TRACE: $stackTrace");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // --- UI Helper Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        color: _backgroundColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const SizedBox(height: 40),
                _buildTitle(),
                const SizedBox(height: 30),
                _buildMoodSelector(),
                const Spacer(),
                _buildNotesField(),
                const SizedBox(height: 16),
                _buildLogButton(),
                const SizedBox(height: 16),
                _buildActionCards(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const CircleAvatar(radius: 18, backgroundColor: Colors.white),
        const Spacer(),
        Text(
          DateFormat('EEEE, d MMM').format(DateTime.now()),
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const Spacer(),
        IconButton(icon: const Icon(Icons.add, size: 28), onPressed: () {}),
      ],
    );
  }

  Widget _buildTitle() {
    return const Text(
      'How are you\nfeeling today?',
      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.2),
    );
  }

  Widget _buildMoodSelector() {
    return SizedBox(
      height: 120,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _moods.length,
        onPageChanged: (index) {
          setState(() {
            _selectedMoodIndex = index;
            _backgroundColor = _moods[index].color;
          });
        },
        itemBuilder: (context, index) {
          final mood = _moods[index];
          return AnimatedScale(
            scale: _selectedMoodIndex == index ? 1.0 : 0.7,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (_selectedMoodIndex == index)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: Icon(mood.icon, size: 35, color: mood.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mood.name,
                    style: TextStyle(
                      fontWeight: _selectedMoodIndex == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotesField() {
    final selectedMoodName = _moods[_selectedMoodIndex].name.toLowerCase();
    return TextField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: "What's making you feel $selectedMoodName?",
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildLogButton() {
    // Button is disabled until model is loaded and auth is ready
    final bool isButtonEnabled = _isModelLoaded && _isAuthReady && !_isSubmitting;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          disabledBackgroundColor: Colors.grey.shade700,
        ),
        onPressed: isButtonEnabled ? _submitEntry : null,
        child: _isSubmitting
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
            : const Text(
          'Log',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildActionCards() {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            title: 'See Nearby Therapists',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionCard(
            title: 'View Log Calendar',
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

// Reusable card widget
class _ActionCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _ActionCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.arrow_forward, size: 20, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}