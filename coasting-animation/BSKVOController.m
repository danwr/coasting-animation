//
//  BSKVOController.m
//  coasting-animation
//
//  Created by Dan Wright on 4/2/16.
//  Copyright © 2016 Dan Wright. All rights reserved.
//
//	Key-Value-Observation controller. Typical usage:
//
//		_kvoController = [[BSKVOController alloc] initWithObservedObject:self];
//
//		[_kvoController keyPath:@"playerController" options:0 addObserver:^(id object, NSDictionary *changes) {
//			__typeof(self) _self = object;
//			[_self didChangePlayerController];
//		}];
//
//		[_kvoController bind:@"playerController.player.currentItem.duration" to:@"transportBar.duration" nilValue:[NSValue valueWithCMTime:kCMTimeInvalid]];
//

#import "BSKVOController.h"

typedef void (^BSKVOBlock)(id /* observedObject */, NSDictionary * /* KVO changes */);

@interface _BSKVObservation : NSObject
@property (nonatomic, copy) BSKVOBlock block;
@property (nonatomic) NSKeyValueObservingOptions options;
@end

@implementation _BSKVObservation
@end

@interface BSKVOController ()
@property (nonatomic, weak, setter = _setObservedObject:) NSObject *observedObject;
@property (nonatomic) NSMutableDictionary<NSString *, _BSKVObservation *> *observations;
@property (nonatomic) NSMutableDictionary<NSString *, BSMutableKVOController *> *boundControllers;
@end

static void *BSKVOControllerKeyValueObserverContext = &BSKVOControllerKeyValueObserverContext;
static void *BSKVOControllerKeyValueObserverBoundControllerContext = &BSKVOControllerKeyValueObserverBoundControllerContext;

@implementation BSKVOController

- (instancetype)initWithObservedObject:(NSObject *)object
{
	if (self = [super init]) {
		_observedObject = object;
		_observations = [NSMutableDictionary dictionary];
		_boundControllers = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)dealloc
{
	[self invalidate];
}

- (void)invalidateBoundControllers
{
	for (NSString *keyPath in self.boundControllers.allKeys) {
		[self removeObserver:self forKeyPath:keyPath context:BSKVOControllerKeyValueObserverBoundControllerContext];
	}
	[self.boundControllers removeAllObjects];
}

- (void)invalidate
{
	for (NSString *keyPath in self.observations.allKeys) {
		[self removeKeyPath:keyPath];
	}
	[self invalidateBoundControllers];
}

- (void)keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options queue:(dispatch_queue_t)queue addObserver:(void (^)(id object, NSDictionary *changes))block
{
	assert(![self isObservingKeyPath:keyPath]);
	_BSKVObservation *observation = self.observations[keyPath] ?: [[_BSKVObservation alloc] init];
	
	if (queue) {
		BSKVOBlock originalBlock = [block copy];
		block = ^(id object, NSDictionary *changes) {
			__weak id weakObject = object;
			dispatch_async(queue, ^{
				id object = weakObject;
				originalBlock(object, changes);
			});
		};
	}
	[observation setBlock:block];
	[observation setOptions:options];
	self.observations[keyPath] = observation;
	[self.observedObject addObserver:self forKeyPath:keyPath options:options context:BSKVOControllerKeyValueObserverContext];
}

- (void)keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options addObserver:(void (^)(id object, NSDictionary *changes))block
{
	[self keyPath:keyPath options:options queue:dispatch_get_main_queue() addObserver:block];
}

- (void)keyPaths:(NSArray<NSString *> *)keyPaths options:(NSKeyValueObservingOptions)options addObserver:(void (^)(id object, NSDictionary *changes))block
{
	block = [block copy];
	for (NSString *keyPath in keyPaths) {
		[self keyPath:keyPath options:options addObserver:block];
	}
}

- (void)bind:(NSString *)fromKeyPath to:(NSString *)toKeyPath nilValue:(NSObject *)nilValue
{
	fromKeyPath = [fromKeyPath copy];
	toKeyPath = [toKeyPath copy];
	[self keyPath:fromKeyPath options:NSKeyValueObservingOptionInitial addObserver:^(id object, NSDictionary *changes) {
		NSObject *value = [object valueForKeyPath:fromKeyPath] ?: nilValue;
		[object setValue:value forKeyPath:toKeyPath];
	}];
}

- (BOOL)isObservingKeyPath:(NSString *)keyPath
{
	return self.observations[keyPath] != nil;
}

- (void)removeKeyPath:(NSString *)keyPath
{
	if (!self.observations[keyPath]) {
		return;
	}
	[self.observedObject removeObserver:self forKeyPath:keyPath context:BSKVOControllerKeyValueObserverContext];
	[self.observations removeObjectForKey:keyPath];
}

- (void)bindKeyPath:(NSString *)keyPath toController:(BSMutableKVOController *)controller
{
	// this isn't quite right, because keyPath:options:addObserver: doesn't allow us to add multiple observers for the same keyPath,
	// which means either we, or the client, can observer keyPath, but not both. We either want a separate BSKVOController under the covers,
	// or an internal set.
	keyPath = [keyPath copy];
	self.boundControllers[keyPath] = controller;
	[self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionInitial context:BSKVOControllerKeyValueObserverBoundControllerContext];
}

+ (instancetype)observe:(NSObject *)object
{
	return [[self alloc] initWithObservedObject:object];
}

- (instancetype)observe:(NSString *)keyPath
{
	BSMutableKVOController *controller = [[BSMutableKVOController alloc] initWithObservedObject:nil];
	[self bindKeyPath:keyPath toController:controller];
	return controller;
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
	if (context == BSKVOControllerKeyValueObserverContext) {
		BSKVOBlock block = [self.observations[keyPath] block];
		if (block) {
			block(object, change);
		}
	} else if (context == BSKVOControllerKeyValueObserverBoundControllerContext) {
		// Note: We might want to do dispatch_async(main) here.
		BSMutableKVOController *controller = self.boundControllers[keyPath];
		NSObject *value = [object valueForKeyPath:keyPath];
		[controller setObservedObject:value];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

@end

#pragma mark -

@interface BSMutableKVOController ()
@end

@implementation BSMutableKVOController

@dynamic observedObject;

- (void)setObservedObject:(NSObject *)observedObject
{
	NSObject *oldObject = [super observedObject];
	if (oldObject != observedObject) {
		for (NSString *keyPath in self.observations.allKeys) {
			[oldObject removeObserver:self forKeyPath:keyPath context:BSKVOControllerKeyValueObserverContext];
		}
		for (NSString *keyPath in self.boundControllers.allKeys) {
			[oldObject removeObserver:self forKeyPath:keyPath context:BSKVOControllerKeyValueObserverBoundControllerContext];
		}
		[super _setObservedObject:observedObject];
		for (NSString *keyPath in self.boundControllers.allKeys) {
			[oldObject addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionInitial context:BSKVOControllerKeyValueObserverBoundControllerContext];
		}
		for (NSString *keyPath in self.observations.allKeys) {
			NSKeyValueObservingOptions options = [self.observations[keyPath] options];
			[observedObject addObserver:self forKeyPath:keyPath options:(NSKeyValueObservingOptionInitial | options) context:BSKVOControllerKeyValueObserverContext];
		}
	}
}
@end

#pragma mark -

@implementation NSObject (BSKVO)
- (BSKVOController *)keyPath:(NSString *)keyPath controllerForObserver:(void (^)(id object, NSDictionary *changes))block
{
	BSKVOController *controller = [[BSKVOController alloc] initWithObservedObject:self];
	[controller keyPath:keyPath options:NSKeyValueObservingOptionInitial addObserver:block];
	return controller;
}
@end
