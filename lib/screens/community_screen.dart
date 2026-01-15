
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/activity_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _selectedMetric = 'distance'; // 'distance' or 'calories'
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
    });

    final data = await ActivityService().getLeaderboard(_selectedMetric);

    if (mounted) {
      setState(() {
        _leaderboard = data;
        _isLoading = false;
      });
    }
  }

  void _onMetricChanged(String metric) {
    if (_selectedMetric != metric) {
      setState(() {
        _selectedMetric = metric;
      });
      _loadLeaderboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myRankValues = _leaderboard.where((u) => u['isMe'] == true);
    final myData = myRankValues.isNotEmpty ? myRankValues.first : null;
    final myRankIndex = _leaderboard.indexWhere((u) => u['isMe'] == true);

    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text(
                    'Community',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Container(
                    width: 40, 
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: CruizrTheme.accentPink, width: 2),
                    ),
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Toggle Stats
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  _buildToggleItem('Distance', 'distance'),
                  _buildToggleItem('Calories', 'calories'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Leaderboard List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: _leaderboard.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = _leaderboard[index];
                        final isMe = user['isMe'] == true;
                        return _buildUserRow(index + 1, user, isMe: isMe);
                      },
                    ),
            ),
            
            // "Your Rank" Sticky Bar (if you are in the list)
            if (!_isLoading && myData != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5)),
                  ],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Your Rank",
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildUserRow(myRankIndex + 1, myData, isMe: true, isSticky: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(String label, String value) {
    final isSelected = _selectedMetric == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onMetricChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? CruizrTheme.accentPink : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserRow(int rank, Map<String, dynamic> user, {bool isMe = false, bool isSticky = false}) {
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
    } else {
      rankColor = Colors.grey.withValues(alpha: 0.5);
    }

    final valueDisplay = _selectedMetric == 'distance'
        ? '${user['distance'].toStringAsFixed(1)} km'
        : '${user['calories'].toStringAsFixed(0)} cal';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: isMe && !isSticky ? CruizrTheme.accentPink.withValues(alpha: 0.1) : (isSticky ? Colors.white : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: isMe ? Border.all(color: CruizrTheme.accentPink.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 30,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: rankColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.grey),
          ),
          const SizedBox(width: 16),

          // Name
          Expanded(
            child: Text(
              user['name'],
              style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF2D2D2D),
              ),
            ),
          ),

          // Value
          Text(
            valueDisplay,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF5D4037),
            ),
          ),
        ],
      ),
    );
  }
}
