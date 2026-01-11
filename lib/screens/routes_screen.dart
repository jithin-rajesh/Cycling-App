import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final List<String> _filters = ["All Activities", "Cycling", "Running", "Hiking"];
  int _selectedFilterIndex = 0;

  final List<Map<String, dynamic>> _routes = [
    {
      "title": "Riverside Path",
      "distance": "15.5 km",
      "elevation": "50m",
      "duration": "~45 min",
      "rating": 4.8,
      "reviews": 124,
      "difficulty": "Easy",
      "color": "green", // Badge color logic can be refined
    },
    {
      "title": "Hill Circuit",
      "distance": "8.2 km",
      "elevation": "180m",
      "duration": "~50 min",
      "rating": 4.6,
      "reviews": 89,
      "difficulty": "Moderate",
      "color": "orange",
    },
    {
      "title": "Mountain Trail",
      "distance": "12.0 km",
      "elevation": "450m",
      "duration": "~3h",
      "rating": 4.9,
      "reviews": 67,
      "difficulty": "Hard",
      "color": "red",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background, // Assuming generic background color from theme
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: _routes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final route = _routes[index];
                  return _RouteCard(route: route);
                },
              ),
            ),
          ],
        ),
      ),
    );
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
              color: Color(0xFF2D2D2D), // Dark text
              fontStyle: FontStyle.italic,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF5D4037)), // Light purple/grey in design? Using brownish for now
            onPressed: () {},
          ),
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
                  color: isSelected ? const Color(0xFFD67B80) : Colors.white, // Salmon pink if selected
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                     if (!isSelected)
                       BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
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

  const _RouteCard({required this.route});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / Map placeholder
          Stack(
            children: [
              Container(
                height: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0EBE8), // Placeholder beige
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                // Real implementation would use an Image.asset or network image here
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    route['difficulty'],
                    style: TextStyle(
                      color: _getDifficultyColor(route['difficulty']),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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
                  route['title'],
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
                    _buildStat(Icons.directions_bike, route['distance']), // Assuming cycling icon for now, logic can change based on filter
                    const SizedBox(width: 16),
                    _buildStat(Icons.expand, route['elevation'], iconColor: Colors.blue),
                    const SizedBox(width: 16),
                    _buildStat(Icons.timer_outlined, route['duration']),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      final rating = route['rating'] as double;
                      return Icon(
                        index < rating.floor() ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '${route['rating']} (${route['reviews']} reviews)',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String text, {Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor ?? const Color(0xFFD67B80)),
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

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy': return Colors.green;
      case 'Moderate': return Colors.orange;
      case 'Hard': return Colors.red;
      default: return Colors.blue;
    }
  }
}
