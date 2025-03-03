import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

class _CoordinateOffset {
  final double main, cross;

  _CoordinateOffset(this.main, this.cross);
}

class SpanableSliverGridLayout extends SliverGridLayout {
  /// Creates a layout that uses equally sized and spaced tiles.
  ///
  /// All of the arguments must not be null and must not be negative. The
  /// `crossAxisCount` argument must be greater than zero.
  SpanableSliverGridLayout(this.crossAxisCount, this.childCrossAxisExtent,
      this.crossAxisStride, this.mainAxisSpacing, this.origins)
      : assert(crossAxisCount > 0),
        assert(mainAxisSpacing >= 0),
        assert(childCrossAxisExtent >= 0),
        assert(crossAxisStride >= 0),
        offsets = origins.toPosition(
            crossAxisCount, mainAxisSpacing, crossAxisStride);

  /// The number of children in the cross axis.
  final int crossAxisCount;

  /// The number of pixels from the leading edge of one tile to the trailing
  /// edge of the same tile in the main axis.
  final double mainAxisSpacing;

  /// The number of pixels from the leading edge of one tile to the leading edge
  /// of the next tile in the cross axis.
  final double crossAxisStride;

  /// The number of pixels from the leading edge of one tile to the trailing
  /// edge of the same tile in the cross axis.
  final double childCrossAxisExtent;

  final List<GridTileOrigin> origins;

  final List<Offset> offsets;

  _CoordinateOffset _findOffset(int index) {
    if (index < offsets.length) {
      final Offset offset = offsets[index];
      return _CoordinateOffset(offset.dy, offset.dx);
    } else {
      return _CoordinateOffset(0, 0);
    }
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    for (int i = 0; i < offsets.length; i++) {
      if (origins[i].mainAxisExtent + offsets[i].dy >= scrollOffset) {
        // log('getMinChildIndexForScrollOffset: $scrollOffset, $i');

        return i;
      }
    }

    return 0;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    for (int i = origins.length - 1; i >= 0; i--) {
      if (offsets[i].dy <= scrollOffset) {
        // log('getMaxChildIndexForScrollOffset: $scrollOffset, $i');

        return i;
      }
    }
    return 0;
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final int span = origins[index].crossAxisSpan;
    final double mainAxisExtent = origins[index].mainAxisExtent;
    final _CoordinateOffset offset = _findOffset(index);

    return SliverGridGeometry(
      scrollOffset: offset.main,
      crossAxisOffset: offset.cross,
      mainAxisExtent: mainAxisExtent,
      crossAxisExtent: childCrossAxisExtent + (span - 1) * crossAxisStride,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    if (childCount <= 0) {
      return 0.0;
    }

    double max = 0;
    for (int i = 0; i < origins.length; i++) {
      max = math.max(max, offsets[i].dy + origins[i].mainAxisExtent);
    }
    return max;
  }
}

abstract class SpanableSliverGridDelegate extends SliverGridDelegate {
  /// Creates a delegate that makes grid layouts with a fixed number of tiles in
  /// the cross axis.
  ///
  /// All of the arguments must not be null. The `mainAxisSpacing` and
  /// `crossAxisSpacing` arguments must not be negative. The `crossAxisCount`
  /// and `childAspectRatio` arguments must be greater than zero.
  SpanableSliverGridDelegate(
    this.crossAxisCount, {
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    required this.origins,
  })  : assert(crossAxisCount > 0),
        assert(mainAxisSpacing >= 0),
        assert(crossAxisSpacing >= 0);

  /// The number of children in the cross axis.
  final int crossAxisCount;

  /// The number of logical pixels between each child along the main axis.
  final double mainAxisSpacing;

  /// The number of logical pixels between each child along the cross axis.
  final double crossAxisSpacing;

  final List<GridTileOrigin> origins;

  bool _debugAssertIsValid() {
    assert(crossAxisCount > 0);
    assert(mainAxisSpacing >= 0.0);
    assert(crossAxisSpacing >= 0.0);
    return true;
  }

  double? crossAxisStride;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    assert(_debugAssertIsValid());
    final double usableCrossAxisExtent =
        constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1);
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    crossAxisStride = childCrossAxisExtent + crossAxisSpacing;
    return SpanableSliverGridLayout(
      crossAxisCount,
      childCrossAxisExtent,
      childCrossAxisExtent + crossAxisSpacing,
      mainAxisSpacing,
      origins,
    );
  }

  @override
  bool shouldRelayout(SpanableSliverGridDelegate oldDelegate) {
    return oldDelegate.crossAxisCount != crossAxisCount ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing;
  }
}

extension on List<GridTileOrigin> {
  List<Offset> toPosition(
    int crossAxisCount,
    double mainAxisSpacing,
    double stride,
  ) {
    int computeCrossAxisCellCount(
      GridTileOrigin childParentData,
      int crossAxisCount,
    ) {
      return math.min(
        childParentData.crossAxisSpan,
        crossAxisCount,
      );
    }

    final List<Offset> res = List<Offset>.filled(length, Offset.zero);

    final List<double> offsets = List<double>.filled(crossAxisCount, 0.0);

    for (int i = 0; i < length; i++) {
      final int crossAxisCellCount = computeCrossAxisCellCount(
        this[i],
        crossAxisCount,
      );

      final _TileOrigin origin = _findBestCandidate(offsets, crossAxisCellCount,
          i, this[i].mainAxisExtent, mainAxisSpacing);
      final double mainAxisOffset = origin.mainAxisOffset;
      final double crossAxisOffset = origin.crossAxisIndex * stride;
      final Offset offset = Offset(crossAxisOffset, mainAxisOffset);

      res[i] = offset;

      // Don't forget to update the offsets.
      final double nextTileOffset =
          mainAxisOffset + this[i].mainAxisExtent + mainAxisSpacing;
      for (int i = 0; i < crossAxisCellCount; i++) {
        offsets[origin.crossAxisIndex + i] = nextTileOffset;
      }
    }

    return res;
  }
}

_TileOrigin _findBestCandidate(List<double> offsets, int crossAxisCount,
    int index, double mainAxisExtent, double mainAxisSpacing) {
  final int length = offsets.length;
  _TileOrigin bestCandidate = const _TileOrigin(0, double.infinity);
  for (int i = 0; i < length; i++) {
    final double offset = offsets[i];
    if (_lessOrNearEqual(bestCandidate.mainAxisOffset, offset)) {
      // The potential candidate is already higher than the current best.
      continue;
    }

    int start = 0;
    int span = 0;
    for (int j = 0;
        span < crossAxisCount &&
            j < length &&
            length - j >= crossAxisCount - span;
        j++) {
      if (_lessOrNearEqual(offsets[j], offset)) {
        span++;
        if (span == crossAxisCount) {
          bestCandidate = _TileOrigin(start, offset);
        }
      } else {
        start = j + 1;
        span = 0;
      }
    }
  }
  return bestCandidate;
}

bool _lessOrNearEqual(double a, double b) {
  return a < b || (a - b).abs() < precisionErrorTolerance;
}

class _TileOrigin {
  const _TileOrigin(this.crossAxisIndex, this.mainAxisOffset);

  final int crossAxisIndex;
  final double mainAxisOffset;
}

class GridTileOrigin {
  int crossAxisSpan;
  double mainAxisExtent;
  Key key;

  GridTileOrigin(this.crossAxisSpan, this.mainAxisExtent, this.key);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridTileOrigin &&
          runtimeType == other.runtimeType &&
          crossAxisSpan == other.crossAxisSpan &&
          mainAxisExtent == other.mainAxisExtent;

  @override
  int get hashCode => crossAxisSpan.hashCode ^ mainAxisExtent.hashCode;

  @override
  String toString() {
    return 'GridTile{crossAxisSpan: $crossAxisSpan, mainAxisExtent: $mainAxisExtent}';
  }
}
