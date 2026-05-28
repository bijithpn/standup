
import 'template_model.dart';

class BreakDisplayState {
  final bool isVisible;
  final TemplateModel? activeTemplate;
  final double animationProgress;

  const BreakDisplayState({
    this.isVisible = false,
    this.activeTemplate,
    this.animationProgress = 0.0,
  });

  BreakDisplayState copyWith({
    bool? isVisible,
    TemplateModel? activeTemplate,
    double? animationProgress,
  }) {
    return BreakDisplayState(
      isVisible: isVisible ?? this.isVisible,
      activeTemplate: activeTemplate ?? this.activeTemplate,
      animationProgress: animationProgress ?? this.animationProgress,
    );
  }
}
