//
//  CocoaAsyncSocketTest.m
//  iLiDAR
//
//  Created by Bo Liang on 2024/12/8.
//

#import "CocoaAsyncSocketHandler.h"
#import <GCDAsyncSocket.h>

@interface CocoaAsyncSocketHandler ()<GCDAsyncSocketDelegate>

@property (strong, nonatomic) GCDAsyncSocket *socket;
@property (strong, nonatomic) NSMutableData *incomingBuffer;
@property (assign, nonatomic) BOOL isConnecting;

@end

@implementation CocoaAsyncSocketHandler

- (instancetype) init {
    self = [super init];
    if (self) {
        _incomingBuffer = [NSMutableData data];
        _isConnecting = NO;
    }
    return self;
}

- (void)setupSocketHost:(NSString *)host port:(NSInteger)port {
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    
    self.isConnecting = YES;
    
    BOOL started = [self.socket connectToHost:host onPort:(uint16_t)port error:&error];
    if (!started || error) {
        NSLog(@"Fail to connect: %@", error.localizedDescription);
        self.isConnecting = NO;
        if (self.connectionCallback) {
            self.connectionCallback(NO); // link failed
        }
    }
}

- (void)sendMyData:(NSData *)data {
    if (self.socket.isConnected) {
        [self.socket writeData:data withTimeout:-1 tag:0];
    } else {
        NSLog(@"Socker is not connected. Uable to send data.");
    }
}

- (void)disconnect {
    if (self.socket) {
        [self.socket disconnect];
        NSLog(@"Socket disconnected by user.");
    }
}

#pragma mark - GCDAsyncSocketDelegate Methods

// Delegate method: Connection successful
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"Successfully connected %@:%d", host, port);
    self.isConnecting = NO;
    [self.socket readDataWithTimeout:-1 tag:0];
    if (self.connectionCallback) {
        self.connectionCallback(YES);
    }
}

// Delegate method: Data received (optional, can be used for simple acknowledgments)
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"Received response: %@", response);
    
    if (self.getResponseBlock){
        self.getResponseBlock(response);
    }
    
    // Continue reading if expecting more responses
    [self.socket readDataWithTimeout:-1 tag:0];
}

// Delegate method: Connection disconnected
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (err) {
        NSLog(@"Socket disconnected with error: %@", err.localizedDescription);
        if (self.isConnecting && self.connectionCallback) {
            self.connectionCallback(NO);
        }
    } else {
        NSLog(@"Socket disconnected successfully.");
    }
    
    self.isConnecting = NO;
    
    // Optionally, notify about disconnection
    if (self.getResponseBlock) {
        self.getResponseBlock(@"Disconnected from server.");
    }
}

@end
