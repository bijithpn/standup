import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Maps each [AvatarSpecies] to its snapshot SVG asset path.
///
/// Species that map directly to the avatar-main snapshot filenames:
///   `assets/avatars/species/<name>.svg`
/// Names are lowercased; multi-word names use hyphens (guinea-pig, red-panda etc.).
/// Species not present in the snapshot set fall back to a pixel variant if available,
/// then to a plain emoji label.
String _speciesSnapshotPath(AvatarSpecies species) {
  return species.svgAssetPath;
}

const Map<AvatarSpecies, String> _speciesEmojis = {
  AvatarSpecies.panda: '🐼',
  AvatarSpecies.redPanda: '🦝',
  AvatarSpecies.raccoon: '🦝',
  AvatarSpecies.wolf: '🐺',
};

/// A sleek, responsive carousel and grid picker for all 30+ 3D Avatar species.
/// Shows the real geometric 3D SVG avatar snapshot for each species from
/// the OneWorks Avatar (avatar-main) repository.
class AvatarSpeciesPicker extends StatefulWidget {
  final AvatarSpecies selectedSpecies;
  final ValueChanged<AvatarSpecies> onSpeciesSelected;
  final bool isHorizontal;

  const AvatarSpeciesPicker({
    super.key,
    required this.selectedSpecies,
    required this.onSpeciesSelected,
    this.isHorizontal = true,
  });

  @override
  State<AvatarSpeciesPicker> createState() => _AvatarSpeciesPickerState();
}

class _AvatarSpeciesPickerState extends State<AvatarSpeciesPicker> {
  AvatarSpeciesCategory? _selectedCategory;

  List<AvatarSpecies> get _filteredSpecies {
    if (_selectedCategory == null) {
      return AvatarSpecies.values;
    }
    return AvatarSpecies.values
        .where((s) => s.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final speciesList = _filteredSpecies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCategoryTabs(),
        const SizedBox(height: 12),
        if (widget.isHorizontal)
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: speciesList.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final species = speciesList[index];
                return _buildSpeciesCard(species);
              },
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: speciesList.length,
            itemBuilder: (context, index) {
              final species = speciesList[index];
              return _buildSpeciesCard(species);
            },
          ),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    final categories = <AvatarSpeciesCategory?>[
      null,
      ...AvatarSpeciesCategory.values,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          final title = cat?.displayName ?? 'All';

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.accentColor,
              backgroundColor: const Color(0xFF1E202C),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AppTheme.accentColor : const Color(0xFF2C2F42),
                ),
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? cat : null;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSpeciesCard(AvatarSpecies species) {
    final isSelected = widget.selectedSpecies == species;
    final svgPath = _speciesSnapshotPath(species);
    final fallbackEmoji = _speciesEmojis[species] ?? '🐾';

    return Tooltip(
      message: '${species.displayName} (${species.category.displayName})',
      child: InkWell(
        key: Key('species_card_${species.name}'),
        onTap: () => widget.onSpeciesSelected(species),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 78,
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentColor.withValues(alpha: 0.18)
                : const Color(0xFF1E202C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.accentColor : const Color(0xFF2C2F42),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar SVG image or emoji fallback
              SizedBox(
                width: 54,
                height: 54,
                child: svgPath.isNotEmpty
                    ? SvgPicture.asset(
                        svgPath,
                        fit: BoxFit.contain,
                        placeholderBuilder: (context) => Center(
                          child: Text(
                            fallbackEmoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          fallbackEmoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                species.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.accentColor : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
