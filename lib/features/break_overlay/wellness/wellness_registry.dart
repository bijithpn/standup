import 'package:breakmate/features/break_overlay/wellness/templates/aurora_template.dart';
import 'package:breakmate/features/break_overlay/wellness/templates/balance_template.dart';
import 'package:breakmate/features/break_overlay/wellness/templates/flowline_template.dart';
import 'package:breakmate/features/break_overlay/wellness/templates/liquid_template.dart';
import 'package:breakmate/features/break_overlay/wellness/templates/midnight_template.dart';
import 'package:breakmate/features/break_overlay/wellness/templates/zen_ink_template.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_template.dart';

const List<WellnessTemplate> wellnessTemplates = [
  BalanceTemplate(),
  ZenInkTemplate(),
  FlowlineTemplate(),
  AuroraTemplate(),
  MidnightTemplate(),
  LiquidTemplate(),
];

const defaultWellnessTemplateId = 'balance';

const _legacy = {
  'night_sky': 'midnight',
  'dusk_glow': 'midnight',
  'warm_amber': 'midnight',
  'zen': 'zen_ink',
  'one_word': 'zen_ink',
  'haiku_card': 'zen_ink',
  'paper_light': 'zen_ink',
  'breathe_line': 'flowline',
  'wave_calm': 'flowline',
  'hud': 'flowline',
  'time_slice': 'flowline',
  'classic': 'aurora',
  'open_field': 'aurora',
  'focus_orb': 'liquid',
  'iris_rest': 'liquid',
  'soft_arc': 'liquid',
  'pulse_dot': 'liquid',
};

/// Maps any stored id (including the 25+ retired ones) to a valid template id.
String migrateTemplateId(String? id) {
  if (id == null) return defaultWellnessTemplateId;
  if (wellnessTemplates.any((t) => t.id == id)) return id;
  return _legacy[id] ?? defaultWellnessTemplateId;
}

WellnessTemplate wellnessTemplateById(String? id) {
  final target = migrateTemplateId(id);
  return wellnessTemplates.firstWhere(
    (t) => t.id == target,
    orElse: () => wellnessTemplates.first,
  );
}
