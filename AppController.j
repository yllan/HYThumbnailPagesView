/*
 * AppController.j
 * NewApplication
 *
 * Created by You on November 16, 2011.
 * Copyright 2011, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "HYThumbnailPagesView.j"

@implementation AppController : CPObject
{
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{
    var theWindow = [[CPWindow alloc] initWithContentRect: CGRectMakeZero() styleMask: CPBorderlessBridgeWindowMask],
        contentView = [theWindow contentView];

    var pagesView = [[HYThumbnailPagesView alloc] initWithFrame: [contentView bounds]];

    [pagesView setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [pagesView setCenter: [contentView center]];
    [pagesView setBackgroundColor: [CPColor grayColor]];
    [pagesView setDelegate: self];
    [pagesView setDataSource: self];
    [pagesView reloadData];
    [contentView addSubview: pagesView];

    [theWindow orderFront: self];
    // [CPMenu setMenuBarVisible: YES];
}


- (int) sectionCount
{
  return 2;
}

- (int) pageCountForSection: (int)sectionIndex
{
  if (sectionIndex == 0)
    return 2;
  else if (sectionIndex == 1)
    return 38;
  else
    return 0;
}

- (CPSize) pageSize
{
  return CGSizeMake(120, 120);
}

- (CPView) viewForPageAtIndexPath: (CPIndexPath)indexPath
{
  var section = [indexPath section], page = [indexPath page];

  if (section == 0) {
    var title = "?";
    if (page == 0) title = "cover";
    else if (page == 1) title = "title";
    var label = [CPTextField labelWithTitle: title];
    return label;
  } else if (section == 1) {
    var title = page;
    if (page == 0 || page == 37) title = "blank";
    var label = [CPTextField labelWithTitle: title];
    return label;
  }
}

- (int) pageTypeAtIndexPath: (CPIndexPath)indexPath
{
  var section = [indexPath section], page = [indexPath page];
  if (section == 0) {
    return HYSingularPage;
  } else if (section == 1 && ((page % 6 == 0) || (page % 6 == 1)) && page > 2 && page < 36) {
    return HYNonseperablePairPage;
  } else {
    return HYSeperablePairPage;
  }
}

- (BOOL) isDraggablePageAtIndexPath: (CPIndexPath)indexPath
{
  var section = [indexPath section], page = [indexPath page];
  if (section == 0) return NO;
  if (section == 1 && page == 0) return NO;
  if (section == 1 && page == 37) return NO;
  return YES;
}

- (BOOL) acceptsDropFromIndexPath: (CPIndexPath)droppedIndexPath toIndexPath: (CPIndexPath)toIndexPath
{
  var section = [toIndexPath section], page = [toIndexPath page];

  if (section == 0) return NO;
  if (section == 1 && page == 0) return NO;
  if (section == 1 && page == 37) return NO;

  if ([self pageTypeAtIndexPath: droppedIndexPath] == HYNonseperablePairPage) {
    if (section == 1 && page <= 1) return NO;
    if (section == 1 && page >= 36) return NO;
  }

  return YES;
}

@end
