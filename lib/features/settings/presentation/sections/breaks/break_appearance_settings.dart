import 'dart:io';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/breath_preset.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_template_switcher.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

part 'break_template_catalog.dart';
part 'break_appearance_sections.dart';
part 'live_template_preview.dart';

class BreakAppearanceSettings extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const BreakAppearanceSettings({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<BreakAppearanceSettings> createState() =>
      _BreakAppearanceSettingsState();
}

class _BreakAppearanceSettingsState extends State<BreakAppearanceSettings> {
  static const _themeModeLabels = {
    'dark': 'Dark',
    'light': 'Light',
    'system': 'Match system',
  };

  String? _hoveredId;
  String? _selectedTemplateId;

  /// Templates whose accent color can be pinned independently of the app
  /// theme (see `BreakOverlayTheme.resolveAccent`).
  static const _overridableTemplates = [
    (id: 'warm_amber', name: 'Warm Amber'),
    (id: 'iris_rest', name: 'Iris Rest'),
    (id: 'split_view', name: 'Split View'),
    (id: 'breathe_line', name: 'Breathe Line'),
    (id: 'activities', name: 'Activities'),
    (id: 'companion', name: 'Companion'),
    (id: 'minimal', name: 'Minimal Focus'),
    (id: 'hud', name: 'Productivity HUD'),
    (id: 'floating', name: 'Soft Floating'),
    (id: 'quiet_pill', name: 'Quiet Pill'),
    (id: 'soft_arc', name: 'Soft Arc'),
    (id: 'zen', name: 'Zen Mode'),
  ];
  String _accentOverrideTemplateId = 'warm_amber';
  final ScrollController _gridScrollController = ScrollController();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _selectedTemplateId = widget.settings.breakTemplate;
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BreakAppearanceSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.breakTemplate != widget.settings.breakTemplate) {
      _selectedTemplateId = widget.settings.breakTemplate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Break Templates'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_selectedTemplateId != null) ...[
              Text(
                'Selected: ',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
              Builder(
                builder: (context) {
                  final selectedTemplate = _templates.firstWhere(
                    (t) => t.id == _selectedTemplateId,
                    orElse: () => _templates.first,
                  );
                  return Text(
                    selectedTemplate.name,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  );
                },
              ),
            ],
            const Spacer(),
            Tooltip(
              message: 'Preview Selected',
              child: MinimalButton(
                padding: const EdgeInsets.all(8),
                backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                onPressed: () => _showBreakTemplatePreview(_selectedTemplateId),
                child: Icon(
                  CupertinoIcons.eye,
                  size: 16,
                  color: AppTheme.accentColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final bool hasChanges =
                    _selectedTemplateId != widget.settings.breakTemplate;
                return Tooltip(
                  message: 'Update Template',
                  child: MinimalButton(
                    padding: const EdgeInsets.all(8),
                    backgroundColor: AppTheme.accentColor,
                    disabledColor: AppTheme.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: hasChanges
                        ? () {
                            widget.onSave(
                              widget.settings.copyWith(
                                breakTemplate: _selectedTemplateId,
                              ),
                            );
                            Toast.showSuccess(
                              context,
                              'Template updated successfully!',
                            );
                          }
                        : null,
                    child: Icon(
                      CupertinoIcons.checkmark,
                      size: 16,
                      color: hasChanges
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        CupertinoTextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontFamily: 'Inter',
          ),
          placeholder: 'Search templates...',
          placeholderStyle: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
            fontSize: 13,
            fontFamily: 'Inter',
          ),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(
              CupertinoIcons.search,
              size: 16,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          suffix: _searchQuery.isNotEmpty
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 16,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : null,
          decoration: BoxDecoration(
            color: AppTheme.contentBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _searchFocusNode.hasFocus
                  ? AppTheme.accentColor
                  : AppTheme.borderColor.withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.trim();
            });
          },
        ),
        const SizedBox(height: 12),
        _buildCategoryFilterRow(),
        const SizedBox(height: 16),
        _buildBreakTemplateGrid(),
        const SizedBox(height: 32),
        ..._buildColorsSection(context),
        const SizedBox(height: 32),
        ..._buildAccentPinSection(context),
      ],
    );
  }

  Widget _buildCategoryFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentColor
                      : AppTheme.contentBackground.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor
                        : AppTheme.borderColor.withValues(alpha: 0.4),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBreakTemplateGrid() {
    final filteredTemplates = _templates.where((t) {
      if (_selectedCategory != 'All' && t.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.name.toLowerCase().contains(q) ||
          t.desc.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: AppTheme.contentBackground.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: filteredTemplates.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.search,
                      size: 32,
                      color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No templates found matching "$_searchQuery"',
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              )
            : Scrollbar(
                controller: _gridScrollController,
                thumbVisibility: true,
                child: GridView.builder(
                  controller: _gridScrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 195,
                  ),
                  itemCount: filteredTemplates.length,
                  itemBuilder: (context, index) {
                    final t = filteredTemplates[index];
                    return _breakTemplatePreview(
                      t.name,
                      t.id,
                      t.desc,
                      t.category,
                      _selectedTemplateId == t.id,
                      () => setState(() => _selectedTemplateId = t.id),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _breakTemplatePreview(
    String name,
    String id,
    String description,
    String category,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final isHovered = _hoveredId == id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredId = id),
      onExit: (_) => setState(() => _hoveredId = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedScale(
                scale: isHovered ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 120,
                  clipBehavior: Clip.none,
                  decoration: BoxDecoration(
                    color: AppTheme.contentBackground,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentColor
                          : isHovered
                          ? AppTheme.accentColor.withValues(alpha: 0.4)
                          : AppTheme.borderColor.withValues(alpha: 0.6),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : isHovered
                        ? [
                            BoxShadow(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _LiveTemplatePreview(id: id, settings: widget.settings),
                      if (isSelected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            color: AppTheme.accentColor,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    flex: 3,
                    child: Text(
                      name,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.accentColor
                            : isHovered
                            ? Colors.white
                            : AppTheme.textPrimary.withValues(alpha: 0.9),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 11,
                  height: 1.3,
                  fontFamily: 'Inter',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBreakTemplatePreview(String? templateId) {
    try {
      final controller = sl<BreakController>();
      controller.previewBreak(templateId: templateId);

      if (mounted) {
        Toast.showSuccess(
          context,
          'Preview started! Break overlay will appear.',
        );
      }
    } catch (e) {
      if (mounted) {
        Toast.showError(context, 'Failed to start preview: ${e.toString()}');
      }
    }
  }
}
