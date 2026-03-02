import 'package:flutter/material.dart';
import '../models/club_model.dart';
import '../services/club_service.dart';
import '../theme/app_theme.dart';
import '../widgets/club_card_placeholder.dart';
import 'club_detail_screen.dart';
import 'create_club_screen.dart';

class ClubsTab extends StatefulWidget {
  const ClubsTab({super.key});

  @override
  State<ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends State<ClubsTab> {
  final ClubService _clubService = ClubService();
  List<ClubModel> _clubs = [];
  bool _isLoading = true;
  String _selectedActivityFilter = 'All';

  final List<String> _activityFilters = [
    'All',
    'Cycling',
    'Running',
    'Gym',
    'Mixed'
  ];

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    setState(() => _isLoading = true);
    try {
      final clubs =
          await _clubService.getClubs(activityType: _selectedActivityFilter);
      if (mounted) {
        setState(() {
          _clubs = clubs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Handle error gracefully
      }
    }
  }

  Future<void> _handleClubTap(ClubModel club) async {
    bool isMember = await _clubService.isMember(club.id);

    // Check if user is an admin (creator), who can always bypass
    // We don't have current user ID easily available without extra call or passed context,
    // but service handles authorization.
    // For UI flow:

    if (club.isPrivate && !isMember) {
      // Show dialog to enter code
      if (!mounted) return;
      _showJoinPrivateClubDialog(club);
    } else {
      _navigateToDetail(club);
    }
  }

  void _navigateToDetail(ClubModel club) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubDetailScreen(club: club),
      ),
    ).then((_) => _loadClubs()); // Refresh on return
  }

  Future<void> _showJoinByCodeDialog() async {
    final codeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Private Club'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the invite code shared with you.'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
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
              if (codeController.text.isEmpty) return;

              try {
                // Show loading or disable button... simple awaiting here
                final club = await _clubService
                    .joinClubByCode(codeController.text.trim());

                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  if (club != null) {
                    _navigateToDetail(club);
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: CruizrTheme.accentPink),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _showJoinPrivateClubDialog(ClubModel club) async {
    final codeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join ${club.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This is a private club. Please enter the invite code to join.'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
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
              try {
                await _clubService.joinClub(club.id,
                    code: codeController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  _navigateToDetail(club);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to join: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CruizrTheme.accentPink,
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Assumes parent background
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateClubScreen()),
          );
          if (result == true) {
            _loadClubs();
          }
        },
        backgroundColor: CruizrTheme.accentPink,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter Chips & Join Code
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ActionChip(
                  avatar:
                      const Icon(Icons.vpn_key, size: 16, color: Colors.white),
                  label: const Text('Join via Code'),
                  backgroundColor: CruizrTheme.primaryDark,
                  labelStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  onPressed: _showJoinByCodeDialog,
                ),
                const SizedBox(width: 8),
                ..._activityFilters.map((filter) {
                  final isSelected = _selectedActivityFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedActivityFilter = filter;
                          });
                          _loadClubs();
                        }
                      },
                      selectedColor: CruizrTheme.accentPink.withOpacity(0.2),
                      checkmarkColor: CruizrTheme.accentPink,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? CruizrTheme.accentPink
                            : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _clubs.isEmpty
                    ? const Center(
                        child: Text('No clubs found matching your criteria.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _clubs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final club = _clubs[index];
                          return _buildClubCard(club);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubCard(ClubModel club) {
    return GestureDetector(
      onTap: () => _handleClubTap(club),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background: gradient placeholder or network image
              if (club.imageUrl.isNotEmpty)
                Image.network(
                  club.imageUrl,
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.4),
                  colorBlendMode: BlendMode.darken,
                  errorBuilder: (_, __, ___) => ClubCardPlaceholder(
                    activityType: club.activityType,
                    clubName: club.name,
                    customIconCodePoint: club.iconCodePoint,
                  ),
                )
              else
                ClubCardPlaceholder(
                  activityType: club.activityType,
                  clubName: club.name,
                  customIconCodePoint: club.iconCodePoint,
                ),

              // Dark overlay for text legibility on gradient
              if (club.imageUrl.isEmpty)
                Container(
                  color: Colors.black.withOpacity(0.25),
                ),

              // Private Badge
              if (club.isPrivate)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.lock, color: Colors.white, size: 16),
                  ),
                ),

              // Activity Type Badge
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CruizrTheme.accentPink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    club.activityType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              // Bottom text
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${club.memberCount} Members',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (club.isPrivate) ...[
                          const SizedBox(width: 8),
                          const Text(
                            '• Private',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        ]
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      club.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
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
