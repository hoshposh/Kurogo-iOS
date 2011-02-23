#import "MapBookmarkManager.h"
#import "CoreDataManager.h"

@interface MapBookmarkManager (Private)

- (KGOPlacemark *)savedAnnotationWithAnnotation:(ArcGISMapAnnotation *)annotation;
- (void)refreshBookmarks;

@end



static MapBookmarkManager* s_mapBookmarksManager = nil;

@implementation MapBookmarkManager
@synthesize bookmarks = _bookmarks;

#pragma mark Creation and initialization

+ (MapBookmarkManager*)defaultManager
{
	if (nil == s_mapBookmarksManager) {
		s_mapBookmarksManager = [[MapBookmarkManager alloc] init];
	}
	return s_mapBookmarksManager;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self refreshBookmarks];
	}
	
	return self;
}

- (void)dealloc
{
	[_bookmarks release];
	[super dealloc];
}

- (void)refreshBookmarks {
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"isBookmark == YES"];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"sortOrder" ascending:YES];
    self.bookmarks = [[[CoreDataManager sharedManager] objectsForEntity:CampusMapAnnotationEntityName
                                                      matchingPredicate:pred
                                                        sortDescriptors:[NSArray arrayWithObject:sort]] mutableCopy];
}

- (void)pruneNonBookmarks {
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"isBookmark == NO"];
    NSArray *nonBookmarks = [[CoreDataManager sharedManager] objectsForEntity:CampusMapAnnotationEntityName
                                                            matchingPredicate:pred];
    for (KGOPlacemark *nonBookmark in nonBookmarks) {
        [[CoreDataManager sharedManager] deleteObject:nonBookmark];
    }
}

#pragma mark Bookmark Management

- (KGOPlacemark *)savedAnnotationForID:(NSString *)uniqueID {
    KGOPlacemark *saved = (KGOPlacemark *)[[CoreDataManager sharedManager] getObjectForEntity:CampusMapAnnotationEntityName
                                                                                                attribute:@"id"
                                                                                                    value:uniqueID];
    return saved;
}

- (KGOPlacemark *)savedAnnotationWithAnnotation:(ArcGISMapAnnotation *)annotation {
    KGOPlacemark *savedAnnotation = [[CoreDataManager sharedManager] insertNewObjectForEntityForName:CampusMapAnnotationEntityName];
    
    savedAnnotation.identifier = annotation.uniqueID;
    savedAnnotation.latitude = [NSNumber numberWithFloat:annotation.coordinate.latitude];
    savedAnnotation.longitude = [NSNumber numberWithFloat:annotation.coordinate.longitude];
    if (annotation.name) savedAnnotation.title = annotation.name;
    if (annotation.street) savedAnnotation.street = annotation.street;
    if (annotation.dataPopulated) {
        savedAnnotation.info = [NSKeyedArchiver archivedDataWithRootObject:annotation.info];
    }
    
    return savedAnnotation;
}

- (void)bookmarkAnnotation:(ArcGISMapAnnotation *)annotation {
    KGOPlacemark *savedAnnotation = [self savedAnnotationWithAnnotation:annotation];
    savedAnnotation.bookmarked = [NSNumber numberWithBool:YES];
    savedAnnotation.sortOrder = [NSNumber numberWithInt:[_bookmarks count]];
    [_bookmarks addObject:savedAnnotation];
    [[CoreDataManager sharedManager] saveData];
    [self refreshBookmarks];
}

- (void)saveAnnotationWithoutBookmarking:(ArcGISMapAnnotation *)annotation {
    KGOPlacemark *savedAnnotation = [self savedAnnotationWithAnnotation:annotation];
    savedAnnotation.bookmarked = [NSNumber numberWithBool:NO];
    [[CoreDataManager sharedManager] saveData];
}

- (void)removeBookmark:(KGOPlacemark *)savedAnnotation {
    NSInteger sortOrder = [savedAnnotation.sortOrder integerValue];
    // decrement sortOrder of all bookmarks after this
    for (NSInteger i = sortOrder + 1; i < [_bookmarks count]; i++) {
        KGOPlacemark *savedAnnotation = [_bookmarks objectAtIndex:i];
        savedAnnotation.sortOrder = [NSNumber numberWithInt:i - 1];
    }
    [_bookmarks removeObject:savedAnnotation];
    [[CoreDataManager sharedManager] deleteObject:savedAnnotation];
    [[CoreDataManager sharedManager] saveData];
}

- (BOOL)isBookmarked:(NSString *)uniqueID {
    KGOPlacemark *saved = [self savedAnnotationForID:uniqueID];
    return (saved != nil && [saved.bookmarked boolValue]);
}

- (void)moveBookmarkFromRow:(int) from toRow:(int)to
{
    if (to != from) {
		KGOPlacemark *savedAnnotation = nil;

        // if the row is moving down (from < to), the sortOrder of the
        // moved item increases and everything between decreases by 1
        NSInteger startIndex = (from < to) ? from + 1 : to;
        NSInteger endIndex = (from < to) ? to + 1 : from;
        NSInteger sortOrderDiff = (from < to) ? -1 : 1;
        
        for (NSInteger i = startIndex; i < endIndex; i++) {
            savedAnnotation = [self.bookmarks objectAtIndex:i];
            savedAnnotation.sortOrder = [NSNumber numberWithInt:i + sortOrderDiff];
        }

        savedAnnotation = [self.bookmarks objectAtIndex:from];
        savedAnnotation.sortOrder = [NSNumber numberWithInt:to];
        
        [[CoreDataManager sharedManager] saveData];
    }
}

@end
