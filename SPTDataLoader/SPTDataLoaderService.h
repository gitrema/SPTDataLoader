#import <Foundation/Foundation.h>

@class SPTDataLoaderFactory;

/**
 * The service used for creating data loader factories and providing application wide rate limiting to services
 */
@interface SPTDataLoaderService : NSObject

/**
 * Class constructor
 * @param userAgent The user agent to report as when making HTTP requests
 */
+ (instancetype)dataLoaderServiceWithUserAgent:(NSString *)userAgent;

/**
 * Creates a data loader factory
 * @param authorisers An NSArray of SPTDataLoaderAuthoriser objects for supporting different forms of authorisation
 */
- (SPTDataLoaderFactory *)createDataLoaderFactoryWithAuthorisers:(NSArray *)authorisers;

@end
