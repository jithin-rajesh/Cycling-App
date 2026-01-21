import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/cruizr_switch.dart';
import '../services/strava_service.dart';



class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Profile data
  String? _photoUrl;
  final _preferredNameController = TextEditingController();
  String? _selectedPronoun;
  final _birthYearController = TextEditingController();
  final _locationController = TextEditingController();
  
  // Activities
  Set<String> _selectedActivities = {};
  
  // Activity level
  String? _activityLevel;
  String _measurementSystem = 'metric';
  
  // Privacy settings
  String _profileVisibility = 'public';
  String _activitySharing = 'followers';
  bool _liveActivitySharing = true;
  
  // Notifications
  bool _activityReminders = true;
  bool _communityUpdates = true;
  bool _achievementCelebrations = false;
  
  // Connected Apps
  bool _isStravaConnected = false;

  final List<String> _pronounOptions = [
    'he/him',
    'she/her',
    'they/them',
    'other',
    'prefer not to say',
  ];

  final List<Map<String, String>> _activities = [
    {'id': 'cycling', 'emoji': '🚴', 'name': 'Cycling'},
    {'id': 'running', 'emoji': '🏃', 'name': 'Running'},
    {'id': 'swimming', 'emoji': '🏊', 'name': 'Swimming'},
    {'id': 'yoga', 'emoji': '🧘', 'name': 'Yoga'},
    {'id': 'hiking', 'emoji': '🥾', 'name': 'Hiking'},
    {'id': 'strength', 'emoji': '🏋️', 'name': 'Strength'},
    {'id': 'tennis', 'emoji': '🎾', 'name': 'Tennis'},
    {'id': 'volleyball', 'emoji': '🏐', 'name': 'Volleyball'},
    {'id': 'soccer', 'emoji': '⚽', 'name': 'Soccer'},
    {'id': 'badminton', 'emoji': '🏸', 'name': 'Badminton'},
  ];

  final List<Map<String, String>> _levels = [
    {'id': 'starting', 'emoji': '🌱', 'name': 'Starting'},
    {'id': 'building', 'emoji': '🌿', 'name': 'Building'},
    {'id': 'active', 'emoji': '🌳', 'name': 'Active'},
    {'id': 'athletic', 'emoji': '⚡', 'name': 'Athletic'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkStravaStatus();
  }
  
  Future<void> _checkStravaStatus() async {
    final connected = await StravaService().isAuthenticated();
    if (mounted) {
        setState(() => _isStravaConnected = connected);
    }
  }

  @override
  void dispose() {
    _preferredNameController.dispose();
    _birthYearController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _photoUrl = data['photoUrl'];
          _preferredNameController.text = data['preferredName'] ?? '';
          _selectedPronoun = data['pronouns'];
          _birthYearController.text = data['birthYear']?.toString() ?? '';
          _locationController.text = data['location'] ?? '';
          
          _selectedActivities = Set<String>.from(data['activities'] ?? []);
          _activityLevel = data['activityLevel'];
          _measurementSystem = data['measurementSystem'] ?? 'metric';
          
          _profileVisibility = data['profileVisibility'] ?? 'public';
          _activitySharing = data['activitySharing'] ?? 'followers';
          _liveActivitySharing = data['liveActivitySharing'] ?? true;
          
          final notifications = data['notifications'] as Map<String, dynamic>? ?? {};
          _activityReminders = notifications['activityReminders'] ?? true;
          _communityUpdates = notifications['communityUpdates'] ?? true;
          _achievementCelebrations = notifications['achievementCelebrations'] ?? false;
          
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'preferredName': _preferredNameController.text.trim(),
        'pronouns': _selectedPronoun,
        'birthYear': int.tryParse(_birthYearController.text.trim()),
        'location': _locationController.text.trim(),
        'activities': _selectedActivities.toList(),
        'activityLevel': _activityLevel,
        'measurementSystem': _measurementSystem,
        'profileVisibility': _profileVisibility,
        'activitySharing': _activitySharing,
        'liveActivitySharing': _liveActivitySharing,
        'notifications': {
          'activityReminders': _activityReminders,
          'communityUpdates': _communityUpdates,
          'achievementCelebrations': _achievementCelebrations,
        },
      });

      // Update display name if changed
      final preferredName = _preferredNameController.text.trim();
      if (preferredName.isNotEmpty && preferredName != user.displayName) {
        await user.updateDisplayName(preferredName);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _signOut() async {
    // Pop all screens to return to AuthGate (root)
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    // Sign out to trigger AuthGate stream
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: CruizrTheme.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo & Name Section
                    _buildProfileHeader(),
                    const SizedBox(height: 32),
                    
                    // Personal Info Section
                    _buildSectionTitle('Personal Info'),
                    const SizedBox(height: 16),
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 32),
                    
                    // Activities Section
                    _buildSectionTitle('Activities'),
                    const SizedBox(height: 16),
                    _buildActivitiesSection(),
                    const SizedBox(height: 32),
                    
                    // Activity Level Section
                    _buildSectionTitle('Activity Level'),
                    const SizedBox(height: 16),
                    _buildActivityLevelSection(),
                    const SizedBox(height: 32),
                    
                    // Privacy Settings Section
                    _buildSectionTitle('Privacy & Safety'),
                    const SizedBox(height: 16),
                    _buildPrivacySection(),
                    const SizedBox(height: 32),
                    
                    // Notifications Section
                    _buildSectionTitle('Notifications'),
                    const SizedBox(height: 16),
                    _buildNotificationsSection(),
                    const SizedBox(height: 32),
                    
                    // Connected Apps
                    _buildSectionTitle('Connected Apps'),
                    const SizedBox(height: 16),
                    _buildConnectedAppsSection(),
                    const SizedBox(height: 32),
                    
                    // Sign Out Button
                    _buildSignOutButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48), // Spacer for balance
          Text(
            'Profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: 'Playfair Display',
              fontStyle: FontStyle.italic,
            ),
          ),
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: CruizrTheme.accentPink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return Center(
      child: Column(
        children: [
          // Profile Photo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CruizrTheme.surface,
              border: Border.all(color: CruizrTheme.border, width: 2),
              image: _photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _photoUrl == null
                ? const Icon(
                    Icons.person,
                    size: 48,
                    color: CruizrTheme.textSecondary,
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            user?.displayName ?? 'User',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: 'Playfair Display',
            ),
          ),
          Text(
            user?.email ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CruizrTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontFamily: 'Playfair Display',
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CruizrTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Preferred Name
          _buildTextField('Preferred Name', _preferredNameController, 'What should we call you?'),
          const SizedBox(height: 16),
          
          // Pronouns Dropdown
          _buildDropdown('Pronouns', _selectedPronoun, _pronounOptions, 
            (value) => setState(() => _selectedPronoun = value)),
          const SizedBox(height: 16),
          
          // Birth Year
          _buildTextField('Birth Year', _birthYearController, 'e.g. 1995', 
            keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          
          // Location
          _buildTextField('Location', _locationController, 'City, Country'),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, 
      {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: Theme.of(context).textTheme.bodyLarge,
          cursorColor: CruizrTheme.primaryDark,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> options, 
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text('Select', style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: CruizrTheme.textSecondary,
              )),
              items: options.map((String v) {
                return DropdownMenuItem<String>(value: v, child: Text(v));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivitiesSection() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _activities.map((activity) {
        final isSelected = _selectedActivities.contains(activity['id']);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedActivities.remove(activity['id']);
              } else {
                _selectedActivities.add(activity['id']!);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? CruizrTheme.accentPink : CruizrTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? CruizrTheme.accentPink : Colors.transparent,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: CruizrTheme.accentPink.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Text(activity['emoji']!, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: isSelected ? Colors.white : CruizrTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                  child: Text(activity['name']!),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityLevelSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CruizrTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Level Selection
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _levels.map((level) {
              final isSelected = _activityLevel == level['id'];
              return GestureDetector(
                onTap: () => setState(() => _activityLevel = level['id']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? CruizrTheme.accentPink : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: CruizrTheme.accentPink.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        child: Text(level['emoji']!, style: const TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          color: isSelected ? CruizrTheme.accentPink : CruizrTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                        child: Text(level['name']!),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          
          // Measurement System Toggle with Sliding Indicator
          LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = (constraints.maxWidth - 8) / 2;
              final selectedIndex = _measurementSystem == 'metric' ? 0 : 1;
              return Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.all(4),
                child: Stack(
                  children: [
                    // Sliding Indicator
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      left: selectedIndex * segmentWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: segmentWidth,
                        decoration: BoxDecoration(
                          color: CruizrTheme.accentPink,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: CruizrTheme.accentPink.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Labels
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _measurementSystem = 'metric'),
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: _measurementSystem == 'metric' 
                                      ? Colors.white : CruizrTheme.textSecondary,
                                ),
                                child: const Text('Metric'),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _measurementSystem = 'imperial'),
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: _measurementSystem == 'imperial' 
                                      ? Colors.white : CruizrTheme.textSecondary,
                                ),
                                child: const Text('Imperial'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CruizrTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Visibility
          Text('Profile Visibility', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          _buildThreeWayToggle(
            options: ['Public', 'Community', 'Private'],
            values: ['public', 'community', 'private'],
            selectedValue: _profileVisibility,
            onChanged: (value) => setState(() => _profileVisibility = value),
          ),
          const SizedBox(height: 20),
          
          // Activity Sharing
          Text('Activity Sharing', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          _buildThreeWayToggle(
            options: ['Everyone', 'Followers', 'Only Me'],
            values: ['everyone', 'followers', 'only_me'],
            selectedValue: _activitySharing,
            onChanged: (value) => setState(() => _activitySharing = value),
          ),
          const SizedBox(height: 20),
          
          // Live Activity Sharing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Activity Sharing', 
                        style: Theme.of(context).textTheme.bodyLarge),
                    Text('Share real-time location with contacts',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CruizrTheme.textSecondary,
                        )),
                  ],
                ),
              ),
              CruizrSwitch(
                value: _liveActivitySharing,
                onChanged: (value) => setState(() => _liveActivitySharing = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThreeWayToggle({
    required List<String> options,
    required List<String> values,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    final selectedIndex = values.indexOf(selectedValue);
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = (constraints.maxWidth - 8) / options.length;
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              // Sliding Indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: selectedIndex * segmentWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  width: segmentWidth,
                  decoration: BoxDecoration(
                    color: CruizrTheme.accentPink,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: CruizrTheme.accentPink.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels
              Row(
                children: List.generate(options.length, (index) {
                  final isSelected = values[index] == selectedValue;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(values[index]),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? Colors.white : CruizrTheme.textSecondary,
                            fontSize: 12,
                          ),
                          child: Text(options[index]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CruizrTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildCheckboxTile('Activity reminders', _activityReminders, 
            (v) => setState(() => _activityReminders = v ?? false)),
          const Divider(height: 24),
          _buildCheckboxTile('Community updates', _communityUpdates,
            (v) => setState(() => _communityUpdates = v ?? false)),
          const Divider(height: 24),
          _buildCheckboxTile('Achievement celebrations', _achievementCelebrations,
            (v) => setState(() => _achievementCelebrations = v ?? false)),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile(String title, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: CruizrTheme.accentPink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 12),
        Text(title, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  Widget _buildConnectedAppsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CruizrTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Strava Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFC4C02), // Strava Orange
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'S',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Strava',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Sync activities & routes',
                      style: TextStyle(
                         color: Colors.grey,
                         fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isStravaConnected)
                TextButton(
                  onPressed: () async {
                      await StravaService().disconnect();
                      await _checkStravaStatus();
                  },
                  child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    await StravaService().authenticate();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC4C02),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Connect'),
                ),
                // Fallback for Desktop/Web where deep links might fail
                // Fallback for manual code entry
                Padding(
                     padding: const EdgeInsets.only(left: 8),
                     child: TextButton(
                       onPressed: _showManualAuthDialog,
                       child: const Text('Enter Code', style: TextStyle(fontSize: 10)),
                     ),
                  ),
            ],
          ),
          if (_isStravaConnected) ...[
             const Padding(
               padding: EdgeInsets.symmetric(vertical: 12),
               child: Divider(),
             ),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text('Auto-upload activities'),
                 CruizrSwitch(value: true, onChanged: (val) {}), 
               ],
             ),
          ]
        ],
      ),
    );
  }

  void _showManualAuthDialog() {
    final TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Authentication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'If the browser does not redirect automatically, copy the "code" parameter from the URL bar and paste it here.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Authorization Code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                 Navigator.pop(context); // Close dialog first
                 final success = await StravaService().handleAuthCallback(code);
                 
                 if (!context.mounted) return; // Check context directly
                 
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(success ? 'Connected!' : 'Failed to connect')),
                 );
                 
                 if (success) {
                     await _checkStravaStatus();
                 }
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _signOut,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: const Text('Sign Out'),
      ),
    );
  }
}
