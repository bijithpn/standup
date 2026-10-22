import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/shared/shared.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/features/companion/domain/custom_environment_layer.dart';
import 'package:breakmate/features/companion/presentation/environment_builder/environment_builder_controller.dart';
import 'figma_value_input.dart';

class LayersManagerTab extends StatefulWidget {
  final EnvironmentBuilderController controller;
  final CustomEnvironmentTheme draft;

  const LayersManagerTab({
    super.key,
    required this.controller,
    required this.draft,
  });

  @override
  State<LayersManagerTab> createState() => _LayersManagerTabState();
}

class _LayersManagerTabState extends State<LayersManagerTab> {
  String? _expandedLayerId;

  String _getFriendlyName(String path) {
    final name = path.split('/').last.replaceAll('.png', '');
    return name
        .split(RegExp(r'[-_]'))
        .map(
          (s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final List<CustomEnvironmentLayer> layers = widget.draft.layers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Scenery Layers',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Inter',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _showAddLayerDialog,
              icon: const Icon(CupertinoIcons.add, size: 14),
              label: const Text('Add Layer', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (layers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.layers,
                  size: 32,
                  color: AppTheme.textMuted,
                ),
                SizedBox(height: 8),
                Text(
                  'No scenery layers yet.\nClick "Add Layer" to begin composing!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: layers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final layer = layers[idx];
              final isExpanded = _expandedLayerId == layer.id;
              final displayName = _getFriendlyName(layer.assetPath);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? AppTheme.surfaceCard
                      : AppTheme.surfaceCard.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isExpanded ? AppTheme.accent : AppTheme.border,
                    width: isExpanded ? 1.2 : 0.5,
                  ),
                  boxShadow: isExpanded
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(widget.draft.baseColorArgb),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          child: Stack(
                            children: [
                              if (widget.draft.skyPath.isNotEmpty &&
                                  widget.draft.skyPath != 'none')
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: widget.draft.skyOpacity,
                                    child: Image.asset(
                                      widget.draft.skyPath,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Image.asset(
                                    layer.assetPath,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          CupertinoIcons.photo,
                                          size: 14,
                                          color: AppTheme.textMuted,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      title: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Layer ${idx + 1} (Priority: ${-8 + idx})',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                          fontFamily: 'Inter',
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _actionIconButton(
                            icon: CupertinoIcons.chevron_up,
                            tooltip: 'Send Backward (Draw Earlier)',
                            onPressed: idx > 0
                                ? () => widget.controller.reorderLayers(
                                    idx,
                                    idx - 1,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 4),
                          _actionIconButton(
                            icon: CupertinoIcons.chevron_down,
                            tooltip: 'Bring Forward (Draw Later)',
                            onPressed: idx < layers.length - 1
                                ? () => widget.controller.reorderLayers(
                                    idx,
                                    idx + 2,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 4),
                          _actionIconButton(
                            icon: isExpanded
                                ? CupertinoIcons.chevron_up_circle_fill
                                : CupertinoIcons.chevron_down_circle,
                            color: isExpanded ? AppTheme.accent : null,
                            onPressed: () {
                              setState(() {
                                _expandedLayerId = isExpanded ? null : layer.id;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Divider(height: 1, color: AppTheme.border),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSliderRow(
                                  label: 'Horizontal Pos (X)',
                                  value: layer.xRatio,
                                  min: -0.2,
                                  max: 1.2,
                                  step: 0.05,
                                  onChanged: (val) {
                                    widget.controller.updateLayer(
                                      layer.copyWith(xRatio: val),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildSliderRow(
                                  label: 'Vertical Height (Y)',
                                  value: layer.yRatio,
                                  min: -0.2,
                                  max: 1.2,
                                  step: 0.05,
                                  onChanged: (val) {
                                    widget.controller.updateLayer(
                                      layer.copyWith(yRatio: val),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildSliderRow(
                                  label: 'Scale Size',
                                  value: layer.scale,
                                  min: 0.1,
                                  max: 3.0,
                                  step: 0.10,
                                  onChanged: (val) {
                                    widget.controller.updateLayer(
                                      layer.copyWith(scale: val),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildSliderRow(
                                  label: 'Opacity',
                                  value: layer.opacity,
                                  min: 0.0,
                                  max: 1.0,
                                  step: 0.05,
                                  onChanged: (val) {
                                    widget.controller.updateLayer(
                                      layer.copyWith(opacity: val),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Flip Horizontally',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textPrimary,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        CupertinoSwitch(
                                          value: layer.flipX,
                                          activeTrackColor: AppTheme.accent,
                                          onChanged: (val) {
                                            widget.controller.updateLayer(
                                              layer.copyWith(flipX: val),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            widget.controller.duplicateLayer(
                                              layer,
                                            );
                                          },
                                          icon: const Icon(
                                            CupertinoIcons.doc_on_doc,
                                            size: 12,
                                          ),
                                          label: const Text(
                                            'Duplicate',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppTheme.textSecondary,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        TextButton.icon(
                                          onPressed: () {
                                            widget.controller.removeLayer(
                                              layer.id,
                                            );
                                            if (_expandedLayerId == layer.id) {
                                              _expandedLayerId = null;
                                            }
                                          },
                                          icon: const Icon(
                                            CupertinoIcons.trash,
                                            size: 12,
                                          ),
                                          label: const Text(
                                            'Delete',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.border,
              thumbColor: AppTheme.accent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FigmaValueInput(
          value: value,
          min: min,
          max: max,
          step: step,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _actionIconButton({
    required IconData icon,
    String? tooltip,
    VoidCallback? onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: onPressed == null
                ? Colors.transparent
                : (color ?? AppTheme.textSecondary).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: onPressed == null
                ? AppTheme.textMuted.withValues(alpha: 0.4)
                : (color ?? AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  void _showAddLayerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AddLayerDialog(controller: widget.controller);
      },
    );
  }
}

class AddLayerDialog extends StatefulWidget {
  final EnvironmentBuilderController controller;

  const AddLayerDialog({super.key, required this.controller});

  @override
  State<AddLayerDialog> createState() => _AddLayerDialogState();
}

class _AddLayerDialogState extends State<AddLayerDialog> {
  int _activeDialogTab = 0;

  String _getFriendlyName(String path) {
    final name = path.split('/').last.replaceAll('.png', '');
    return name
        .split(RegExp(r'[-_]'))
        .map(
          (s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final List<String> paths;
    switch (_activeDialogTab) {
      case 0:
        paths = widget.controller.mountainPaths;
        break;
      case 1:
        paths = widget.controller.rockPaths;
        break;
      case 2:
        paths = widget.controller.cloudPaths;
        break;
      case 3:
        paths = widget.controller.skyPaths;
        break;
      case 4:
        paths = widget.controller.groundPaths;
        break;
      case 5:
        paths = {
          ...widget.controller.birdPaths,
          ...widget.controller.rabbitIdlePaths,
          ...widget.controller.rabbitRunPaths,
        }.toList();
        break;
      case 6:
        paths = {
          ...widget.controller.toyPaths,
          ...widget.controller.foodPaths,
        }.toList();
        break;
      default:
        paths = [];
    }

    return Dialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Container(
        width: 580,
        height: 480,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Scenery Layer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark, size: 16),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _dialogTabButton(0, 'Mountains & Trees'),
                    const SizedBox(width: 8),
                    _dialogTabButton(1, 'Rocks & Stones'),
                    const SizedBox(width: 8),
                    _dialogTabButton(2, 'Clouds'),
                    const SizedBox(width: 8),
                    _dialogTabButton(3, 'Backgrounds & Skies'),
                    const SizedBox(width: 8),
                    _dialogTabButton(4, 'Ground Tiles'),
                    const SizedBox(width: 8),
                    _dialogTabButton(5, 'Wildlife & Pets'),
                    const SizedBox(width: 8),
                    _dialogTabButton(6, 'Toys & Foods'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemCount: paths.length,
                itemBuilder: (context, idx) {
                  final path = paths[idx];
                  final name = _getFriendlyName(path);
                  return GestureDetector(
                    onTap: () {
                      widget.controller.addLayer(path);
                      Navigator.of(context).pop();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        border: Border.all(color: AppTheme.border, width: 0.5),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(
                                  widget.controller.draft.baseColorArgb,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm,
                                ),
                                border: Border.all(
                                  color: AppTheme.border.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm,
                                ),
                                child: Stack(
                                  children: [
                                    if (widget
                                            .controller
                                            .draft
                                            .skyPath
                                            .isNotEmpty &&
                                        widget.controller.draft.skyPath !=
                                            'none')
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: widget
                                              .controller
                                              .draft
                                              .skyOpacity,
                                          child: Image.asset(
                                            widget.controller.draft.skyPath,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    Positioned.fill(
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Image.asset(
                                          path,
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Icon(
                                                    CupertinoIcons.photo,
                                                    size: 16,
                                                    color: AppTheme.textMuted,
                                                  ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogTabButton(int idx, String label) {
    final isSelected = _activeDialogTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _activeDialogTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent
              : AppTheme.surfaceCard.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppTheme.border,
            width: 0.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}
