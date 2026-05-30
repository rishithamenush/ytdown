import 'package:flutter/material.dart';

/// Wraps any tappable child with a subtle scale-down animation while pressed,
/// giving the UI a tactile, "physical" feel. Purely visual — the actual tap
/// handling stays with the child's own [InkWell]/[GestureDetector] unless an
/// [onTap] is supplied here.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (!widget.enabled) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final hasGestures = widget.onTap != null || widget.onLongPress != null;

    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        // Let taps fall through to descendant InkWells when we don't own them.
        behavior: hasGestures
            ? HitTestBehavior.opaque
            : HitTestBehavior.deferToChild,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
