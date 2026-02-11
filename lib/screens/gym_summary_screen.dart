
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/muscle_map_widget.dart';
import '../models/activity_model.dart';
import '../services/activity_service.dart';

class GymSummaryScreen extends StatefulWidget {
  final String muscleGroup;
  final int exercises;
  final int sets;
  final Duration duration;

  const GymSummaryScreen({
    super.key,
    required this.muscleGroup,
    required this.exercises,
    required this.sets,
    required this.duration,
  });

  @override
  State<GymSummaryScreen> createState() => _GymSummaryScreenState();
}

class _GymSummaryScreenState extends State<GymSummaryScreen> {
  bool _isSaving = false;

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else {
      int hours = duration.inHours;
      int minutes = duration.inMinutes.remainder(60);
      return '${hours}h ${minutes}m';
    }
  }

  Future<void> _saveActivity() async {
    setState(() {
      _isSaving = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Not logged in')),
        );
         setState(() {
           _isSaving = false;
         });
      }
      return;
    }

    try {
      final activity = ActivityModel(
        id: '', // Firestore generates this
        userId: user.uid,
        type: 'Gym',
        startTime: DateTime.now().subtract(widget.duration),
        endTime: DateTime.now(),
        distance: 0.0, // No distance for gym
        duration: widget.duration,
        calories: widget.duration.inMinutes * 5.0, // Rough estimate: 5 cal/min
        elevationGain: 0.0,
        polyline: [],
        gymMuscleGroup: widget.muscleGroup,
        gymExercises: widget.exercises,
        gymSets: widget.sets,
      );

      await ActivityService().saveActivity(activity);

      if (mounted) {
        // Go back to Home (pop until first)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving activity: $e')),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4E4E4E), // Dark grey background like ss
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Text(
                  'DAY ${DateTime.now().day}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatItem('duration', _formatDuration(widget.duration)),
                    const SizedBox(width: 8), // Small spacer
                    Container(width: 1, height: 40, color: Colors.white24),
                    const SizedBox(width: 8),
                    _buildStatItem('Exercises', '${widget.exercises} exercises'),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 40, color: Colors.white24),
                    const SizedBox(width: 8),
                    _buildStatItem('Sets', '${widget.sets} sets'),
                  ],
                ),

                const SizedBox(height: 40),

                // Muscle Map Visualization
                Expanded(
                  child: Center(
                    child: MuscleMapWidget(activeMuscleGroup: widget.muscleGroup),
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),

            // Save Button at bottom
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveActivity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save & Finish',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
             // Close button top right
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                   // Confirm discard? Or just navigate home?
                   // For now, assume discard or user just checking.
                    showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Discard Workout?'),
                      content: const Text('If you leave now, your progress will not be saved.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Close dialog
                            Navigator.of(context).popUntil((route) => route.isFirst); // Go home
                          },
                          child: const Text('Discard', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white60,
            
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
