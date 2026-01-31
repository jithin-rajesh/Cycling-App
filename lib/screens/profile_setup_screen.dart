import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'onboarding/activities_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final List<String> preSelectedActivities;

  const ProfileSetupScreen({super.key, this.preSelectedActivities = const []});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // Image
  String? _imageUrl;

  // Controllers
  final _preferredNameController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedPronoun;

  final List<String> _pronounOptions = [
    'he/him',
    'she/her',
    'they/them',
    'other',
    'prefer not to say',
  ];

  @override
  void dispose() {
    _preferredNameController.dispose();
    _birthYearController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActivitiesScreen(
          profileData: {
            'preferredName': _preferredNameController.text.trim(),
            'pronouns': _selectedPronoun,
            'birthYear': int.tryParse(_birthYearController.text.trim()),
            'location': _locationController.text.trim(),
            'photoUrl': _imageUrl,
          },
          preSelectedActivities: widget.preSelectedActivities,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Profile Setup',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 20,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CruizrTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CruizrTheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step 1 of 3',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CruizrTheme.accentPink,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Header
              Text(
                'Tell us about\nyourself',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      height: 1.2,
                      fontSize: 40,
                    ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 48),

              // Profile Photo
              Center(
                child: GestureDetector(
                  onTap: () {
                    // TODO: Implement image picker
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: CruizrTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CruizrTheme.border,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 32,
                      color: CruizrTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Add Photo',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 32),

              // Form Fields
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Preferred Name',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              TextField(
                controller: _preferredNameController,
                style: Theme.of(context).textTheme.bodyLarge,
                cursorColor: CruizrTheme.primaryDark,
                decoration: const InputDecoration(
                  hintText: 'What should we call you?',
                ),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Pronouns',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: CruizrTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPronoun,
                    isExpanded: true,
                    hint: Text(
                      'Select pronouns',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: CruizrTheme.textSecondary,
                          ),
                    ),
                    dropdownColor: CruizrTheme.surface,
                    items: _pronounOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedPronoun = newValue;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Birth Year',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              TextField(
                controller: _birthYearController,
                keyboardType: TextInputType.number,
                style: Theme.of(context).textTheme.bodyLarge,
                cursorColor: CruizrTheme.primaryDark,
                decoration: const InputDecoration(
                  hintText: 'e.g. 1995',
                ),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Location',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              TextField(
                controller: _locationController,
                style: Theme.of(context).textTheme.bodyLarge,
                cursorColor: CruizrTheme.primaryDark,
                decoration: const InputDecoration(
                  hintText: 'City, Country',
                ),
              ),
              const SizedBox(height: 48),

              // Next Step Button
              FilledButton(
                onPressed: _goToNextStep,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Next Step'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
