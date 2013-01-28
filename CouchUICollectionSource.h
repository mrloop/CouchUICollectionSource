//
//  CouchUICollectionSource.h
//
//  Based on CouchUITableSource
//  CouchCocoa
//
//  Created by Ewan Mcdougall on 21/01/2013.
//  Copyright (c) 2013 Ewan Mcdougall. All rights reserved.
//
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.



#import <UIKit/UIKit.h>
@class CouchDocument, CouchLiveQuery, CouchQueryRow, RESTOperation;

@interface CouchUICollectionSource : NSObject <UICollectionViewDataSource>

@property (nonatomic, retain) IBOutlet UICollectionView* collectionView;

@property (retain) CouchLiveQuery* query;
@property (retain) NSMutableArray* rows;

/** Rebuilds the table from the query's current .rows property. */
-(void) reloadFromQuery;

#pragma mark Row Accessors:

/** Convenience accessor to get the row object for a given table row index. */
- (CouchQueryRow*) rowAtIndex: (NSUInteger)index;

/** Convenience accessor to find the index path of the row with a given document. */
- (NSIndexPath*) indexPathForDocument: (CouchDocument*)document;

/** Convenience accessor to return the document at a given index path. */
- (CouchDocument*) documentAtIndexPath: (NSIndexPath*)path;


#pragma mark Editing The Table:

/** Asynchronously deletes the documents at the given row indexes, animating the removal from the table. */
- (void) deleteDocumentsAtIndexes: (NSArray*)indexPaths;

/** Asynchronously deletes the given documents, animating the removal from the table. */
- (void) deleteDocuments: (NSArray*)documents;

@end

#pragma mark CouchUICollectionDelegate:

/** Additional methods for the table view's delegate, that will be invoked by the CouchUITableSource. */
@protocol CouchUICollectionDelegate <UICollectionViewDelegate>
@optional

/** Allows delegate to return its own custom cell, just like -tableView:cellForRowAtIndexPath:.
    If this returns nil the table source will create its own cell, as if this method were not implemented. */
- (UICollectionViewCell *)couchCollectionSource:(CouchUICollectionSource*)source
                cellForRowAtIndexPath:(NSIndexPath *)indexPath;

/** Called after the query's results change, before the table view is reloaded. */
- (void)couchCollectionSource:(CouchUICollectionSource*)source
     willUpdateFromQuery:(CouchLiveQuery*)query;

/** Called after the query's results change to update the table view. If this method is not implemented by the delegate, reloadData is called on the table view.*/
- (void)couchCollectionSource:(CouchUICollectionSource*)source
         updateFromQuery:(CouchLiveQuery*)query
            previousRows:(NSArray *)previousRows;

/** Called from -tableView:cellForRowAtIndexPath: just before it returns, giving the delegate a chance to customize the new cell. */
- (void)couchCollectionSource:(CouchUICollectionSource*)source
             willUseCell:(UICollectionViewCell*)cell
                  forRow:(CouchQueryRow*)row;

/** Called if a CouchDB operation invoked by the source (e.g. deleting a document) fails. */
- (void)couchTableSource:(CouchUICollectionSource*)source
         operationFailed:(RESTOperation*)op;

@end
