import 'package:flutter/material.dart';

/// Single-line text at full size: static when it fits, and a continuous
/// ticker loop when it overflows so the whole label can be read — no
/// ellipsis, no shrinking.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// Scroll speed in logical pixels per second.
  final double velocity;

  /// Blank run between the end of the text and its next repetition.
  final double gap;

  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.velocity = 20,
    this.gap = 40,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final style = widget.style ?? DefaultTextStyle.of(context).style;
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();

      if (painter.width <= constraints.maxWidth) {
        if (_ctrl.isAnimating) _ctrl.stop();
        return Text(widget.text, maxLines: 1, softWrap: false, style: style);
      }

      // Constant speed regardless of text length.
      final loop = painter.width + widget.gap;
      final duration =
          Duration(milliseconds: (loop / widget.velocity * 1000).round());
      if (_ctrl.duration != duration) {
        _ctrl.duration = duration;
        _ctrl.repeat();
      } else if (!_ctrl.isAnimating) {
        _ctrl.repeat();
      }

      return ClipRect(
        child: SizedBox(
          width: constraints.maxWidth,
          height: painter.height,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final dx = -_ctrl.value * loop;
              Widget run(double left) => Positioned(
                    left: left,
                    top: 0,
                    child: Text(widget.text,
                        maxLines: 1, softWrap: false, style: style),
                  );
              return Stack(
                clipBehavior: Clip.none,
                children: [run(dx), run(dx + loop)],
              );
            },
          ),
        ),
      );
    });
  }
}
