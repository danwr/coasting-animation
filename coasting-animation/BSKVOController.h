//
//  BSKVOController.h
//
//  Created by Dan Wright on 4/2/16.
//  Copyright © 2016 Dan Wright. All rights reserved.
//

#import <Foundation/Foundation.h>


@class BSMutableKVOController;

@interface BSKVOController : NSObject

@property (nonatomic, readonly, weak) NSObject *observedObject;

- (instancetype)initWithObservedObject:(NSObject *)object;
- (void)invalidate;

- (void)keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options queue:(dispatch_queue_t)queue addObserver:(void (^)(id object, NSDictionary *changes))block;
- (void)keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options addObserver:(void (^)(id object, NSDictionary *changes))block;
- (void)keyPaths:(NSArray<NSString *> *)keyPaths options:(NSKeyValueObservingOptions)options addObserver:(void (^)(id object, NSDictionary *changes))block;

- (BOOL)isObservingKeyPath:(NSString *)keyPath;
- (void)removeKeyPath:(NSString *)keyPath;

- (void)bind:(NSString *)fromKeyPath to:(NSString *)toKeyPath nilValue:(NSObject *)nilValue;

+ (instancetype)observe:(NSObject *)object;
- (instancetype)observe:(NSString *)keyPath;

@end


@interface BSMutableKVOController : BSKVOController
@property (nonatomic, weak) NSObject *observedObject;
@end

@interface NSObject (BSKVO)
- (BSKVOController *)keyPath:(NSString *)keyPath controllerForObserver:(void (^)(id object, NSDictionary *changes))block;
@end


/*
 _kvoSelf = [BSKVOController observe:self];
 _kvoPlayer = [_kvoSelf observe:@"player"];
 _kvoPlayerItem = [_kvoPlayer observe:@"currentItem"];
  
 [_kvoSelf keyPath:@"player" options:0 addObserver:^(id object, NSDictionary *changes) {
	NSLog(@"player changed to %@", [object player]);
 }];
 
 [_kvoPlayer keyPath:@"currentItem" options:NSKeyValueObservingOptionsInitial addObserver:^(id object, NSDictionary *changes) {
	NSLog(@"currentItem changed to %@", [object currentItem];
 }];

 [_kvoPlayerItem keyPath:@"duration" options:NSKeyValueObservingOptionsInitial addObserver:^(id object, NSDictionary *changes) {
	NSLog(@"duration is %f",CMTimeGetSeconds(!object ? kCMTimeInvalid : [object duration]));
 }];
 
*/


