import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';
import '../services/user_service.dart';
import '../widgets/route_card.dart';
import 'follow_route_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? avatarUrl;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.avatarUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserService _userService = UserService();
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isMe = false;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _userRoutes = [];
  Map<String, int> _followCounts = {'followers': 0, 'following': 0};

  @override
  void initState() {
    super.initState();
    _checkIsMe();
    _loadData();
  }

  void _checkIsMe() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == widget.userId) {
      setState(() => _isMe = true);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Parallel fetch
    final results = await Future.wait([
      _userService.getUserProfile(widget.userId),
      _userService.isFollowing(widget.userId),
      _userService.getUserRoutes(widget.userId),
      _userService.getFollowCounts(widget.userId),
    ]);

    if (mounted) {
      setState(() {
        _userProfile = results[0] as Map<String, dynamic>?;
        _isFollowing = results[1] as bool;
        _userRoutes = results[2] as List<Map<String, dynamic>>;
        _followCounts = results[3] as Map<String, int>;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    try {
      if (_isFollowing) {
        await _userService.unfollowUser(widget.userId);
        setState(() {
          _isFollowing = false;
          _followCounts['followers'] = (_followCounts['followers'] ?? 1) - 1;
        });
      } else {
        await _userService.followUser(widget.userId);
        setState(() {
          _isFollowing = true;
          _followCounts['followers'] = (_followCounts['followers'] ?? 0) + 1;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _navigateToRoute(Map<String, dynamic> routeData) {
    // Convert stored data back to LatLng
    final routePointsList = (routeData['routePoints'] as List?)?.map((p) {
          return LatLng(p['lat'] as double, p['lng'] as double);
        }).toList() ??
        [];

    final waypointsList = (routeData['waypoints'] as List?)?.map((p) {
          return LatLng(p['lat'] as double, p['lng'] as double);
        }).toList() ??
        [];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FollowRouteScreen(
          routePoints: routePointsList,
          waypoints: waypointsList,
          distanceKm: (routeData['distanceKm'] as num?)?.toDouble() ?? 0.0,
          durationMinutes: (routeData['durationMinutes'] as num?)?.toInt() ?? 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: CruizrTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Fallback if profile not found (unlikely from community list, but safe)
    if (_userProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("User Not Found")),
        body: const Center(child: Text("User profile not found")),
      );
    }

    final avatar = _userProfile?['photoUrl'] ?? widget.avatarUrl;
    final name = _userProfile?['preferredName'] ?? widget.userName;
    final location = _userProfile?['location'] ?? 'Unknown Location';
    final pronouns = _userProfile?['pronouns'];

    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const BackButton(color: Color(0xFF5D4037)),
                  const Spacer(),
                  // Settings or Report button could go here
                ],
              ),
            ),

            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Profile Header
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: CruizrTheme.surface,
                              border: Border.all(
                                  color: CruizrTheme.border, width: 2),
                              image: avatar != null
                                  ? DecorationImage(
                                      image: NetworkImage(avatar),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: avatar == null
                                ? const Icon(Icons.person,
                                    size: 48, color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            name,
                            style: const TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          if (pronouns != null)
                            Text(
                              pronouns,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                location,
                                style: const TextStyle(
                                  color: Color(0xFF5D4037),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Stats Row (Hidden if private)
                          if (_userProfile?['profileVisibility'] == 'private' &&
                              !_isMe) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 20, horizontal: 16),
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: CruizrTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.lock_outline,
                                      size: 32,
                                      color: CruizrTheme.textSecondary),
                                  const SizedBox(height: 8),
                                  Text(
                                    "This account is private",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: CruizrTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    "Follow this user to see their activity",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: CruizrTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Stats Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatItem('Followers',
                                    _followCounts['followers'] ?? 0),
                                Container(
                                    width: 1,
                                    height: 30,
                                    color: Colors.grey[300],
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 24)),
                                _buildStatItem('Following',
                                    _followCounts['following'] ?? 0),
                                Container(
                                    width: 1,
                                    height: 30,
                                    color: Colors.grey[300],
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 24)),
                                _buildStatItem('Routes', _userRoutes.length),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Action Button
                          if (!_isMe)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing
                                      ? Colors.white
                                      : CruizrTheme.accentPink,
                                  foregroundColor: _isFollowing
                                      ? CruizrTheme.accentPink
                                      : Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(
                                        color: CruizrTheme.accentPink),
                                  ),
                                  elevation: _isFollowing ? 0 : 2,
                                ),
                                child: Text(
                                  _isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),

                          // Section Title
                          if (_userProfile?['profileVisibility'] != 'private' ||
                              _isMe) ...[
                            const SizedBox(height: 32),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Created Routes',
                                style: TextStyle(
                                  fontFamily: 'Playfair Display',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Routes List
                  if ((_userProfile?['profileVisibility'] != 'private' ||
                          _isMe) &&
                      _userRoutes.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No routes created yet.',
                            style: TextStyle(color: CruizrTheme.textSecondary),
                          ),
                        ),
                      ),
                    )
                  else if (_userProfile?['profileVisibility'] != 'private' ||
                      _isMe)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final route = _userRoutes[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 10),
                            child: RouteCard(
                              route: route,
                              routeId: route['id'],
                              onTap: () => _navigateToRoute(route),
                              // No delete button here
                            ),
                          );
                        },
                        childCount: _userRoutes.length,
                      ),
                    ),

                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: CruizrTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
