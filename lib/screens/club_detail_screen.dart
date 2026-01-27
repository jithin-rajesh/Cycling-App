
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/create_post_sheet.dart';
import '../models/club_model.dart';
import '../models/club_post_model.dart';
import '../services/club_service.dart';
import '../theme/app_theme.dart';

class ClubDetailScreen extends StatefulWidget {
  final ClubModel club;

  const ClubDetailScreen({super.key, required this.club});

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> {
  final ClubService _clubService = ClubService();
  bool _isMember = false;
  bool _isLoading = true;
  bool _isBusy = false; // logic processing

  @override
  void initState() {
    super.initState();
    _checkMembership();
  }

  Future<void> _checkMembership() async {
    final isMember = await _clubService.isMember(widget.club.id);
    if (mounted) {
      setState(() {
        _isMember = isMember;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleJoinLeave() async {
    setState(() => _isBusy = true);
    try {
      if (_isMember) {
        await _clubService.leaveClub(widget.club.id);
      } else {
        await _clubService.joinClub(widget.club.id);
      }
      _checkMembership();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CreatePostSheet(clubId: widget.club.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 250.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.club.name,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                background: Image.network(
                  widget.club.imageUrl,
                  fit: BoxFit.cover,
                  color: Colors.black38,
                  colorBlendMode: BlendMode.darken,
                ),
              ),
              actions: [
                if (!_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _isBusy ? null : _handleJoinLeave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isMember ? Colors.white.withOpacity(0.2) : CruizrTheme.accentPink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: _isBusy 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : Text(_isMember ? 'Joined' : 'Join'),
                      ),
                    ),
                  )
              ],
            ),
          ];
        },
        body: _buildPostFeed(),
      ),
      floatingActionButton: _isMember
          ? FloatingActionButton.extended(
              onPressed: _showCreatePostSheet,
              backgroundColor: CruizrTheme.accentPink,
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: const Text('Post', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildPostFeed() {
    return StreamBuilder<List<ClubPostModel>>(
      stream: _clubService.getClubPosts(widget.club.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  _isMember ? 'Be the first to post!' : 'Join to see and share posts.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length + 1, // +1 for padding at bottom FAB
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            if (index == posts.length) return const SizedBox(height: 80);
            return _buildPostCard(posts[index]);
          },
        );
      },
    );
  }

  Widget _buildPostCard(ClubPostModel post) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: post.userAvatar.isNotEmpty ? NetworkImage(post.userAvatar) : null,
                child: post.userAvatar.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    _formatDate(post.timestamp.toDate()),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Content
          if (post.description.isNotEmpty) ...[
            Text(post.description),
            const SizedBox(height: 12),
          ],
          
          // Image
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                post.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}';
  }
}


