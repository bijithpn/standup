import 'package:flutter/material.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart'
    show appColor;
import 'package:breakmate/features/analytics/app_usage_tracker.dart';
import 'package:breakmate/features/analytics/segments/productivity_repository.dart';
import 'package:breakmate/features/settings/custom_budget_category.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

/// Create or edit a [CustomBudgetCategory]: name, icon, and which recently used apps count toward it.
Future<CustomBudgetCategory?> showCustomBudgetDialog(
  BuildContext context, {
  CustomBudgetCategory? existing,
}) {
  return showDialog<CustomBudgetCategory>(
    context: context,
    builder: (_) => _CustomBudgetDialog(existing: existing),
  );
}

class _CustomBudgetDialog extends StatefulWidget {
  const _CustomBudgetDialog({this.existing});

  final CustomBudgetCategory? existing;

  @override
  State<_CustomBudgetDialog> createState() => _CustomBudgetDialogState();
}

class _CustomBudgetDialogState extends State<_CustomBudgetDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late int _icon = widget.existing?.iconIndex ?? 0;
  late final Set<String> _apps = <String>{...?widget.existing?.appNames};
  List<String> _known = const <String>[];
  final ScrollController _iconScroll = ScrollController();
  bool _loadingApps = true;
  final TextEditingController _iconSearch = TextEditingController();
  final TextEditingController _appSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKnownApps();
  }

  Future<void> _loadKnownApps() async {
    if (!sl.isRegistered<ProductivityRepository>()) {
      setState(() => _loadingApps = false);
      return;
    }
    final summary = await sl<ProductivityRepository>().summaryForLastDays(30);
    if (!mounted) return;
    setState(() {
      _known = <String>[
        for (final a in summary.apps)
          if (!AppUsageTracker.isSystemHelperKey(a.appKey)) a.appName,
      ];
      _loadingApps = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _iconScroll.dispose();
    _iconSearch.dispose();
    _appSearch.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      CustomBudgetCategory(
        id:
            widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        iconIndex: _icon,
        appNames: _apps.toList(),
        minutes: widget.existing?.minutes ?? 60,
      ),
    );
  }

  List<int> _matchingIcons() {
    final q = _iconSearch.text.trim().toLowerCase();
    return <int>[
      for (var i = 0; i < kBudgetIconSet.length; i++)
        if (q.isEmpty ||
            kBudgetIconSet[i].$2.contains(q) ||
            kBudgetIconSet[i].$3.contains(q))
          i,
    ];
  }

  Widget _appResults() {
    final q = _appSearch.text.trim();
    final lower = q.toLowerCase();
    final matches = <String>[
      for (final app in _known)
        if (!_apps.contains(app) &&
            (lower.isEmpty || app.toLowerCase().contains(lower)))
          app,
    ];
    final canAddTyped =
        q.isNotEmpty &&
        !_apps.any((a) => a.toLowerCase() == lower) &&
        !_known.any((a) => a.toLowerCase() == lower);
    if (_loadingApps && _known.isEmpty && !canAddTyped) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Loading your apps…',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      );
    }
    if (matches.isEmpty && !canAddTyped) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          _known.isEmpty
              ? 'No apps recorded yet. Type a name to add one.'
              : 'No more matching apps.',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 148),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          if (canAddTyped)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.add, size: 18),
              title: Text('Add "$q"', style: const TextStyle(fontSize: 13)),
              onTap: () => setState(() {
                _apps.add(q);
                _appSearch.clear();
              }),
            ),
          for (final app in matches)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: _AppAvatar(name: app),
              title: Text(app, style: const TextStyle(fontSize: 13)),
              onTap: () => setState(() => _apps.add(app)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(fontSize: 12, color: AppTheme.textSecondary);
    final icons = _matchingIcons();
    return Dialog(
      backgroundColor: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existing == null
                      ? 'New budget type'
                      : 'Edit budget type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Text('Name', style: label),
                const SizedBox(height: 6),
                TextField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 24,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Social, Reading, Gaming',
                    counterText: '',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 18),
                Text('Icon', style: label),
                const SizedBox(height: 8),
                _SearchField(
                  controller: _iconSearch,
                  hint: 'Search icons',
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 148,
                  child: Scrollbar(
                    controller: _iconScroll,
                    thumbVisibility: true,
                    child: GridView.builder(
                      controller: _iconScroll,
                      padding: const EdgeInsets.only(right: 12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 42,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                      itemCount: icons.length,
                      itemBuilder: (context, n) {
                        final i = icons[n];
                        final selected = i == _icon;
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: kBudgetIconSet[i].$2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _icon = i),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: selected ? AppTheme.accent : null,
                                border: selected
                                    ? null
                                    : Border.all(color: AppTheme.border),
                              ),
                              child: Icon(
                                kBudgetIconSet[i].$1,
                                size: 16,
                                color: selected
                                    ? AppTheme.gray950
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _apps.isEmpty
                      ? 'Apps that count toward it'
                      : 'Apps that count toward it (${_apps.length})',
                  style: label,
                ),
                const SizedBox(height: 8),
                if (_apps.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 84),
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(right: 10),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final app in _apps)
                              InputChip(
                                avatar: _AppAvatar(name: app, size: 18),
                                label: Text(app),
                                onDeleted: () =>
                                    setState(() => _apps.remove(app)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_apps.isNotEmpty) const SizedBox(height: 8),
                _SearchField(
                  controller: _appSearch,
                  hint: 'Search or type an app name',
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 6),
                _appResults(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MinimalButton(
                      isGhost: true,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    MinimalButton(
                      onPressed: _name.text.trim().isEmpty ? null : _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        prefixIcon: const Icon(Icons.search, size: 16),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
      ),
    );
  }
}

/// Letter badge in a stable colour; real app icons would need a native lookup per app.
class _AppAvatar extends StatelessWidget {
  const _AppAvatar({required this.name, this.size = 24});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colour = appColor(name.runes.fold<int>(0, (a, b) => a + b));
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w600,
          color: colour,
        ),
      ),
    );
  }
}
