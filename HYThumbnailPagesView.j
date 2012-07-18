@import <AppKit/CPView.j>

/*
  Data Source must implement the protocol:

  - (int) sectionCount
  - (int) pageCountForSection: (int)sectionIndex
  - (CPSize) pageSize
  - (CPView) viewForPageAtIndexPath: (CPIndexPath)indexPath

  Delegate Methods. Supports drag-n-drop.

  - (int) pageTypeAtIndexPath: (CPIndexPath)indexPath
  - (BOOL) isDraggablePageAtIndexPath: (CPIndexPath)indexPath
  - (BOOL) acceptsDropFromIndexPath: (CPIndexPath)droppedIndexPath toIndexPath: (CPIndexPath)toIndexPath
*/

@implementation CPIndexPath (HYThumbnailPagesViewAdditions)
+ (CPIndexPath) indexPathWithSection: (int)sectionIdx page: (int)pageIdx
{
  return [CPIndexPath indexPathWithIndexes: [sectionIdx, pageIdx] length: 2];
}
- (int) section { return [self indexAtPosition: 0]; }
- (int) page { return [self indexAtPosition: 1]; }
@end

var HYThumbnailPagesViewDefaultSpacing = 20;

/* pageType */
HYSingularPage = 0;
HYSeperablePairPage = 1;
HYNonseperablePairPage = 2;

HYThumbnailPagesViewSinglePageDragType = "HYThumbnailPagesViewSinglePageDragType"
HYThumbnailPagesViewDoublePageDragType = "HYThumbnailPagesViewDoublePageDragType"


@implementation HYThumbnailPagesView : CPView
{
  id _dataSource @accessors(property=dataSource);
  id _delegate @accessors(property=delegate);
  int _sectionCount;
  CPArray _viewsForSection; // array of array of views
  CPMutableArray _containerViews; // array of views
  CPArray _cachedFramesForSection; // array of array of CGRect

  CPEvent _mouseDownEvent;
  CPView _selectedView;
  CPIndexPath _droppingIndexPath;
}

- (id) initWithFrame: (CGRect)aFrame
{
  self = [super initWithFrame: aFrame];
  if (self) {
    [self registerForDraggedTypes: [HYThumbnailPagesViewSinglePageDragType, HYThumbnailPagesViewDoublePageDragType]];
  }
  return self;
}

- (void) reloadData
{
  if (_viewsForSection != nil) { // remove all the views.
    var sectionIdx = 0;
    for (sectionIdx = [_viewsForSection count] - 1; sectionIdx >= 0; sectionIdx--) {
      var views = _viewsForSection[sectionIdx];
      var idx = 0;
      for (idx = [views count] - 1; idx >= 0; idx--) {
        var view = views[idx];
        [view removeFromSuperView];
      }
    }
  }

  if (_containerViews != nil) { // remove all the container views
    var idx = 0;
    for (idx = [_containerViews count] - 1; idx >= 0; idx--)
      [_containerViews[idx] removeFromSuperView];
  }

  _sectionCount = [_dataSource sectionCount];
  _viewsForSection = [CPMutableArray new];
  _containerViews = [CPMutableArray new];

  var pageSize = [_dataSource pageSize];
  var sectionIdx = 0;
  for (sectionIdx = 0; sectionIdx < _sectionCount; sectionIdx++) {
    var idx, pageCount = [_dataSource pageCountForSection: sectionIdx];
    var sectionViews = [CPMutableArray new];

    var containerView = [HYThumbnailPageContainerView new];

    for (idx = 0; idx < pageCount; idx++) {
      var indexPath = [CPIndexPath indexPathWithSection: sectionIdx page: idx];
      var view = [_dataSource viewForPageAtIndexPath: indexPath];
      [sectionViews addObject: view];

      /* Usually creates a new container unless the this view is the first part of a pair page. */
      var pageType = [_delegate respondsToSelector: @selector(pageTypeAtIndexPath:)] ? [_delegate pageTypeAtIndexPath: indexPath] : HYSingularPage;
      var needsToCreateNewContainerForNextPageView = (pageType == HYSingularPage) || ![containerView isEmpty];

      var wrapperView = [SinglePageBackgroundView new];
      [wrapperView addSubview: view];
      [wrapperView setIndexPath: indexPath];
      [wrapperView setPageType: pageType];

      // DEBUG ONLY
      if (pageType == HYNonseperablePairPage) [wrapperView setBackgroundColor: [CPColor colorWithHexString: "EEFFBB"]];

      [view setFrameOrigin: CGPointMakeZero()];
      [view setFrameSize: pageSize];

      [containerView addView: wrapperView];
      [containerView setSection: sectionIdx];

      if (needsToCreateNewContainerForNextPageView) {
        [_containerViews addObject: containerView];
        [self addSubview: containerView];
        containerView = [HYThumbnailPageContainerView new];
      }
    }
    [_viewsForSection addObject: sectionViews];
  }

  [self setNeedsLayout];
}

- (void) layoutSubviews
{
  var horizontalPadding = 20, verticalPadding = 20;
  var width = [self bounds].size.width;
  var size = [_dataSource pageSize];

  var previousX = horizontalPadding;
  var previousY = verticalPadding;
  var previousSection = 0;

  _cachedFramesForSection = [];
  for (var idx = 0; idx < _sectionCount; idx++)
    _cachedFramesForSection[idx] = [];

  for (var idx = 0; idx < [_containerViews count]; idx++) {
    var container = _containerViews[idx];
    var containerWidth = [container pageCount] * size.width;

    var needsNewRow = (previousX + containerWidth > width - horizontalPadding) || ([container section] != previousSection);
    if (needsNewRow) {
      previousX = horizontalPadding;
      previousY += size.height+ HYThumbnailPagesViewDefaultSpacing;
      previousSection = [container section];
    }

    [container setFrame: CGRectMake(previousX, previousY, containerWidth, size.height)];

    if ([container pageCount] == 1) {
      var view = [container leftView];
      [view setFrame: CGRectMake(0, 0, size.width, size.height)];
      _cachedFramesForSection[[container section]].push([self convertRect: [view frame] fromView: container]);
    } else if ([container pageCount] == 2) {
      var view = [container leftView];
      [view setFrame: CGRectMake(0, 0, size.width, size.height)];
      _cachedFramesForSection[[container section]].push([self convertRect: [view frame] fromView: container]);

      view = [container rightView];
      [view setFrame: CGRectMake(size.width, 0, size.width, size.height)];
      _cachedFramesForSection[[container section]].push([self convertRect: [view frame] fromView: container]);
    }

    previousX += (containerWidth + HYThumbnailPagesViewDefaultSpacing);
  }

  for (var idx = 0; idx < _sectionCount; idx++)
    for (var p = 0; p < [_cachedFramesForSection[idx] count]; p++) {
      // CPLog("[" + idx + "][" + p + "]=" + CPStringFromRect(_cachedFramesForSection[idx][p]));
    }
}

- (void) mouseDown: (CPEvent)anEvent
{
  _mouseDownEvent = anEvent;
  // Select page.
  var locationInView = [self convertPointFromBase: [anEvent locationInWindow]];

  _selectedView = [self viewAtPoint: locationInView];
}

- (CPView) viewAtPoint: (CGPoint)aPoint
{
  var sectionIdx = 0;
  for (sectionIdx = 0; sectionIdx < _sectionCount; sectionIdx++) {
    var viewsInSection = _viewsForSection[sectionIdx];
    var idx = 0, pageCountForSection = [viewsInSection count];
    for (idx = 0; idx < pageCountForSection; idx++) {
      var view = viewsInSection[idx];
      var viewRect = [self convertRect: [view frame] fromView: view];
      if (CPRectContainsPoint(viewRect, aPoint)) {
        return view;
      }
    }
  }
  return nil;
}

- (CPIndexPath) indexPathAtPoint: (CGPoint)aPoint
{
  var sectionIdx = 0;
  for (sectionIdx = 0; sectionIdx < _sectionCount; sectionIdx++) {
    var viewsInSection = _viewsForSection[sectionIdx];
    var pageCountForSection = [viewsInSection count];
    for (var idx = 0; idx < pageCountForSection; idx++) {
      if (CPRectContainsPoint(_cachedFramesForSection[sectionIdx][idx], aPoint)) {
        // CPLog("{" + sectionIdx + ", " + idx + "} = " + CPStringFromRect(_cachedFramesForSection[sectionIdx][idx]) + " contains " + CPStringFromPoint(aPoint));
        return [CPIndexPath indexPathWithSection: sectionIdx page: idx];
      }
    }
  }
  return nil;
}

- (void) mouseDragged: (CPEvent)anEvent
{
  if (_selectedView == nil) return;

  var locationInWindow = [anEvent locationInWindow],
      mouseDownLocationInWindow = [_mouseDownEvent locationInWindow];

  // FIXME: This is because Safari's drag hysteresis is 3px x 3px
  if ((ABS(locationInWindow.x - mouseDownLocationInWindow.x) < 3) &&
      (ABS(locationInWindow.y - mouseDownLocationInWindow.y) < 3))
      return;


  // Set up the pasteboard
  var dragTypes = [HYThumbnailPagesViewSinglePageDragType]; // Well, dragType seems doesn't matter in my implementation. May fix this later.
  var pb = [[CPPasteboard pasteboardWithName: CPDragPboard] declareTypes: dragTypes owner: self];

  var mouseDownLocationInView = [self convertPointFromBase: mouseDownLocationInWindow];

  var indexPath = [[_selectedView superview] indexPath]; // superview is a SinglePageBackgroundView

  if ([_delegate respondsToSelector: @selector(isDraggablePageAtIndexPath:)] && ![_delegate isDraggablePageAtIndexPath: indexPath])
    return;

  var draggedView = [CPView new];
  [draggedView setBackgroundColor: [CPColor whiteColor]];
  [draggedView setAlphaValue: 0.5];

  if ([[_selectedView superview] pageType] == HYNonseperablePairPage) {
    // find the corresponding page
    [draggedView setFrameSize: [[[_selectedView superview] superview] bounds].size];

  } else {
    [draggedView setFrameSize: [[_selectedView superview] bounds].size];
    var draggedContent = [_dataSource viewForPageAtIndexPath: indexPath];
    [draggedContent setFrame: [_selectedView frame]];
    [draggedView addSubview: draggedContent];
  }

  var origin = [self convertPoint: [_selectedView bounds].origin fromView: _selectedView];

  [self dragView: draggedView at: origin offset: CGSizeMakeZero() event: _mouseDownEvent pasteboard: pb source: self slideBack: YES];
}

- (void) mouseUp: (CPEvent)anEvent
{
  // Drag won't invoke this method. Only mouse click will.
}

- (void) draggedView: (CPView)aView beganAt: (CGPoint)aPoint
{
  CPLog("begin");
}

/* Returns an array containing the index of the corresponding element from original array. */
- (CPArray) newOrderIndexesByMovingIndexPath: (CPIndexPath)fromIndexPath toIndexPath: (CPIndexPath)toIndexPath
{
  var section = [fromIndexPath section];
  var views = _viewsForSection[section];
  var pages = [views count];
  var doublePage = [[views[[fromIndexPath page]] superview] pageType] == HYNonseperablePairPage;

  var newOrder = [];
  var leftIndex = Math.min([fromIndexPath page], [toIndexPath page]),
      rightIndex = Math.max([fromIndexPath page], [toIndexPath page]);
  var findNextItemDirection = [fromIndexPath page] < [toIndexPath page] ? 1 : -1;
  // if we want to move page to later postion, then newPosition[i] = oldPosition[i + 1]
  //
  // old: from  i     j      k      to
  // new: i     j     k      to     from

  if (doublePage) {
    // FIXME: Assumes the pages in section is all paired.
    var fromLeft = [fromIndexPath page] & (~1);
    var fromRight = fromLeft + 1;
    leftIndex = leftIndex & (~1);
    rightIndex = rightIndex | 1;

    for (var idx = 0; idx < pages; idx += 2) {
      if (idx == [toIndexPath page] || idx + 1 == [toIndexPath page]) {
        newOrder[idx] = fromLeft;
        newOrder[idx + 1] = fromRight;
      } else if (idx < leftIndex || idx > rightIndex) {
        newOrder[idx] = idx;
        newOrder[idx + 1] = idx + 1;
      } else {
        newOrder[idx] = idx + 2 * findNextItemDirection;
        newOrder[idx + 1] = idx + 1 + 2 * findNextItemDirection;
      }
    }
  } else {
    for (var idx = 0; idx < pages; idx++) {
      if (idx == [toIndexPath page]) {
        newOrder[idx] = [fromIndexPath page];
      } else if (idx < leftIndex || idx > rightIndex) {
        newOrder[idx] = idx;
      } else if ([[views[idx] superview] pageType] == HYNonseperablePairPage) {
        newOrder[idx] = idx;
      } else {
        var copyFrom = idx + findNextItemDirection;
        for (; copyFrom >= leftIndex && copyFrom <= rightIndex && [[views[copyFrom] superview] pageType] == HYNonseperablePairPage;
              copyFrom += findNextItemDirection);
        newOrder[idx] = copyFrom;
      }
    }
  }
  return newOrder;
}

- (void) draggedView: (CPView)aView movedTo: (CGPoint)aPoint
{
  var fromIndexPath = [[_selectedView superview] indexPath];
  var toIndexPath = [self indexPathAtPoint: aPoint];

  var hoverView = [self viewAtPoint: aPoint];
  var doublePage = ([[_selectedView superview] pageType] == HYNonseperablePairPage);

  if (_droppingIndexPath && toIndexPath && [_droppingIndexPath compare: toIndexPath] == CPOrderedSame)
    return;

  if (!doublePage && [[hoverView superview] pageType] == HYNonseperablePairPage) return;
  if ([_delegate respondsToSelector: @selector(acceptsDropFromIndexPath:toIndexPath:)] &&
      ![_delegate acceptsDropFromIndexPath: fromIndexPath toIndexPath: toIndexPath]) return;

  _droppingIndexPath = toIndexPath;

  if (_droppingIndexPath == nil) return;

  // check if accept drop

  var highlightView = [_selectedView superview];
  if (doublePage) {
    [[_selectedView superview] superview]._DOMElement.style["border"] = "none";
    highlightView = [[hoverView superview] superview];
  }
  highlightView._DOMElement.style["border"] = "3px solid #3399ff";

  /* FIXME: precondition: fromIndexPath.section == toIndexPath.section */
  var newOrder = [CPMutableArray new];
  var staticPage = [CPMutableArray new];

  var section = [fromIndexPath section];
  var views = _viewsForSection[section];
  var newOrderIndexes = [self newOrderIndexesByMovingIndexPath: fromIndexPath toIndexPath: toIndexPath];

  for (var idx = 0; idx < [newOrderIndexes count]; idx++) {
    [newOrder addObject: views[newOrderIndexes[idx]]];
  }

  var containers = _containerViews.filter(function(view) {
    return [view section] == [fromIndexPath section];
  });

  var size = [_dataSource pageSize];

  for (var idx = 0; idx < [containers count]; idx++) {
    var container = containers[idx];
    if ([container leftView] != nil) {
      var v = newOrder.shift();
      [container setLeftView: [v superview]];
      [container addSubview: [v superview]];
    }
    if ([container rightView] != nil) {
      var v = newOrder.shift();
      [container setRightView: [v superview]];
      [container addSubview: [v superview]];
    }

    if ([container pageCount] == 1) {
      [[container leftView] setFrame: CGRectMake(0, 0, size.width, size.height)];
    } else if ([container pageCount] == 2) {
      [[container leftView] setFrame: CGRectMake(0, 0, size.width, size.height)];
      [[container rightView] setFrame: CGRectMake(size.width, 0, size.width, size.height)];
    }

  }

}

- (void) draggedView: (CPView)aView endedAt: (CGPoint)aLocation operation: (CPDragOperation)anOperation
{
  if (_droppingIndexPath != nil) {
    var doublePage = ([[_selectedView superview] pageType] == HYNonseperablePairPage);
    var previousHighlightView = [_selectedView superview];
    if (doublePage) previousHighlightView = [previousHighlightView superview];

    previousHighlightView._DOMElement.style["border"] = "none";
  }

  var opCode = "?"
  if (anOperation == CPDragOperationCopy)
    opCode = "copy";
  else if (anOperation == CPDragOperationDelete)
    opCode = "delete";
  else if (anOperation == CPDragOperationEvery)
    opCode = "every";
  else if (anOperation == CPDragOperationGeneric)
    opCode = "generic";
  else if (anOperation == CPDragOperationLink)
    opCode = "link";
  else if (anOperation == CPDragOperationMove)
    opCode = "move";
  else if (anOperation == CPDragOperationNone)
    opCode = "none";

  CPLog("end: " + anOperation + " (" + opCode + ")");
}

@end

@implementation SinglePageBackgroundView : CPView
{
  CPIndexPath _indexPath @accessors(property=indexPath);
  int _pageType @accessors(property=pageType);
}

- (id) init
{
  self = [super init];
  if (self) {
    _DOMElement.style["box-sizing"] = "border-box";
    [self setBackgroundColor: [CPColor whiteColor]];
  }
  return self;
}
@end

@implementation HYThumbnailPageContainerView : CPView
{
  int _section @accessors(property=section);
  CPView _leftView @accessors(property=leftView);
  CPView _rightView @accessors(property=rightView);
  int _slot @accessors(property=slot);
}

- (id) init
{
  self = [super init];
  if (self) {
    _DOMElement.style["box-sizing"] = "border-box";
  }
  return self;
}

- (void) removeViews
{
  [_leftView removeFromSuperView];
  [_rightView removeFromSuperView];
  _leftView = nil;
  _rightView = nil;
}

- (BOOL) addView: (CPView)aView
{
  if (_leftView && _rightView) return NO;

  if (_leftView == nil) {
    _leftView = aView;
    _rightView = nil;
  } else if (_rightView == nil) {
    _rightView = aView;
  }
  [self addSubview: aView];
  return YES;
}

- (int) pageCount
{
  var count = 0;
  if (_leftView != nil) count++;
  if (_rightView != nil) count++;
  return count;
}

- (BOOL) isEmpty
{
  return (_leftView == nil && _rightView == nil);
}


@end
