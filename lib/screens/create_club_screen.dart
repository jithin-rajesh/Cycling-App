import 'package:flutter/material.dart';
import '../services/club_service.dart';
import '../theme/app_theme.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ClubService _clubService = ClubService();

  String _selectedActivityType = 'Cycling';
  bool _isPrivate = false;
  bool _isLoading = false;
  int? _selectedIconCodePoint;

  final List<String> _activityTypes = ['Cycling', 'Running', 'Gym', 'Mixed'];

  // Curated icon set for clubs
  static const List<_ClubIcon> _availableIcons = [
    _ClubIcon(Icons.directions_bike, 'Bike'),
    _ClubIcon(Icons.directions_run, 'Run'),
    _ClubIcon(Icons.fitness_center, 'Gym'),
    _ClubIcon(Icons.groups, 'Group'),
    _ClubIcon(Icons.emoji_events, 'Trophy'),
    _ClubIcon(Icons.local_fire_department, 'Fire'),
    _ClubIcon(Icons.flash_on, 'Bolt'),
    _ClubIcon(Icons.terrain, 'Mountain'),
    _ClubIcon(Icons.pool, 'Swim'),
    _ClubIcon(Icons.sports, 'Sports'),
    _ClubIcon(Icons.pedal_bike, 'Pedal'),
    _ClubIcon(Icons.surfing, 'Surf'),
    _ClubIcon(Icons.self_improvement, 'Yoga'),
    _ClubIcon(Icons.hiking, 'Hike'),
    _ClubIcon(Icons.skateboarding, 'Skate'),
    _ClubIcon(Icons.sports_martial_arts, 'Martial'),
    _ClubIcon(Icons.shield, 'Shield'),
    _ClubIcon(Icons.favorite, 'Heart'),
    _ClubIcon(Icons.star, 'Star'),
    _ClubIcon(Icons.rocket_launch, 'Rocket'),
  ];

  Future<void> _createClub() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _clubService.createClub(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        activityType: _selectedActivityType,
        isPrivate: _isPrivate,
        iconCodePoint: _selectedIconCodePoint,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating club: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Club'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Playfair Display',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Club Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a club name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedActivityType,
                decoration: const InputDecoration(
                  labelText: 'Activity Focus',
                  border: OutlineInputBorder(),
                ),
                items: _activityTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedActivityType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // Icon Picker
              const Text(
                'Choose an Icon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair Display',
                  color: CruizrTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pick an icon to represent your club',
                style: TextStyle(
                  fontSize: 13,
                  color: CruizrTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availableIcons.map((clubIcon) {
                  final isSelected =
                      _selectedIconCodePoint == clubIcon.icon.codePoint;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIconCodePoint =
                            isSelected ? null : clubIcon.icon.codePoint;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CruizrTheme.accentPink.withValues(alpha: 0.15)
                            : CruizrTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? CruizrTheme.accentPink
                              : CruizrTheme.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        clubIcon.icon,
                        size: 26,
                        color: isSelected
                            ? CruizrTheme.accentPink
                            : CruizrTheme.textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Private Club'),
                subtitle: const Text('Members can only join via invite code'),
                value: _isPrivate,
                onChanged: (value) {
                  setState(() {
                    _isPrivate = value;
                  });
                },
                activeColor: CruizrTheme.accentPink,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createClub,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CruizrTheme.accentPink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create Club',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClubIcon {
  final IconData icon;
  final String label;
  const _ClubIcon(this.icon, this.label);
}
