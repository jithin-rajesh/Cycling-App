import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';
import 'follow_route_screen.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final List<String> _filters = ["My Routes", "All Routes"];
  int _selectedFilterIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(
              child: _buildRoutesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutesList() {
    final user = FirebaseAuth.instance.currentUser;
    
    // Build query - for "My Routes", filter by userId first, then order
    // For "All Routes", just order by createdAt
    Query<Map<String, dynamic>> query;
    
    if (_selectedFilterIndex == 0 && user != null) {
      // My Routes - filter first, then order
      query = FirebaseFirestore.instance
          .collection('routes')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true);
    } else {
      // All Routes - just order
      query = FirebaseFirestore.instance
          .collection('routes')
          .orderBy('createdAt', descending: true);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final routes = snapshot.data?.docs ?? [];

        if (routes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.route, size: 64, color: CruizrTheme.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'No saved routes yet',
                  style: TextStyle(
                    color: CruizrTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a route to get started!',
                  style: TextStyle(
                    color: CruizrTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: routes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final routeData = routes[index].data();
            final routeId = routes[index].id;
            return _RouteCard(
              route: routeData,
              routeId: routeId,
              onTap: () => _navigateToRoute(routeData),
              onDelete: () => _deleteRoute(routeId, routeData['name']),
            );
          },
        );
      },
    );
  }

  void _navigateToRoute(Map<String, dynamic> routeData) {
    // Convert stored data back to LatLng
    final routePointsList = (routeData['routePoints'] as List?)?.map((p) {
      return LatLng(p['lat'] as double, p['lng'] as double);
    }).toList() ?? [];

    final waypointsList = (routeData['waypoints'] as List?)?.map((p) {
      return LatLng(p['lat'] as double, p['lng'] as double);
    }).toList() ?? [];

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

  Future<void> _deleteRoute(String routeId, String? routeName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route?'),
        content: Text('Are you sure you want to delete "${routeName ?? 'this route'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('routes').doc(routeId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route deleted')),
        );
      }
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF5D4037)),
            onPressed: () {
               if (Navigator.of(context).canPop()) {
                 Navigator.of(context).pop();
               }
            },
          ),
          const Text(
            'Discover Routes',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 48), // Balance the header
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;
          return Center(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilterIndex = index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? CruizrTheme.accentPink : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                     if (!isSelected)
                       BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF5D4037),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final Map<String, dynamic> route;
  final String routeId;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RouteCard({
    required this.route,
    required this.routeId,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = route['name'] as String? ?? 'Unnamed Route';
    final distanceKm = (route['distanceKm'] as num?)?.toDouble() ?? 0.0;
    final durationMinutes = (route['durationMinutes'] as num?)?.toInt() ?? 0;
    final elevation = (route['elevation'] as num?)?.toInt() ?? 0;
    final routeType = route['routeType'] as int? ?? 1;

    String routeTypeLabel;
    switch (routeType) {
      case 0:
        routeTypeLabel = 'Loop';
        break;
      case 2:
        routeTypeLabel = 'Out & Back';
        break;
      default:
        routeTypeLabel = 'One Way';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route preview placeholder
            Stack(
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: CruizrTheme.accentPink.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.route,
                      size: 48,
                      color: CruizrTheme.accentPink.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      routeTypeLabel,
                      style: TextStyle(
                        color: CruizrTheme.accentPink,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
            
            // Info Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStat(Icons.straighten, '${distanceKm.toStringAsFixed(1)} km'),
                      const SizedBox(width: 16),
                      _buildStat(Icons.terrain, '$elevation m'),
                      const SizedBox(width: 16),
                      _buildStat(Icons.timer_outlined, '$durationMinutes min'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: CruizrTheme.accentPink),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF555555),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

