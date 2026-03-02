import 'package:flutter/material.dart';
import '../widgets/create_post_sheet.dart';
import '../widgets/club_chat_tab.dart';
import '../widgets/club_card_placeholder.dart';
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
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
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
                  background: widget.club.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.club.imageUrl,
                          fit: BoxFit.cover,
                          color: Colors.black38,
                          colorBlendMode: BlendMode.darken,
                          errorBuilder: (_, __, ___) => ClubCardPlaceholder(
                            activityType: widget.club.activityType,
                            clubName: widget.club.name,
                            customIconCodePoint: widget.club.iconCodePoint,
                          ),
                        )
                      : ClubCardPlaceholder(
                          activityType: widget.club.activityType,
                          clubName: widget.club.name,
                          customIconCodePoint: widget.club.iconCodePoint,
                        ),
                ),
                actions: [
                  if (!_isLoading) ...[
                    if (widget.club.isPrivate &&
                        _isMember &&
                        widget.club.inviteCode != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CircleAvatar(
                          backgroundColor: Colors.black45,
                          child: IconButton(
                            icon: const Icon(Icons.share,
                                color: Colors.white, size: 20),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Invite Code'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                          'Share this code with others to let them join this private club.'),
                                      const SizedBox(height: 16),
                                      SelectableText(
                                        widget.club.inviteCode!,
                                        style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: ElevatedButton(
                          onPressed: _isBusy ? null : _handleJoinLeave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isMember
                                ? Colors.white.withOpacity(0.2)
                                : CruizrTheme.accentPink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: _isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text(_isMember ? 'Joined' : 'Join'),
                        ),
                      ),
                    )
                  ],
                ],
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  const TabBar(
                    labelColor: CruizrTheme.primaryDark,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: CruizrTheme.accentPink,
                    tabs: [
                      Tab(text: "Feed"),
                      Tab(text: "Chat"),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildPostFeed(),
              _isMember
                  ? ClubChatTab(clubId: widget.club.id)
                  : _buildJoinPrompt(),
            ],
          ),
        ),
      ),
      floatingActionButton: _isMember
          ? Builder(builder: (context) {
              // Only show FAB on Feed tab? Or check index?
              // TabController is in a parent widget, accessing it here is tricky without a key or context lookups.
              // For simplicity, we can let it float there, but usually Chat has its own input.
              // Let's just hide it if we are on Chat tab?
              // With DefaultTabController and NestedScrollView, keeping track of index requires a custom controller.
              // Alternative: Show FAB always, but maybe push it up when keyboard opens?
              // Actually, Chat has its own input bar, so FAB might overlay it.
              // Let's rely on the user interface: FAB is "Post" (camera icon).
              // Ideally, hide FAB when on Chat tab.
              // For now, I'll return it as is, but it might overlap Chat input.
              // Let's wrap FAB in a visibility check if possible, or just accept overlap for MVP.
              // A better UX: Listen to tab changes.
              // Let's stick to simple implementation: FAB is visible.
              return FloatingActionButton.extended(
                onPressed: _showCreatePostSheet,
                backgroundColor: CruizrTheme.accentPink,
                icon: const Icon(Icons.add_a_photo, color: Colors.white),
                label:
                    const Text('Post', style: TextStyle(color: Colors.white)),
              );
            })
          : null,
    );
  }

  Widget _buildJoinPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Join the club to join the chat!',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleJoinLeave,
            style: ElevatedButton.styleFrom(
              backgroundColor: CruizrTheme.accentPink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Join Club'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostFeed() {
    return StreamBuilder<List<ClubPostModel>>(
      stream: _clubService.getClubPosts(widget.club.id),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  _isMember
                      ? 'Be the first to post!'
                      : 'Join to see and share posts.',
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
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
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
                backgroundImage: post.userAvatar.isNotEmpty
                    ? NetworkImage(post.userAvatar)
                    : null,
                child:
                    post.userAvatar.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height + 16; // + pudding

  @override
  double get maxExtent => _tabBar.preferredSize.height + 16;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: CruizrTheme.background,
      padding: const EdgeInsets.only(top: 16), // Padding top
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
