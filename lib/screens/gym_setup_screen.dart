
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'gym_session_screen.dart';

class GymSetupScreen extends StatefulWidget {
  const GymSetupScreen({super.key});

  @override
  State<GymSetupScreen> createState() => _GymSetupScreenState();
}

class _GymSetupScreenState extends State<GymSetupScreen> {
  String _selectedMuscleGroup = 'Full Body';
  int _exercises = 3;
  int _sets = 9;

  final List<String> _muscleGroups = [
    'Full Body',
    'Chest',
    'Back',
    'Legs',
    'Arms',
    'Shoulders',
    'Abs',
    'Cardio'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF5D4037)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Gym Setup',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            color: Color(0xFF5D4037),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New Workout',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Customize your session targets',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),

              // Target Muscle Group
              _buildLabel('Target Muscle Group'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMuscleGroup,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF5D4037)),
                    items: _muscleGroups.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF2D2D2D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedMuscleGroup = newValue!;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Exercises Counter
              _buildCounter(
                'Exercises',
                _exercises,
                (val) => setState(() => _exercises = val.clamp(1, 50)),
              ),

              const SizedBox(height: 24),

              // Sets Counter
              _buildCounter(
                'Total Sets',
                _sets,
                (val) => setState(() => _sets = val.clamp(1, 100)),
              ),

              const Spacer(),

              // Start Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                     Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GymSessionScreen(
                          muscleGroup: _selectedMuscleGroup,
                          exercises: _exercises,
                          sets: _sets,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CruizrTheme.accentPink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Start Workout',
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2D2D2D),
      ),
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChanged) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D2D2D),
            ),
          ),
          Row(
            children: [
              _buildCircleButton(
                icon: Icons.remove,
                onTap: () => onChanged(value - 1),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ),
              _buildCircleButton(
                icon: Icons.add,
                onTap: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFFBF5F2),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFEFEBE9)),
        ),
        child: Icon(icon, color: const Color(0xFF5D4037), size: 20),
      ),
    );
  }
}
