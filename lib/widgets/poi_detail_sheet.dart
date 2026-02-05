import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/poi_model.dart';
import '../theme/app_theme.dart';
import '../services/poi_service.dart';

/// Bottom sheet showing details of a POI with save/directions actions.
class POIDetailSheet extends StatefulWidget {
  final POI poi;
  final VoidCallback? onClose;
  final VoidCallback? onFavoriteChanged;

  const POIDetailSheet({
    super.key,
    required this.poi,
    this.onClose,
    this.onFavoriteChanged,
  });

  /// Shows the POI detail sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required POI poi,
    VoidCallback? onFavoriteChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => POIDetailSheet(
        poi: poi,
        onClose: () => Navigator.pop(context),
        onFavoriteChanged: onFavoriteChanged,
      ),
    );
  }

  @override
  State<POIDetailSheet> createState() => _POIDetailSheetState();
}

class _POIDetailSheetState extends State<POIDetailSheet> {
  final POIService _poiService = POIService();
  bool _isFavorite = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final isFav = await _poiService.isFavorite(widget.poi.placeId);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() => _isLoading = true);

    bool success;
    if (_isFavorite) {
      success = await _poiService.removeFavorite(widget.poi.placeId);
    } else {
      success = await _poiService.saveFavorite(widget.poi);
    }

    if (success && mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
        _isLoading = false;
      });
      widget.onFavoriteChanged?.call();
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openDirections() async {
    final lat = widget.poi.location.latitude;
    final lng = widget.poi.location.longitude;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=bicycling',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge and name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: CruizrTheme.accentPink.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.poi.category.emoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.poi.category.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: CruizrTheme.accentPink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Open status
                      if (widget.poi.isOpen != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.poi.isOpen!
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.poi.isOpen! ? 'Open' : 'Closed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.poi.isOpen!
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Name
                  Text(
                    widget.poi.name,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: CruizrTheme.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Address
                  if (widget.poi.address != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: CruizrTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.poi.address!,
                            style: TextStyle(
                              fontSize: 14,
                              color: CruizrTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Rating
                  if (widget.poi.rating != null) ...[
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          final starValue = index + 1;
                          if (widget.poi.rating! >= starValue) {
                            return const Icon(
                              Icons.star,
                              size: 18,
                              color: Colors.amber,
                            );
                          } else if (widget.poi.rating! >= starValue - 0.5) {
                            return const Icon(
                              Icons.star_half,
                              size: 18,
                              color: Colors.amber,
                            );
                          } else {
                            return Icon(
                              Icons.star_outline,
                              size: 18,
                              color: Colors.grey.shade300,
                            );
                          }
                        }),
                        const SizedBox(width: 8),
                        Text(
                          widget.poi.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.poi.userRatingsTotal != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${widget.poi.userRatingsTotal} reviews)',
                            style: TextStyle(
                              fontSize: 13,
                              color: CruizrTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: _isFavorite ? Icons.star : Icons.star_outline,
                          label: _isFavorite ? 'Saved' : 'Save',
                          onTap: _isLoading ? null : _toggleFavorite,
                          isPrimary: false,
                          isActive: _isFavorite,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.directions,
                          label: 'Directions',
                          onTap: _openDirections,
                          isPrimary: true,
                        ),
                      ),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isPrimary,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary
              ? CruizrTheme.accentPink
              : isActive
                  ? Colors.amber.shade100
                  : CruizrTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary
                  ? Colors.white
                  : isActive
                      ? Colors.amber.shade700
                      : CruizrTheme.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary
                    ? Colors.white
                    : isActive
                        ? Colors.amber.shade700
                        : CruizrTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
