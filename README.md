ThumbPagesView
==================

View class for double-page handling. Since there's a lot of dirty code, you must read this document carefully to use this class.

API
==================

Data Source must implement the protocol:
------------------

**`- (int) sectionCount`**

How many sections. Each section consists at least one row.

**`- (int) pageCountForSection: (int)sectionIndex`**

How many pages for a section.


**`- (CPSize) pageSize`**

The size of each single page.

**`- (CPView) viewForPageAtIndexPath: (CPIndexPath)indexPath`**

Returns the view for each page.

**`- (void) viewsDidRearrangedSection: (int)section newOrder: (CPArray)reorderIndex`**

Returns an array containing the new order of pages in section. For example: [0,2,1,3,4,5]. You need to update the order of data source so that it matches the new order.


Delegate Methods. Supports drag-n-drop.
------------------

**`- (int) pageTypeAtIndexPath: (CPIndexPath)indexPath`**

The type of each page. Could be:

* `HYSingularPage`: A single page.
* `HYSeperablePairPage`: One of a pair of pages that can move independently.
* `HYNonseperablePairPage`: One of a pair of pages that can only move together. For example: a cross page should be this type.


**`- (BOOL) isDraggablePageAtIndexPath: (CPIndexPath)indexPath`**

Return true if this page is draggable.

**`- (BOOL) acceptsDropFromIndexPath: (CPIndexPath)draggingIndexPath toIndexPath: (CPIndexPath)toIndexPath`**

Return true if the page come from draggingIndexPath can be drop to toIndexPath. Note that you have to return `false` if the draggingIndexPath.section != toIndexPath.section due to implementation bug.