//
//  CouchUICollectionSource.m
//
//  Based on CouchUITableSource https://github.com/couchbaselabs/CouchCocoa/blob/master/UI/iOS/CouchUITableSource.h
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

#import "CouchUICollectionSource.h"
#import <CouchCocoa/CouchCocoa.h>

@interface NSArray (RESTExtensions)
- (NSArray*) rest_map: (id (^)(id obj))block;
@end

@implementation NSArray (RESTExtensions)

- (NSArray*) rest_map: (id (^)(id obj))block {
  NSMutableArray* mapped = [[NSMutableArray alloc] initWithCapacity: self.count];
  for (id obj in self) {
    obj = block(obj);
    if (obj)
      [mapped addObject: obj];
  }
  NSArray* result = [[mapped copy] autorelease];
  [mapped release];
  return result;
}

@end

@interface CouchUICollectionSource ()
{
  @private
  UICollectionView* _collectionView;
  CouchLiveQuery* _query;
	NSMutableArray* _rows;
  BOOL _deletionAllowed;
}
@end


@implementation CouchUICollectionSource

- (id)init {
    self = [super init];
    if (self) {
        _deletionAllowed = YES;
    }
    return self;
}

- (void)dealloc {
  [_rows release];
  [_query removeObserver: self forKeyPath: @"rows"];
  [_query release];
  [super dealloc];
}

#pragma mark -
#pragma mark ACCESSORS:

@synthesize collectionView=_collectionView;
@synthesize rows=_rows;


- (CouchQueryRow*) rowAtIndex: (NSUInteger)index {
  return [_rows objectAtIndex: index];
}

- (NSIndexPath*) indexPathForDocument: (CouchDocument*)document {
    NSString* documentID = document.documentID;
    NSUInteger index = 0;
    for (CouchQueryRow* row in _rows) {
        if ([row.documentID isEqualToString: documentID])
            return [NSIndexPath indexPathForRow: index inSection: 0];
        ++index;
    }
    return nil;
}


- (CouchDocument*) documentAtIndexPath: (NSIndexPath*)path {
    if (path.section == 0)
        return [[_rows objectAtIndex: path.row] document];
    return nil;
}


- (id) tellDelegate: (SEL)selector withObject: (id)object {
  id delegate = _collectionView.delegate;
  if ([delegate respondsToSelector: selector]){
        return [delegate performSelector: selector withObject: self withObject: object];
  }
  return nil;
}


#pragma mark -
#pragma mark QUERY HANDLING:


- (CouchLiveQuery*) query {
    return _query;
}

- (void) setQuery:(CouchLiveQuery *)query {
    if (query != _query) {
        [_query removeObserver: self forKeyPath: @"rows"];
        [_query autorelease];
        _query = [query retain];
        [_query addObserver: self forKeyPath: @"rows" options: 0 context: NULL];
        [self reloadFromQuery];
    }
}


-(void) reloadFromQuery {
    CouchQueryEnumerator* rowEnum = _query.rows;
    if (rowEnum) {
        NSArray *oldRows = [_rows retain];
        [_rows release];
        _rows = [rowEnum.allObjects mutableCopy];
        [self tellDelegate: @selector(couchCollectionSource:willUpdateFromQuery:) withObject: _query];

        id delegate = _collectionView.delegate;
        SEL selector = @selector(couchTableSource:updateFromQuery:previousRows:);
        if ([delegate respondsToSelector: selector]) {
            [delegate couchCollectionSource: self 
                       updateFromQuery: _query
                          previousRows: oldRows];
        } else {
            [self.collectionView reloadData];
        }
        [oldRows release];
    }
}


- (void) observeValueForKeyPath: (NSString*)keyPath ofObject: (id)object
                         change: (NSDictionary*)change context: (void*)context 
{
    if (object == _query)
        [self reloadFromQuery];
}


#pragma mark -
#pragma mark DATA SOURCE PROTOCOL:


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _rows.count;
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
         cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Allow the delegate to create its own cell:
    UICollectionViewCell* cell = [self tellDelegate: @selector(couchCollectionSource:cellForRowAtIndexPath:)
                                    withObject: indexPath];
    if (!cell) {
       // ...if it doesn't, create a cell for it:
      cell = [collectionView dequeueReusableCellWithReuseIdentifier: @"CouchUICollectionCell" forIndexPath:indexPath];
      if(!cell){
        cell = [[UICollectionViewCell alloc] init];
      }
      CouchQueryRow* row = [self rowAtIndex: indexPath.row];

      // Allow the delegate to customize the cell:
      id delegate = _collectionView.delegate;
      if ([delegate respondsToSelector: @selector(couchCollectionSource:willUseCell:forRow:)]){
        [(id<CouchUICollectionDelegate>)delegate couchCollectionSource: self willUseCell: cell forRow: row];
      }
    }
    return cell;
}


#pragma mark -
#pragma mark EDITING:


- (void) checkDelete: (RESTOperation*)op {
    if (!op.isSuccessful) {
        // If the delete failed, undo the table row deletion by reloading from the db:
        [self tellDelegate: @selector(couchTableSource:operationFailed:) withObject: op];
        [self reloadFromQuery];
    }
}


- (void) deleteDocuments: (NSArray*)documents atIndexes: (NSArray*)indexPaths {
    RESTOperation* op = [_query.database deleteDocuments: documents];
    [op onCompletion: ^{ [self checkDelete: op]; }];

    NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];
    for (NSIndexPath* path in indexPaths) {
        if (path.section == 0)
            [indexSet addIndex: path.row];
    }
    [_rows removeObjectsAtIndexes: indexSet];
    // [_tableView deleteRowsAtIndexPaths: indexPaths withRowAnimation: UITableViewRowAnimationFade];
}


- (void) deleteDocumentsAtIndexes: (NSArray*)indexPaths {
    NSArray* docs = [indexPaths rest_map: ^(id path) {return [self documentAtIndexPath: path];}];
    [self deleteDocuments: docs atIndexes: indexPaths];
}


- (void) deleteDocuments: (NSArray*)documents {
    NSArray* paths = [documents rest_map: ^(id doc) {return [self indexPathForDocument: doc];}];
    [self deleteDocuments: documents atIndexes: paths];
}


@end
