import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/presentation/widgets/avatar_customizer_sheet.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Fullscreen 3D Avatar Customizer page providing interactive styling,
/// palette selection, procedural seed variation, and live animation testing.
class AvatarCustomizerPage extends StatefulWidget {
  final AvatarDefinition? initialDefinition;
  final AvatarEngineController? engineController;
  final ValueChanged<AvatarDefinition>? onSaved;
  final VoidCallback? onCancel;
  final bool isStatic;

  const AvatarCustomizerPage({
    super.key,
    this.initialDefinition,
    this.engineController,
    this.onSaved,
    this.onCancel,
    this.isStatic = false,
  });

  @override
  State<AvatarCustomizerPage> createState() => _AvatarCustomizerPageState();
}

class _AvatarCustomizerPageState extends State<AvatarCustomizerPage> {
  late AvatarDefinition _definition;
  late AvatarEngineController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _definition = widget.initialDefinition ??
        AvatarDefinition.fromSpecies(AvatarSpecies.cat);

    if (widget.engineController != null) {
      _controller = widget.engineController!;
      _ownsController = false;
    } else {
      _controller = AvatarEngineController();
      _ownsController = true;
    }
    _controller.setDefinition(_definition);
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleSave(AvatarDefinition savedDef) async {
    try {
      if (sl.isRegistered<CompanionOverlayController>()) {
        final companionController = sl<CompanionOverlayController>();
        final themeId = 'avatar_${savedDef.species.name}';
        companionController.changeTheme(themeId);
      } else {
        try {
          final settingsRepo = Provider.of<SettingsRepository>(context, listen: false);
          final updated = settingsRepo.currentSettings.copyWith(
            companionPetTheme: 'avatar_${savedDef.species.name}',
          );
          await settingsRepo.save(updated);
        } catch (_) {}
      }
    } catch (_) {}

    widget.onSaved?.call(savedDef);

    if (mounted) {
      Toast.showSuccess(context, 'Companion customizer saved successfully!');
      if (Navigator.canPop(context)) {
        Navigator.pop(context, savedDef);
      }
    }
  }

  void _handleCancel() {
    widget.onCancel?.call();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.contentBackground,
      appBar: AppBar(
        title: Text(
          '3D Pet Customizer',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppTheme.surfaceElevated,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: AppTheme.textPrimary),
          onPressed: _handleCancel,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: AvatarCustomizerSheet(
            initialDefinition: _definition,
            engineController: _controller,
            showPreview: true,
            isStatic: widget.isStatic,
            onSaved: _handleSave,
            onChanged: (newDef) {
              setState(() => _definition = newDef);
            },
            onCancel: _handleCancel,
          ),
        ),
      ),
    );
  }
}
