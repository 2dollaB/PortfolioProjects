import 'package:flutter/material.dart';

/// Picks the right grid shape based on viewport width:
///  - **Phone** (< 500): 2-column scrollable GridView. Cards stay readable.
///  - **Tablet** (500-800): 3-column scrollable GridView. Same scrollable
///    pattern, just more cards per row.
///  - **Desktop / TV** (≥ 800): [AdaptiveTileGrid] that fills the rect for
///    casting onto a TV.
class ResponsiveParticipantGrid extends StatelessWidget {
  final int count;
  final Widget Function(BuildContext, int) tileBuilder;
  final EdgeInsets padding;
  final double gap;

  /// Card aspect ratio (width / height). 1.0 = square. Below 1.0 = tall.
  final double scrollAspectRatio;

  const ResponsiveParticipantGrid({
    super.key,
    required this.count,
    required this.tileBuilder,
    this.padding = EdgeInsets.zero,
    this.gap = 8,
    this.scrollAspectRatio = 0.95,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < 800) {
          // Phone OR tablet — scrollable column-based grid. Cards stay
          // tall enough to read at distance.
          final cols = w < 500 ? 2 : 3;
          return GridView.builder(
            padding: padding,
            itemCount: count,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              childAspectRatio: scrollAspectRatio,
            ),
            itemBuilder: tileBuilder,
          );
        }
        // Desktop / TV — fill the rect with the adaptive grid.
        return AdaptiveTileGrid(
          count: count,
          tileBuilder: tileBuilder,
          padding: padding,
          gap: gap,
        );
      },
    );
  }
}

/// Returns the (cols, rows) grid that best fits [count] participants
/// on a TV-style landscape display. Empty trailing slots are left blank
/// so the visual rhythm (e.g. 4+4+1 for 9 athletes) is preserved.
({int cols, int rows}) optimalGrid(int count) {
  if (count <= 1) return (cols: 1, rows: 1);
  if (count == 2) return (cols: 2, rows: 1);
  if (count == 3) return (cols: 3, rows: 1);
  if (count == 4) return (cols: 2, rows: 2);
  if (count <= 6) return (cols: 3, rows: 2);
  if (count <= 8) return (cols: 4, rows: 2);
  if (count <= 12) return (cols: 4, rows: 3);
  if (count <= 16) return (cols: 4, rows: 4);
  if (count <= 20) return (cols: 5, rows: 4);
  return (cols: 6, rows: 4); // up to 24
}

/// Fills the available rect with [count] tiles arranged in the optimal grid
/// from [optimalGrid]. Each tile is sized to fill its cell — no aspect-ratio
/// guessing, no empty whitespace from childAspectRatio mismatches.
class AdaptiveTileGrid extends StatelessWidget {
  final int count;
  final Widget Function(BuildContext, int index) tileBuilder;
  final double gap;
  final EdgeInsets padding;

  const AdaptiveTileGrid({
    super.key,
    required this.count,
    required this.tileBuilder,
    this.gap = 6,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final grid = optimalGrid(count);
    return Padding(
      padding: padding,
      child: Column(
        children: List.generate(grid.rows, (r) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: r > 0 ? gap : 0),
              child: Row(
                children: List.generate(grid.cols, (c) {
                  final idx = r * grid.cols + c;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: c > 0 ? gap : 0),
                      child:
                          idx < count ? tileBuilder(context, idx) : const SizedBox(),
                    ),
                  );
                }),
              ),
            ),
          );
        }),
      ),
    );
  }
}
