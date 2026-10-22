import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/settings/widgets/menu_bar_mode_picker.dart';

void main() {
  test('every mode round-trips through the persisted styles', () {
    for (final mode in [
      'companion',
      'progress',
      'focusdot',
      'countdown',
      'minimal',
    ]) {
      final s = menuBarModeToStyles(mode);
      expect(menuBarModeFromStyles(s.iconStyle, s.menuStyle), mode);
    }
  });

  test('companion only owns the icon; others use the default icon', () {
    expect(menuBarModeToStyles('companion').iconStyle, 'companion');
    expect(menuBarModeToStyles('progress').iconStyle, 'default');
    expect(menuBarModeToStyles('minimal').menuStyle, 'icon');
  });

  test('legacy saved values still resolve', () {
    expect(menuBarModeFromStyles('cat', 'countdown'), 'companion');
    expect(menuBarModeFromStyles('default', 'icon'), 'minimal');
    expect(menuBarModeFromStyles('default', 'anything'), 'minimal');
  });
}
