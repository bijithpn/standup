import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/shared/shared.dart';

class FigmaValueInput extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  const FigmaValueInput({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  State<FigmaValueInput> createState() => _FigmaValueInputState();
}

class _FigmaValueInputState extends State<FigmaValueInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(2));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant FigmaValueInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _submitValue();
    }
  }

  void _submitValue() {
    final parsed = double.tryParse(_controller.text);
    if (parsed != null) {
      final clamped = parsed.clamp(widget.min, widget.max);
      widget.onChanged(clamped);
      _controller.text = clamped.toStringAsFixed(2);
    } else {
      _controller.text = widget.value.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(
          icon: CupertinoIcons.minus,
          onPressed: widget.value > widget.min
              ? () {
                  final newVal = (widget.value - widget.step).clamp(
                    widget.min,
                    widget.max,
                  );
                  widget.onChanged(newVal);
                  _controller.text = newVal.toStringAsFixed(2);
                }
              : null,
        ),
        const SizedBox(width: 4),
        Container(
          width: 44,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              fontFamily: 'SFMono-Regular, Consolas, Courier, monospace',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              border: InputBorder.none,
            ),
            onSubmitted: (_) => _submitValue(),
          ),
        ),
        const SizedBox(width: 4),
        _btn(
          icon: CupertinoIcons.plus,
          onPressed: widget.value < widget.max
              ? () {
                  final newVal = (widget.value + widget.step).clamp(
                    widget.min,
                    widget.max,
                  );
                  widget.onChanged(newVal);
                  _controller.text = newVal.toStringAsFixed(2);
                }
              : null,
        ),
      ],
    );
  }

  Widget _btn({required IconData icon, VoidCallback? onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 18,
        height: 22,
        decoration: BoxDecoration(
          color: onPressed == null
              ? Colors.transparent
              : AppTheme.textSecondary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: onPressed == null ? Colors.transparent : AppTheme.border,
            width: 0.5,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 8,
            color: onPressed == null
                ? AppTheme.textMuted.withValues(alpha: 0.3)
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
