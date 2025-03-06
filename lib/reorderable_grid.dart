part of 'reorderable.dart';

class _GridDragInfo extends _DragInfo {
  _GridDragInfo({
    required super.item,
    super.initialPosition = Offset.zero,
    super.scrollDirection = Axis.vertical,
    super.onUpdate,
    super.onEnd,
    super.onCancel,
    super.onDropCompleted,
    super.proxyDecorator,
    required super.tickerProvider,
  });

  @override
  void update(DragUpdateDetails details) {
    dragPosition += details.delta;
    onUpdate?.call(this, dragPosition, details.delta);
  }
}

class _ReorderableGridItem extends _ReorderableItem {
  const _ReorderableGridItem({
    required super.key,
    required super.index,
    required super.child,
    required super.capturedThemes,
    super.shadowBuilder,
    super.lockedKeys,
  });

  @override
  _ReorderableItemState<_ReorderableItem> createState() =>
      _ReorderableGridItemState();
}

class _ReorderableGridItemState
    extends _ReorderableItemState<_ReorderableGridItem> {
  @override
  Offset _calculateNewTargetOffset(bool reverse,
      {Map<Key, Offset>? oldOffsets, Map<Key, Offset>? offsets}) {
    if (oldOffsets == null || offsets == null) {
      return Offset.zero;
    }
    return offsets[widget.child.key]! - oldOffsets[widget.child.key]!;
  }
}

class SliverReorderableGrid extends SliverReorderable {
  const SliverReorderableGrid({
    super.key,
    required super.itemBuilder,
    super.findChildIndexCallback,
    required super.itemCount,
    required super.onReorder,
    required this.gridDelegate,
    super.onReorderStart,
    super.onReorderEnd,
    super.proxyDecorator,
    super.shadowBuilder,
    super.lockedKeys,
  });

  final SliverGridDelegate gridDelegate;

  @override
  SliverReorderableState<SliverReorderable> createState() =>
      SliverReorderableGridState();
}

class SliverReorderableGridState
    extends SliverReorderableState<SliverReorderableGrid> {
  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasOverlay(context));
    final SliverChildBuilderDelegate childrenDelegate =
        SliverChildBuilderDelegate(
      _itemBuilder,
      childCount: widget.itemCount,
      findChildIndexCallback: widget.findChildIndexCallback,
    );
    return SliverGrid(
      delegate: childrenDelegate,
      gridDelegate: widget.gridDelegate,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final HomeGridDelegate gridDelegate =
          widget.gridDelegate as HomeGridDelegate;
      if (gridDelegate.crossAxisStride != null) {
        crossAxisStride = gridDelegate.crossAxisStride;
      }
      if (gridDelegate.childCrossAxisExtent != null) {
        childCrossAxisExtent = gridDelegate.childCrossAxisExtent;
      }
    });
  }

  @override
  _ReorderableItem _createReorderableItem(
      Key key, int index, BuildContext overlayContext, Widget child) {
    return _ReorderableGridItem(
      key: _ReorderableItemGlobalKey(key, index, this),
      index: index,
      capturedThemes: InheritedTheme.capture(from: context, to: overlayContext),
      shadowBuilder: widget.shadowBuilder,
      child: child,
      lockedKeys: widget.lockedKeys,
    );
  }

  @override
  _DragInfo _createDragInfo(
      _ReorderableItemState<_ReorderableItem> item, Offset position) {
    return _GridDragInfo(
      item: item,
      initialPosition: position,
      scrollDirection: _scrollDirection,
      onUpdate: _dragUpdate,
      onCancel: _dragCancel,
      onEnd: _dragEnd,
      onDropCompleted: _dropCompleted,
      proxyDecorator: widget.proxyDecorator,
      tickerProvider: this,
    );
  }

  Key? lastHit;

  @override
  void _dragUpdateItems() {
    assert(_dragInfo != null);

    int newIndex = _insertIndex!;
    for (final _ReorderableItemState<_ReorderableItem> item in _items.values) {
      if (item._offsetAnimation != null ||
          widget.lockedKeys.contains(item.widget.child.key)) {
        continue;
      }

      final RenderBox renderBox = item.context.findRenderObject()! as RenderBox;
      final Rect rect =
          (renderBox.localToGlobal(Offset.zero) + item.offset) & renderBox.size;
      if (rect.contains(_dragInfo!.dragPosition)) {
        if (item.widget.child.key == lastHit) {
          continue;
        }
        lastHit = item.widget.child.key;
        newIndex = item.tidx ?? item.index;
        break;
      }
    }
    final HomeGridDelegate gridDelegate =
        widget.gridDelegate as HomeGridDelegate;

    final List<GridTileOrigin> origins = List<GridTileOrigin>.from(
        (widget.gridDelegate as HomeGridDelegate).origins);

    final Map<Key, Offset> oldOffset = origins.toPosition(
        gridDelegate.crossAxisCount,
        gridDelegate.mainAxisSpacing,
        gridDelegate.crossAxisStride ?? crossAxisStride!);

    if (newIndex != _insertIndex) {
      _insertIndex = newIndex;
      final int fromIndex = _dragIndex!;
      final int toIndex = _insertIndex!;
      final GridTileOrigin origin = origins.removeAt(fromIndex);
      origins.insert(toIndex, origin);

      final Map<Key, Offset> offsets = origins.toPosition(
          gridDelegate.crossAxisCount,
          gridDelegate.mainAxisSpacing,
          gridDelegate.crossAxisStride ?? crossAxisStride!);
      for (final _ReorderableItemState<_ReorderableItem> item
          in _items.values) {
        item.tidx = origins.indexWhere(
            (GridTileOrigin element) => element.key == item.widget.child.key);
        if (!item.mounted) {
          continue;
        }
        item.updateForGap(true, _reverse,
            oldOffsets: oldOffset, offsets: offsets);
      }
    }
  }

  double? crossAxisStride;

  double? childCrossAxisExtent;

  void updateSize(Key key, GridTileOrigin org) {
    final HomeGridDelegate gridDelegate =
        widget.gridDelegate as HomeGridDelegate;

    final List<GridTileOrigin> origins = List<GridTileOrigin>.from(
        (widget.gridDelegate as HomeGridDelegate).origins);

    final Map<Key, Offset> oldOffset = origins.toPosition(
        gridDelegate.crossAxisCount,
        gridDelegate.mainAxisSpacing,
        crossAxisStride!);

    GridTileOrigin? origin;
    for (int i = 0; i < origins.length; i++) {
      if (origins[i].key == key) {
        origin = origins[i];
        origins[i] = org;
      }
    }

    final Map<Key, Offset> offsets = origins.toPosition(
        gridDelegate.crossAxisCount,
        gridDelegate.mainAxisSpacing,
        crossAxisStride!);

    for (final _ReorderableItemState<_ReorderableItem> item in _items.values) {
      if (!item.mounted) {
        continue;
      }
      if ((item.key as _ReorderableItemGlobalKey).subKey == key) {
        item.updatePositioned(
            _crossExtent(origin?.crossAxisSpan ?? 1) -
                _crossExtent(org.crossAxisSpan),
            (origin?.mainAxisExtent ?? 1) - org.mainAxisExtent);
      }
      item.updateForGap(true, _reverse,
          oldOffsets: oldOffset, offsets: offsets);
    }
  }

  double _crossExtent(int span) {
    return childCrossAxisExtent! + (span - 1) * crossAxisStride!;
  }

  void resetItemSize() {
    for (final _ReorderableItemState<_ReorderableItem> item in _items.values) {
      item.resetPositioned();
    }
    super._resetItemGap();
  }

  void _dragEnd(_DragInfo item) {
    setState(() {
      try {
        _finalDropPosition = _itemOffsetAt(_dragIndex!);
      } catch (e) {}
    });
    widget.onReorderEnd?.call(_insertIndex!);
  }

  @override
  Offset _itemOffsetAt(int index) {
    // calculate relative position of target
    // delegateNew[insertIndex] - delegateNew[insertIndex + 1] + (insertIndex + 1)'s localToGlobal

    final HomeGridDelegate gridDelegate =
        widget.gridDelegate as HomeGridDelegate;

    final List<GridTileOrigin> origins = List<GridTileOrigin>.from(
        (widget.gridDelegate as HomeGridDelegate).origins);

    final int fromIndex = _dragIndex!;
    final int toIndex = _insertIndex!;
    final GridTileOrigin origin = origins.removeAt(fromIndex);
    origins.insert(toIndex, origin);

    final Map<Key, Offset> offsets = origins.toPosition(
        gridDelegate.crossAxisCount,
        gridDelegate.mainAxisSpacing,
        gridDelegate.crossAxisStride ?? crossAxisStride!);

    // delegateNew[insertIndex] - delegateNew[insertIndex + 1] +
    final Offset off =
        offsets[origins[toIndex + 1].key]! - offsets[origin.key]!;

    // (insertIndex + 1)'s localToGlobal
    final _ReorderableItemState<_ReorderableItem> item = _items.values
        .where((_ReorderableItemState<_ReorderableItem> element) =>
            element.widget.child.key == origins[toIndex + 1].key)
        .first;

    final RenderBox itemRenderBox =
        item.context.findRenderObject()! as RenderBox;
    final Offset offset =
        itemRenderBox.localToGlobal(Offset.zero) + item._targetOffset;

    return offset - off;
  }

  void _dropCompleted() {
    final int fromIndex = _dragIndex!;
    final int toIndex = _insertIndex!;
    if (fromIndex != toIndex) {
      widget.onReorder.call(fromIndex, toIndex);
    }
    setState(() {
      _dragReset();
    });
  }
}

class ReorderableGrid extends StatefulWidget {
  /// Creates a scrolling container that allows the user to interactively
  /// reorder the grid items.
  ///
  /// The [itemCount] must be greater than or equal to zero.
  const ReorderableGrid({
    super.key,
    required this.gridDelegate,
    required this.itemBuilder,
    required this.itemCount,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.proxyDecorator,
    this.padding,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.anchor = 0.0,
    this.cacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.shadowBuilder,
  }) : assert(itemCount >= 0);

  /// The delegate that controls the size and position of the children.
  final SliverGridDelegate gridDelegate;

  /// {@macro reorderable.itemBuilder}
  final IndexedWidgetBuilder itemBuilder;

  /// {@macro reorderable.shadowBuilder}
  final ShadowBuilder? shadowBuilder;

  /// {@macro reorderable.itemCount}
  final int itemCount;

  /// {@macro reorderable.onReorder}
  final ReorderCallback onReorder;

  /// {@macro reorderable.onReorderStart}
  final void Function(int index)? onReorderStart;

  /// {@macro reorderable.onReorderEnd}
  final void Function(int index)? onReorderEnd;

  /// {@macro reorderable.proxyDecorator}
  final ReorderItemProxyDecorator? proxyDecorator;

  /// The amount of space by which to inset the grid contents.
  ///
  /// It defaults to `EdgeInsets.all(0)`.
  final EdgeInsetsGeometry? padding;

  /// {@macro flutter.widgets.scroll_view.scrollDirection}
  final Axis scrollDirection;

  /// {@macro flutter.widgets.scroll_view.reverse}
  final bool reverse;

  /// {@macro flutter.widgets.scroll_view.controller}
  final ScrollController? controller;

  /// {@macro flutter.widgets.scroll_view.primary}
  final bool? primary;

  /// {@macro flutter.widgets.scroll_view.physics}
  final ScrollPhysics? physics;

  /// {@macro flutter.widgets.scroll_view.shrinkWrap}
  final bool shrinkWrap;

  /// {@macro flutter.widgets.scroll_view.anchor}
  final double anchor;

  /// {@macro flutter.rendering.RenderViewportBase.cacheExtent}
  final double? cacheExtent;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@macro flutter.widgets.scroll_view.keyboardDismissBehavior}
  ///
  /// The default is [ScrollViewKeyboardDismissBehavior.manual]
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// {@macro flutter.widgets.scrollable.restorationId}
  final String? restorationId;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge].
  final Clip clipBehavior;

  /// The state from the closest instance of this class that encloses the given
  /// context.
  ///
  /// This method is typically used by [ReorderableGrid] item widgets that
  /// insert or remove items in response to user input.
  ///
  /// If no [ReorderableGrid] surrounds the given context, then this function
  /// will assert in debug mode and throw an exception in release mode.
  ///
  /// This method can be expensive (it walks the element tree).
  ///
  /// See also:
  ///
  ///  * [maybeOf], a similar function that will return null if no
  ///    [ReorderableGrid] ancestor is found.
  static ReorderableGridState of(BuildContext context) {
    final ReorderableGridState? result =
        context.findAncestorStateOfType<ReorderableGridState>();
    assert(() {
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'ReorderableGrid.of() called with a context that does not contain a ReorderableGrid.'),
          ErrorDescription(
            'No ReorderableGrid ancestor could be found starting from the context that was passed to ReorderableGrid.of().',
          ),
          ErrorHint(
              'This can happen when the context provided is from the same StatefulWidget that '
              'built the ReorderableGrid.'),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return result!;
  }

  /// The state from the closest instance of this class that encloses the given
  /// context.
  ///
  /// This method is typically used by [ReorderableGrid] item widgets that insert
  /// or remove items in response to user input.
  ///
  /// If no [ReorderableGrid] surrounds the context given, then this function will
  /// return null.
  ///
  /// This method can be expensive (it walks the element tree).
  ///
  /// See also:
  ///
  ///  * [of], a similar function that will throw if no [ReorderableGrid] ancestor
  ///    is found.
  static ReorderableGridState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<ReorderableGridState>();
  }

  @override
  ReorderableGridState createState() => ReorderableGridState();
}

/// The state for a grid that allows the user to interactively reorder
/// the grid items.
///
/// An app that needs to start a new item drag or cancel an existing one
/// can refer to the [ReorderableGrid]'s state with a global key:
///
/// ```dart
/// GlobalKey<ReorderableGridState> gridKey = GlobalKey<ReorderableGridState>();
/// ...
/// ReorderableGrid(key: gridKey, ...);
/// ...
/// gridKey.currentState.cancelReorder();
/// ```
class ReorderableGridState extends State<ReorderableGrid> {
  final GlobalKey<SliverReorderableState<SliverReorderable>> _globalKey =
      GlobalKey();

  /// Initiate the dragging of the item at [index] that was started with
  /// the pointer down [event].
  ///
  /// The given [recognizer] will be used to recognize and start the drag
  /// item tracking and lead to either an item reorder, or a cancelled drag.
  /// The grid will take ownership of the returned recognizer and will dispose
  /// it when it is no longer needed.
  ///
  /// Most applications will not use this directly, but will wrap the item
  /// (or part of the item, like a drag handle) in either a
  /// [ReorderableDragStartListener] or [ReorderableDelayedDragStartListener]
  /// which call this for the application.
  void startItemDragReorder({
    required int index,
    required PointerDownEvent event,
    required MultiDragGestureRecognizer recognizer,
  }) {
    final SliverReorderableState<SliverReorderable> state =
        _globalKey.currentState!;
    state.startItemDragReorder(
        index: index,
        event: event,
        recognizer: recognizer..onStart = state._dragStart);
  }

  /// Cancel any item drag in progress.
  ///
  /// This should be called before any major changes to the item list
  /// occur so that any item drags will not get confused by
  /// changes to the underlying list.
  ///
  /// If no drag is active, this will do nothing.
  void cancelReorder() {
    _globalKey.currentState!.cancelReorder();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      controller: widget.controller,
      primary: widget.primary,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      anchor: widget.anchor,
      cacheExtent: widget.cacheExtent,
      dragStartBehavior: widget.dragStartBehavior,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      restorationId: widget.restorationId,
      clipBehavior: widget.clipBehavior,
      slivers: <Widget>[
        SliverPadding(
          padding: widget.padding ?? EdgeInsets.zero,
          sliver: SliverReorderableGrid(
            key: _globalKey,
            gridDelegate: widget.gridDelegate,
            itemBuilder: widget.itemBuilder,
            itemCount: widget.itemCount,
            onReorder: widget.onReorder,
            onReorderStart: widget.onReorderStart,
            onReorderEnd: widget.onReorderEnd,
            proxyDecorator: widget.proxyDecorator,
            shadowBuilder: widget.shadowBuilder,
          ),
        ),
      ],
    );
  }
}

class HomeGridDelegate extends SpanableSliverGridDelegate {
  HomeGridDelegate(List<GridTileOrigin> list)
      : super(4, mainAxisSpacing: 12.0, crossAxisSpacing: 12.0, origins: list);

  @override
  bool shouldRelayout(HomeGridDelegate oldDelegate) {
    return super.shouldRelayout(oldDelegate) ||
        !listEquals(oldDelegate.origins, origins);
  }
}

extension on List<GridTileOrigin> {
  Map<Key, Offset> toPosition(
    int crossAxisCount,
    double mainAxisSpacing,
    double stride,
  ) {
    int computeCrossAxisCellCount(
      GridTileOrigin childParentData,
      int crossAxisCount,
    ) {
      return min(
        childParentData.crossAxisSpan,
        crossAxisCount,
      );
    }

    // List<Offset> res = List<Offset>.filled(length, Offset.zero);
    Map<Key, Offset> res = <Key, Offset>{};

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

      res[this[i].key] = offset;

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
