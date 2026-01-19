import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/activity_model.dart';
import 'activity_details_screen.dart';

class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('activities')
            .orderBy('startTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.directions_bike, size: 64, color: Colors.grey),
                   const SizedBox(height: 16),
                   Text(
                     "No activities yet",
                     style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
                   ),
                 ],
               ),
             );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final activity = ActivityModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              final dateString = DateFormat('MMMM d, y • h:mm a').format(activity.startTime);

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ActivityDetailsScreen(activity: activity),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: CruizrTheme.accentPink.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          activity.type == 'Running' ? Icons.directions_run : Icons.directions_bike,
                          color: CruizrTheme.accentPink,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.type,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateString,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildMiniStat(Icons.straighten, '${activity.distance.toStringAsFixed(1)} km'),
                                const SizedBox(width: 16),
                                _buildMiniStat(Icons.timer, _formatDuration(activity.duration)),
                                const SizedBox(width: 16),
                                _buildMiniStat(Icons.local_fire_department, '${activity.calories.toInt()} cal'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }
}
