//
//  CocoaAsyncSocketTest.h
//  iLiDAR
//
//  Created by Bo Liang on 2024/12/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ResponseBlock)(NSString *response);

@interface CocoaAsyncSocketHandler : NSObject

@property (nonatomic, copy) ResponseBlock getResponseBlock;

// Setup connection with host and port
- (void)setupSocketHost:(NSString *)host port:(NSInteger)port;

// Send binary data
- (void)sendMyData:(NSData *)data;

// Disconnect the socket
- (void)disconnect;

@end

NS_ASSUME_NONNULL_END
