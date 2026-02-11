
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'gym_summary_screen.dart';

class GymSessionScreen extends StatefulWidget {
  final String muscleGroup;
  final int exercises;
  final int sets;

  const GymSessionScreen({
    super.key,
    required this.muscleGroup,
    required this.exercises,
    required this.sets,
  });

  @override
  State<GymSessionScreen> createState() => _GymSessionScreenState();
}

class _GymSessionScreenState extends State<GymSessionScreen> {
  late Timer _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration += const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  void _finishWorkout() {
    _timer.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GymSummaryScreen(
          muscleGroup: widget.muscleGroup,
          exercises: widget.exercises,
          sets: widget.sets,
          duration: _duration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'Focus on your ${widget.muscleGroup}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 48),
              
              // Timer Display
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFFBF5F2), width: 8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined, 
                      size: 40, 
                      color: CruizrTheme.accentPink.withValues(alpha: 0.8)
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Session Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   _buildInfoItem('${widget.exercises}', 'Exercises'),
                   _buildInfoItem('${widget.sets}', 'Sets'),
                ],
              ),

              const Spacer(),
              
              // Finish Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _finishWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CruizrTheme.accentPink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Finish Workout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
