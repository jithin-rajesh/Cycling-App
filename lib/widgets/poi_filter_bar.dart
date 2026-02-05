import 'package:flutter/material.dart';
import '../models/poi_model.dart';
import '../theme/app_theme.dart';

/// A horizontal scrollable bar with toggleable POI category chips.
/// Similar to Google Maps filter bar.
class POIFilterBar extends StatelessWidget {
  final Set<POICategory> activeCategories;
  final ValueChanged<POICategory> onCategoryToggled;
  final bool showFavorites;
  final VoidCallback? onFavoritesToggled;
  final bool favoritesActive;

  const POIFilterBar({
    super.key,
    required this.activeCategories,
    required this.onCategoryToggled,
    this.showFavorites = true,
    this.onFavoritesToggled,
    this.favoritesActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 8),
          // Show favorites toggle if enabled
          if (showFavorites && onFavoritesToggled != null) ...[
            _buildFavoritesChip(),
            const SizedBox(width: 8),
          ],
          // Show all POI categories
          ...POICategory.values.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildCategoryChip(category),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(POICategory category) {
    final isActive = activeCategories.contains(category);

    return GestureDetector(
      onTap: () => onCategoryToggled(category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? CruizrTheme.accentPink
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isActive
                ? CruizrTheme.accentPink
                : Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category.emoji,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              category.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : CruizrTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesChip() {
    return GestureDetector(
      onTap: onFavoritesToggled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: favoritesActive
              ? Colors.amber.shade600
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: favoritesActive
                ? Colors.amber.shade600
                : Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              favoritesActive ? Icons.star : Icons.star_outline,
              size: 18,
              color: favoritesActive ? Colors.white : Colors.amber.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              'Favorites',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: favoritesActive ? Colors.white : CruizrTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
