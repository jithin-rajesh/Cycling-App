import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/cruizr_switch.dart';
import 'routes_screen.dart';
import 'just_move_screen.dart';
import 'create_route_screen.dart';

class StartActivityScreen extends StatefulWidget {
  const StartActivityScreen({super.key});

  @override
  State<StartActivityScreen> createState() => _StartActivityScreenState();
}

class _StartActivityScreenState extends State<StartActivityScreen> {
  bool _liveTrackingEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   IconButton( // Close button
                     icon: const Icon(Icons.close, color: Color(0xFF5D4037)),
                     onPressed: () => Navigator.of(context).pop(),
                   ),
                ],
              ),
              const Center(
                child: Text(
                  'Start Activity',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037), // Dark brown
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Choose how you want to move today',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Action Cards
              _buildActionCard(
                icon: Icons.push_pin,
                title: "Just Move",
                subtitle: "Start recording your activity now",
                iconColor: const Color(0xFFE91E63),
                iconBgColor: const Color(0xFFFCE4EC),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JustMoveScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildActionCard(
                icon: Icons.route,
                title: "Create Route",
                subtitle: "Plan and save a custom route",
                iconColor: const Color(0xFFD97D84),
                iconBgColor: const Color(0xFFFDF6F5),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateRouteScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildActionCard(
                icon: Icons.map_outlined,
                title: "Follow a Route",
                subtitle: "Navigate your saved routes",
                iconColor: const Color(0xFF2196F3),
                iconBgColor: const Color(0xFFE3F2FD),
                onTap: () {
                  Navigator.of(context).pop(); // Close modal
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoutesScreen()));
                },
              ),
              const SizedBox(height: 20),
              _buildActionCard(
                icon: Icons.groups_rounded,
                title: "Join Community Activity",
                subtitle: "Active sessions near you",
                iconColor: const Color(0xFF673AB7),
                iconBgColor: const Color(0xFFEDE7F6),
                onTap: () {
                  // TODO: Navigate to community
                },
              ),

              const SizedBox(height: 40),

              // Sensors & Devices
              const Text(
                'Sensors & Devices',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 16),
              
              _buildSensorCard(
                icon: Icons.favorite,
                name: "Heart Rate",
                statusWidget: _buildStatusBadge("Connected", Colors.green),
                iconColor: Colors.red,
              ),
              const SizedBox(height: 12),
              _buildSensorCard(
                icon: Icons.directions_bike,
                name: "Cadence",
                statusWidget: _buildStatusBadge("Searching...", Colors.orange),
                iconColor: Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildSensorCard(
                icon: Icons.bolt,
                name: "Power Meter",
                statusWidget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEBE9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text("+ Add", style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.bold)),
                ),
                iconColor: Colors.orangeAccent,
              ),

              const SizedBox(height: 32),
              
              // Live Tracking
              Container(
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: const Color(0xFFFBF5F2), // Slightly darker/different shade if needed, or stick to white
                   borderRadius: BorderRadius.circular(24),
                   border: Border.all(color: Colors.white, width: 2), // Subtle border
                 ),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: const [
                         Text(
                           "Live Tracking",
                           style: TextStyle(
                             fontWeight: FontWeight.bold,
                             fontSize: 16,
                             color: Color(0xFF2D2D2D),
                           ),
                         ),
                         SizedBox(height: 4),
                         Text(
                           "Share location with selected\ncontacts",
                           style: TextStyle(
                             fontSize: 12,
                             color: Colors.grey,
                             fontStyle: FontStyle.italic,
                           ),
                         ),
                       ],
                     ),
                      CruizrSwitch(
                        value: _liveTrackingEnabled,
                        onChanged: (val) {
                          setState(() {
                            _liveTrackingEnabled = val;
                          });
                        },
                      ),
                   ],
                 ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(20), // Squircle-ish
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required String name,
    required Widget statusWidget,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF5F2), // Light beige background for sensor items
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ),
          statusWidget,
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.6), // Muted look
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
