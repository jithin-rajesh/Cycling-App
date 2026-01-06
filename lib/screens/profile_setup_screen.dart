import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _preferredNameController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedPronoun;
  
  // Image
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null) {
      _preferredNameController.text = user!.displayName!;
    }
  }

  final List<String> _pronounOptions = [
    'he/him',
    'she/her',
    'they/them',
    'other',
    'prefer not to say',
  ];

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user found');

      String? photoUrl;

      // 1. Upload Image if selected
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_profiles')
            .child('${user.uid}.jpg');
        
        await storageRef.putFile(_imageFile!);
        photoUrl = await storageRef.getDownloadURL();
        
        // Update Auth Profile as well
        await user.updatePhotoURL(photoUrl);
      }

      // 2. Save Data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'preferredName': _preferredNameController.text.trim(),
        'pronouns': _selectedPronoun,
        'birthYear': int.tryParse(_birthYearController.text.trim()),
        'location': _locationController.text.trim(),
        'photoUrl': photoUrl,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update display name in Auth
      if (_preferredNameController.text.isNotEmpty) {
        await user.updateDisplayName(_preferredNameController.text.trim());
      }

      if (mounted) {
        // Navigate to Home and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _preferredNameController.dispose();
    _birthYearController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Photo Picker
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: CruizrTheme.surface,
                      backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                      child: _imageFile == null
                          ? const Icon(Icons.person, size: 60, color: CruizrTheme.textSecondary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: CruizrTheme.primaryMint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: CruizrTheme.background,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Personal Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: CruizrTheme.primaryMint,
                ),
              ),
              const SizedBox(height: 16),

              // Preferred Name
              TextFormField(
                controller: _preferredNameController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Preferred Name',
                  prefixIcon: Icon(Icons.badge_outlined, color: CruizrTheme.primaryMint),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your preferred name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Pronouns Dropdown
              DropdownButtonFormField<String>(
                value: _selectedPronoun,
                dropdownColor: CruizrTheme.surface,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Pronouns',
                  prefixIcon: Icon(Icons.record_voice_over_outlined, color: CruizrTheme.primaryMint),
                ),
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
              const SizedBox(height: 16),

              // Birth Year
              TextFormField(
                controller: _birthYearController,
                keyboardType: TextInputType.number,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Birth Year',
                  hintText: 'e.g. 1995',
                  prefixIcon: Icon(Icons.cake_outlined, color: CruizrTheme.primaryMint),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your birth year';
                  }
                  final year = int.tryParse(value);
                  if (year == null || year < 1900 || year > DateTime.now().year) {
                    return 'Please enter a valid year';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'City, Country',
                  prefixIcon: Icon(Icons.location_on_outlined, color: CruizrTheme.primaryMint),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 48),

              // Submit Button
              FilledButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: CruizrTheme.background,
                        ),
                      )
                    : const Text('Complete Setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
