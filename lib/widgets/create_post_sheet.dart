
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/club_service.dart';
import '../theme/app_theme.dart';

class CreatePostSheet extends StatefulWidget {
  final String? clubId; // If null, allow selecting club? For now assume passed or we pick one.
  // Actually, if called from Activity Summary, we might need to pick a club. 
  // Let's assume we pass a list of clubIds if clubId is null?
  // To keep it simple for now, let's say we pass the first club the user is in, or prompts user.
  
  // User Requirement: "generic clubs".
  // Let's just pass a specific clubId for now or let the user pick in a separate step?
  // Use case: User finishes activity -> "Share to Club" -> Select Club -> Create Post.
  
  // Let's stick to the current implementation where clubId is required. 
  // The caller handles club selection.
  
  final String? activityId;
  final String? defaultDescription;

  const CreatePostSheet({
    super.key, 
    required this.clubId, 
    this.activityId,
    this.defaultDescription,
  });

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  late TextEditingController _textController;
  File? _selectedImage;
  bool _isPosting = false;
  final ClubService _clubService = ClubService();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.defaultDescription ?? '');
  }
  
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _submitPost() async {
    if (_textController.text.trim().isEmpty && _selectedImage == null) return;

    setState(() => _isPosting = true);

    try {
      String? imageUrl;
      
      // Upload image if present
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('club_posts')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      await _clubService.createPost(
        widget.clubId!,
        _textController.text.trim(),
        imageUrl,
        widget.activityId,
      );

      if (mounted) Navigator.pop(context, true); // Return true on success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clubId == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Create Post',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Share your workout...',
              border: InputBorder.none,
            ),
          ),
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedImage!, height: 100, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.image, color: Colors.blue),
                tooltip: 'Add Image',
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isPosting ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CruizrTheme.accentPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isPosting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('Post'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
