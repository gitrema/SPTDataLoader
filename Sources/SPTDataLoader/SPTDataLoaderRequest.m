/*
 Copyright Spotify AB.
 SPDX-License-Identifier: Apache-2.0
 */

#import <SPTDataLoader/SPTDataLoaderRequest.h>

#import "SPTDataLoaderRequest+Private.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const SPTDataLoaderRequestErrorDomain = @"com.spotify.dataloader.request";

static NSString * NSStringFromSPTDataLoaderRequestMethod(SPTDataLoaderRequestMethod requestMethod);

@interface SPTDataLoaderRequest ()

@property (nonatomic, assign, readwrite) int64_t uniqueIdentifier;

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *mutableHeaders;
@property (nonatomic, assign) BOOL retriedAuthorisation;
@property (nonatomic, weak) id<SPTDataLoaderCancellationToken> cancellationToken;

@end

@implementation SPTDataLoaderRequest

#pragma mark SPTDataLoaderRequest

+ (instancetype)requestWithURL:(NSURL *)URL sourceIdentifier:(nullable NSString *)sourceIdentifier
{
    static int64_t uniqueIdentifierBarrier = 0;
    @synchronized(self.class) {
        return [[self alloc] initWithURL:URL
                        sourceIdentifier:sourceIdentifier
                        uniqueIdentifier:uniqueIdentifierBarrier++];
    }
}

- (instancetype)initWithURL:(NSURL *)URL
           sourceIdentifier:(nullable NSString *)sourceIdentifier
           uniqueIdentifier:(int64_t)uniqueIdentifier
{
    self = [super init];
    if (self) {
        _URL = URL;
        _sourceIdentifier = sourceIdentifier;
        _uniqueIdentifier = uniqueIdentifier;

        _mutableHeaders = [NSMutableDictionary new];
        _method = SPTDataLoaderRequestMethodGet;
    }

    return self;
}

- (NSDictionary *)headers
{
    @synchronized(self.mutableHeaders) {
        return [self.mutableHeaders copy];
    }
}

- (void)addValue:(NSString *)value forHeader:(NSString *)header
{
    if (!header) {
        return;
    }

    @synchronized(self.mutableHeaders) {
        if (!value && header) {
            [self.mutableHeaders removeObjectForKey:header];
            return;
        }

        self.mutableHeaders[header] = value;
    }
}

- (void)removeHeader:(NSString *)header
{
    @synchronized(self.mutableHeaders) {
        [self.mutableHeaders removeObjectForKey:header];
    }
}

#pragma mark Private

- (NSURLRequest *)urlRequest
{
    NSString * const SPTDataLoaderRequestContentLengthHeader = @"Content-Length";
    NSString * const SPTDataLoaderRequestAcceptLanguageHeader = @"Accept-Language";

    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:self.URL];

    if (!self.headers[SPTDataLoaderRequestAcceptLanguageHeader]) {
        [urlRequest addValue:[self.class languageHeaderValue]
          forHTTPHeaderField:SPTDataLoaderRequestAcceptLanguageHeader];
    }

    if (self.bodyStream != nil) {
        urlRequest.HTTPBodyStream = self.bodyStream;
    } else if (self.body) {
        [urlRequest addValue:@(self.body.length).stringValue forHTTPHeaderField:SPTDataLoaderRequestContentLengthHeader];
        urlRequest.HTTPBody = self.body;
    }

    NSDictionary *headers = self.headers;
    for (NSString *key in headers) {
        NSString *value = headers[key];
        [urlRequest addValue:value forHTTPHeaderField:key];
    }

    urlRequest.cachePolicy = self.cachePolicy;
    urlRequest.HTTPMethod = NSStringFromSPTDataLoaderRequestMethod(self.method);

    return urlRequest;
}

+ (NSString *)languageHeaderValue
{
    static NSString * languageHeaderValue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        languageHeaderValue = [self generateLanguageHeaderValue];
    });
    return languageHeaderValue;
}

+ (NSString *)generateLanguageHeaderValue
{
    NSString * const SPTDataLoaderRequestLanguageHeaderValuesJoiner = @", ";

    NSString *(^constructLanguageHeaderValue)(NSString *, double) = ^NSString *(NSString *language, double languageImportance) {
        NSString * const SPTDataLoaderRequestLanguageFormatString = @"%@;q=%.2f";
        return [NSString stringWithFormat:SPTDataLoaderRequestLanguageFormatString, language, languageImportance];
    };

    NSArray<NSString *> *languages = [NSLocale preferredLanguages];

    NSMutableArray *languageHeaderValues = [NSMutableArray arrayWithCapacity:languages.count];

    [languages enumerateObjectsUsingBlock:^(NSString *language, NSUInteger idx, BOOL *stop) {
        const double languageImportance = 1.0 - idx * (1.0 / languages.count);
        [languageHeaderValues addObject:constructLanguageHeaderValue(language, languageImportance)];
    }];

    return [languageHeaderValues componentsJoinedByString:SPTDataLoaderRequestLanguageHeaderValuesJoiner];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p URL = \"%@\">", self.class, (void *)self, self.URL];
}

#pragma mark NSCopying

- (id)copyWithZone:(nullable NSZone *)zone
{
    __typeof(self) copy = [[self.class alloc] initWithURL:self.URL
                                         sourceIdentifier:self.sourceIdentifier
                                         uniqueIdentifier:self.uniqueIdentifier];
    copy.waitsForConnectivity = self.waitsForConnectivity;
    copy.maximumRetryCount = self.maximumRetryCount;
    copy.body = [self.body copy];
    @synchronized(self.mutableHeaders) {
        copy.mutableHeaders = [self.mutableHeaders mutableCopy];
    }
    copy.chunks = self.chunks;
    copy.cachePolicy = self.cachePolicy;
    copy.skipNSURLCache = self.skipNSURLCache;
    copy.method = self.method;
    copy.backgroundPolicy = self.backgroundPolicy;
    copy.userInfo = self.userInfo;
    copy.timeout = self.timeout;
    copy.cancellationToken = self.cancellationToken;
    copy.bodyStream = self.bodyStream;
    copy.shouldStopRedirection = self.shouldStopRedirection;
    return copy;
}

@end

static NSString * const SPTDataLoaderRequestDeleteMethodString = @"DELETE";
static NSString * const SPTDataLoaderRequestGetMethodString = @"GET";
static NSString * const SPTDataLoaderRequestPatchMethodString = @"PATCH";
static NSString * const SPTDataLoaderRequestPostMethodString = @"POST";
static NSString * const SPTDataLoaderRequestPutMethodString = @"PUT";
static NSString * const SPTDataLoaderRequestHeadMethodString = @"HEAD";

static NSString * NSStringFromSPTDataLoaderRequestMethod(SPTDataLoaderRequestMethod requestMethod)
{
    switch (requestMethod) {
        case SPTDataLoaderRequestMethodDelete: return SPTDataLoaderRequestDeleteMethodString;
        case SPTDataLoaderRequestMethodGet: return SPTDataLoaderRequestGetMethodString;
        case SPTDataLoaderRequestMethodPatch: return SPTDataLoaderRequestPatchMethodString;
        case SPTDataLoaderRequestMethodPost: return SPTDataLoaderRequestPostMethodString;
        case SPTDataLoaderRequestMethodPut: return SPTDataLoaderRequestPutMethodString;
        case SPTDataLoaderRequestMethodHead: return SPTDataLoaderRequestHeadMethodString;
    }
}

NS_ASSUME_NONNULL_END
