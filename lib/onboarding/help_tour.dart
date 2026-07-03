import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One stop in the help tour: which widget to spotlight and what to say.
class HelpTourStep {
  final GlobalKey targetKey;
  final IconData icon;
  final String title;
  final String body;

  const HelpTourStep({
    required this.targetKey,
    required this.icon,
    required this.title,
    required this.body,
  });
}

/// Spotlight-style overlay tour for first-time users.
///
/// Dims the screen, cuts a hole around each step's target widget, and shows
/// a card describing it. Only one tour can be active at a time.
class HelpTour {
  HelpTour._();

  static OverlayEntry? _entry;

  static bool get isActive => _entry != null;

  static void start(
    BuildContext context, {
    required List<HelpTourStep> steps,
    VoidCallback? onFinished,
  }) {
    if (isActive || steps.isEmpty) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (_) => _HelpTourOverlay(
        steps: steps,
        onDismiss: () {
          dismiss();
          onFinished?.call();
        },
      ),
    );
    overlay.insert(_entry!);
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class _HelpTourOverlay extends StatefulWidget {
  final List<HelpTourStep> steps;
  final VoidCallback onDismiss;

  const _HelpTourOverlay({required this.steps, required this.onDismiss});

  @override
  State<_HelpTourOverlay> createState() => _HelpTourOverlayState();
}

class _HelpTourOverlayState extends State<_HelpTourOverlay> {
  static const _spotlightPadding = 6.0;
  static const _spotlightRadius = 12.0;
  static const _cardMargin = 16.0;

  int _index = 0;
  Rect? _previousRect;

  HelpTourStep get _step => widget.steps[_index];

  bool get _isLast => _index == widget.steps.length - 1;

  Rect? _targetRect(HelpTourStep step) {
    final targetContext = step.targetKey.currentContext;
    if (targetContext == null) return null;
    final box = targetContext.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return (origin & box.size).inflate(_spotlightPadding);
  }

  void _next() {
    if (_isLast) {
      widget.onDismiss();
      return;
    }
    setState(() {
      _previousRect = _targetRect(_step);
      _index++;
    });
  }

  void _back() {
    if (_index == 0) return;
    setState(() {
      _previousRect = _targetRect(_step);
      _index--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rect = _targetRect(_step);
    final rectTween = RectTween(begin: _previousRect ?? rect, end: rect);

    return Material(
      type: MaterialType.transparency,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_index),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          final animatedRect =
              rectTween.evaluate(AlwaysStoppedAnimation(t)) ?? rect;
          return LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _next,
                    child: CustomPaint(
                      painter: _ScrimPainter(
                        hole: animatedRect,
                        holeRadius: _spotlightRadius,
                        scrimColor: Colors.black.withValues(
                          // Fade the scrim in on the first step only; later
                          // steps keep it steady while the hole slides.
                          alpha: _previousRect == null ? 0.6 * t : 0.6,
                        ),
                        borderColor: theme.colorScheme.primary
                            .withValues(alpha: 0.9 * t),
                      ),
                    ),
                  ),
                ),
                ..._buildCard(context, constraints, rect, t),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCard(
    BuildContext context,
    BoxConstraints constraints,
    Rect? rect,
    double t,
  ) {
    final screenWidth = constraints.maxWidth;
    final screenHeight = constraints.maxHeight;
    final cardWidth = math.min(340.0, screenWidth - 2 * _cardMargin);

    // Place the card in the larger free region: below the target when the
    // target sits in the top half, above it otherwise. No target → center.
    double? top;
    double? bottom;
    double left;
    if (rect == null) {
      top = screenHeight / 3;
      left = (screenWidth - cardWidth) / 2;
    } else if (rect.center.dy < screenHeight / 2) {
      top = rect.bottom + _cardMargin;
      left = _clampedLeft(rect, cardWidth, screenWidth);
    } else {
      bottom = screenHeight - rect.top + _cardMargin;
      left = _clampedLeft(rect, cardWidth, screenWidth);
    }

    return [
      Positioned(
        top: top,
        bottom: bottom,
        left: left,
        width: cardWidth,
        child: Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12 * (bottom != null ? -1 : 1)),
            child: _StepCard(
              step: _step,
              index: _index,
              total: widget.steps.length,
              isLast: _isLast,
              onSkip: widget.onDismiss,
              onBack: _index > 0 ? _back : null,
              onNext: _next,
            ),
          ),
        ),
      ),
    ];
  }

  double _clampedLeft(Rect rect, double cardWidth, double screenWidth) {
    return (rect.center.dx - cardWidth / 2)
        .clamp(_cardMargin, math.max(_cardMargin, screenWidth - _cardMargin - cardWidth));
  }
}

class _StepCard extends StatelessWidget {
  final HelpTourStep step;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  const _StepCard({
    required this.step,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(step.icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(step.title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(step.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _ProgressDots(index: index, total: total),
                const Spacer(),
                if (!isLast)
                  TextButton(onPressed: onSkip, child: const Text('Skip')),
                if (onBack != null)
                  TextButton(onPressed: onBack, child: const Text('Back')),
                FilledButton(
                  onPressed: onNext,
                  child: Text(isLast ? 'Done' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int index;
  final int total;

  const _ProgressDots({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 4),
            width: i == index ? 14 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i == index
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
          ),
      ],
    );
  }
}

class _ScrimPainter extends CustomPainter {
  final Rect? hole;
  final double holeRadius;
  final Color scrimColor;
  final Color borderColor;

  const _ScrimPainter({
    required this.hole,
    required this.holeRadius,
    required this.scrimColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    RRect? rrect;
    if (hole != null) {
      rrect = RRect.fromRectAndRadius(hole!, Radius.circular(holeRadius));
      path.addRRect(rrect);
      path.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = scrimColor);
    if (rrect != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = borderColor,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) =>
      hole != oldDelegate.hole ||
      scrimColor != oldDelegate.scrimColor ||
      borderColor != oldDelegate.borderColor;
}
