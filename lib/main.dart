// lib/main.dart

import 'package:flutter/material.dart';
import 'detailed_view.dart';
import 'mood_service.dart';
import 'sentiment_analyzer.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animated_digit/animated_digit.dart';
import 'dart:math';
import 'package:simple_animations/simple_animations.dart';
import 'package:intl/intl.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
  double _currentValue = 0.5;
  final _textController = TextEditingController();
  bool _isBlurred = false;
  bool _isSubmitting = false;
  bool _isAuthReady = false;
  bool _hasLoggedToday = false;
  final SentimentAnalyzer _analyzer = SentimentAnalyzer();
  bool _isModelLoaded = false;

  @override
  void initState() {
    super.initState();
    _signInAnonymously();
    _loadModel();
  }

  Future<void> _loadModel() async {
    print("🕵️‍♂️ Loading model...");

    final bool success = await _analyzer.loadModel();

    if (success && mounted) {
      setState(() {
        _isModelLoaded = true;
      });
    }
  }

  Future<void> _signInAnonymously() async {
    print("🕵️‍♂️ Signing in...");
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (mounted) {
        setState(() {
          _isAuthReady = true;
        });
        print("✅ Auth is ready!");
        _checkTodaysLog();
      }
    } catch (e) {
      print("🚨 FAILED to sign in: $e");
    }
  }

  Future<void> _checkTodaysLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final streakDocRef =
    FirebaseFirestore.instance.collection('streaks').doc(user.uid);
    final streakDoc = await streakDocRef.get();

    if (streakDoc.exists) {
      final lastEntryTimestamp =
      streakDoc.data()!['lastEntryDate'] as Timestamp;
      final lastEntryDate = lastEntryTimestamp.toDate();
      final now = DateTime.now();

      if (lastEntryDate.year == now.year &&
          lastEntryDate.month == now.month &&
          lastEntryDate.day == now.day) {
        if (mounted) {
          setState(() {
            _hasLoggedToday = true;
          });
        }
      }
    }
  }

  Future<Map<String, int>> _updateStreak(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final streakDocRef =
    FirebaseFirestore.instance.collection('streaks').doc(userId);
    final streakDoc = await streakDocRef.get();

    int oldStreak = 0;
    int newStreak = 1;
    DateTime lastEntryDate = now; // Default to now

    if (streakDoc.exists) {
      final data = streakDoc.data()!;
      oldStreak = data['currentStreak'] as int;
      final lastEntryTimestamp = data['lastEntryDate'] as Timestamp;
      lastEntryDate = lastEntryTimestamp.toDate().toLocal(); // Convert to local
      final lastEntryDay =
      DateTime(lastEntryDate.year, lastEntryDate.month, lastEntryDate.day);

      final difference = today.difference(lastEntryDay).inDays;

      if (difference == 0) {
        newStreak = oldStreak;
      } else if (difference == 1) {
        newStreak = oldStreak + 1;
      } else {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }

    DateTime streakStartDate;
    if (newStreak == 1) {
      streakStartDate = today;
    } else {
      streakStartDate = today.subtract(Duration(days: newStreak - 1));
    }

    await streakDocRef.set({
      'currentStreak': newStreak,
      'lastEntryDate': FieldValue.serverTimestamp(),
      'userId': userId,
      'streakStartDate': Timestamp.fromDate(streakStartDate),
    });

    return {'old': oldStreak, 'new': newStreak};
  }

  Future<void> _submitEntry(String notes) async {
    // The user check and setState for submitting remain the same
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
      _isBlurred = true;
    });

    try {
      String textSentiment = "neutral"; // A default value
      if (notes.isNotEmpty && _isModelLoaded) {
        final predictionMap = _analyzer.predict(notes);
        textSentiment = predictionMap['label'] as String;
      }
      // Log the prediction to the console to see it working!
      print("Model's prediction for the text is: $textSentiment");


      final streakValues = await _updateStreak(user.uid);
      final int oldStreak = streakValues['old']!;
      final int newStreak = streakValues['new']!;

      //Prediction
      await FirebaseFirestore.instance.collection('entries').add({
        'userId': user.uid,
        'mood': MoodService.getMoodText(_currentValue), // The slider's mood
        'notes': notes,
        'predictedSentiment': textSentiment, // 💾 The model's prediction
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _hasLoggedToday = true;
      });

      // The rest of your function remains exactly the same...
      if (mounted) {
        await _showStreakDialog(oldStreak, newStreak);
      }
      if (!mounted) return;

      final streakDoc = await FirebaseFirestore.instance.collection('streaks').doc(user.uid).get();
      final int finalStreak = streakDoc.data()?['currentStreak'] ?? 1;
      final DateTime streakStartDate = (streakDoc.data()?['streakStartDate'] as Timestamp? ?? Timestamp.now()).toDate();

      await Navigator.push(
        context,
        _createBlurInRoute(
          EntryDetailsPage(
            mood: MoodService.getMoodText(_currentValue),
            notes: notes,
            hasLoggedToday: _hasLoggedToday,
            currentStreak: finalStreak,
            streakStartDate: streakStartDate,
          ),
        ),
      );

      setState(() {
        _isBlurred = false;
        _isSubmitting = false;
        _textController.clear();
        _currentValue = 0.5;
      });

    } catch (e, stackTrace) {
      print("🚨🚨🚨 ERROR DURING SUBMISSION: $e");
      print("🚨 STACK TRACE: $stackTrace");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit entry. Please check console.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {
        _isBlurred = false;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _showStreakDialog(int oldStreak, int newStreak) async {
    if (newStreak <= oldStreak) return;

    final screenWidth = MediaQuery.of(context).size.width;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(dialogContext).pop();
        });

        return AlertDialog(
          backgroundColor: Colors.deepPurple.shade400,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Streak Increased!",
                style: TextStyle(
                  // ✨ Responsive font size
                    fontSize: screenWidth * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedDigitWidget(
                    value: newStreak,
                    textStyle: TextStyle(
                      // ✨ Responsive font size
                        fontSize: screenWidth * 0.15,
                        color: Colors.yellowAccent,
                        fontWeight: FontWeight.bold),
                    duration: const Duration(seconds: 1),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    "🔥",
                    // ✨ Responsive font size
                    style: TextStyle(fontSize: screenWidth * 0.12),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Days in a row!",
                style: TextStyle(fontSize: screenWidth * 0.045, color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
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

  @override
  void dispose() {
    _textController.dispose();
    _analyzer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = MoodService.calculateAnimatedGradient(_currentValue);
    final moodText = MoodService.getMoodText(_currentValue);
    final moodEmoji = MoodService.getMoodEmoji(_currentValue);

    // ✨ Get screen dimensions once for responsive calculations
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // ✨ Base font size for scaling
    final baseFontSize = screenWidth * 0.05;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(gradient: gradient),
            width: double.infinity,
            height: double.infinity,
          ),
          const AnimatedParticleBackground(),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    // ✨ Responsive padding
                    padding: EdgeInsets.only(top: screenHeight * 0.02),
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: baseFontSize * 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.06),
                  Column(
                    children: [
                      Padding(
                        // ✨ Responsive padding
                        padding: EdgeInsets.only(bottom: screenHeight * 0.025),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Text(
                            moodEmoji,
                            key: ValueKey(moodEmoji),
                            style: TextStyle(fontSize: baseFontSize * 3.5),
                          ),
                        ),
                      ),
                      Text(
                        moodText,
                        style: TextStyle(
                          fontSize: baseFontSize * 1.8,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.7,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      Padding(
                        // ✨ Responsive padding
                        padding: EdgeInsets.only(bottom: screenHeight * 0.03),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                          width: screenWidth * 0.9,
                          height: screenHeight * 0.05,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 0,
                              thumbShape: RoundSliderThumbShape(
                                // ✨ Responsive thumb radius
                                  enabledThumbRadius: screenHeight * 0.025),
                              overlayShape: RoundSliderOverlayShape(
                                // ✨ Responsive overlay radius
                                  overlayRadius: screenHeight * 0.035),
                              thumbColor: Colors.white,
                              activeTrackColor: Colors.transparent,
                              inactiveTrackColor: Colors.transparent,
                            ),
                            child: Slider(
                              value: _currentValue,
                              min: 0,
                              max: 1,
                              onChanged: (double value) {
                                setState(() {
                                  _currentValue = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                        child: TextField(
                          controller: _textController,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: baseFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: Colors.white,
                          minLines: 7,
                          maxLines: 12,
                          decoration: InputDecoration(
                            hintText: "What's going on in your mind?",
                            hintStyle: TextStyle(
                              color: Colors.white,
                              fontSize: baseFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  SizedBox(
                    width: screenWidth * 0.9,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                      ),

                      onPressed: _isSubmitting || !_isAuthReady || !_isModelLoaded
                          ? null
                          : () async {
                        final String notes =
                        _textController.text.trim();

                        if (notes.isEmpty) {
                          final bool? shouldSubmit =
                          await showGeneralDialog<bool>(
                            context: context,
                            barrierDismissible: true,
                            barrierLabel: MaterialLocalizations.of(context)
                                .modalBarrierDismissLabel,
                            transitionDuration:
                            const Duration(milliseconds: 400),
                            pageBuilder: (context, anim1, anim2) {
                              return BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 5, sigmaY: 5),
                                child: AlertDialog(
                                  backgroundColor:
                                  Colors.black.withOpacity(0.2),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(15)),
                                  title: const Text(
                                    'Confirm Submission',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: const Text(
                                    'You haven\'t written any notes. Are you sure you want to submit?',
                                    style:
                                    TextStyle(color: Colors.white70),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context)
                                              .pop(false),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text(
                                        'Yes, Submit',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                            FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            transitionBuilder: (context, animation,
                                secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.1),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOut)),
                                  child: child,
                                ),
                              );
                            },
                          );

                          if (shouldSubmit == true) {
                            await _submitEntry("");
                          }
                        } else {
                          await _submitEntry(notes);
                        }
                      },
                      child: _isSubmitting
                          ? const CircularProgressIndicator(
                          color: Colors.white)
                          : Text(
                        'Submit Entry',
                        style: TextStyle(
                            fontSize: baseFontSize, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.035),
                ],
              ),
            ),
          ),
          if (_isBlurred)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                color: Colors.black.withOpacity(0.1),
              ),
            ),
        ],
      ),
    );
  }
}

class AnimatedParticleBackground extends StatefulWidget {
  const AnimatedParticleBackground({super.key});

  @override
  State<AnimatedParticleBackground> createState() =>
      _AnimatedParticleBackgroundState();
}

class _AnimatedParticleBackgroundState extends State<AnimatedParticleBackground> {
  final List<ParticleModel> particles =
  List.generate(100, (index) => ParticleModel());

  @override
  Widget build(BuildContext context) {
    return LoopAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 1),
      curve: Curves.linear,
      builder: (context, value, child) {
        for (var particle in particles) {
          particle.updatePosition();
        }
        return CustomPaint(
          painter: ParticlePainter(particles),
        );
      },
    );
  }
}

class ParticlePainter extends CustomPainter {
  final List<ParticleModel> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    for (var particle in particles) {
      particle.draw(canvas, size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ParticleModel {
  late double x;
  late double y;
  late double size;
  late double speedX;
  late double speedY;

  ParticleModel() {
    _init();
  }

  void _init() {
    final random = Random();
    x = random.nextDouble();
    y = random.nextDouble();
    size = random.nextDouble() * 2.5 + 0.5;

    speedX = (random.nextDouble() - 0.5) * 0.0005;
    speedY = (random.nextDouble() - 0.5) * 0.0005;
  }

  void updatePosition() {
    x += speedX;
    y += speedY;

    if (x < 0) x = 1.0;
    if (x > 1.0) x = 0;
    if (y < 0) y = 1.0;
    if (y > 1.0) y = 0;
  }

  void draw(Canvas canvas, Size size, Paint paint) {
    final position = Offset(x * size.width, y * size.height);
    canvas.drawCircle(position, this.size, paint);
  }
}