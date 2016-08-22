//
//  BSDAGNode.h
//  coasting-animation
//
//  Created by Dan Wright on 4/19/16.
//  Copyright © 2016 Dan Wright. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BSDAGNode : NSObject
@property (nonatomic, readonly, weak) id object;
@property (nonatomic, readonly, copy) NSSet<BSDAGNode *> *targetNodes;

- (instancetype)initWithObject:(id)object;
- (instancetype)initWithObject:(id)object targetNodes:(NSSet<BSDAGNode *> *)targetNodes;

- (void)addTargetNode:(BSDAGNode *)node;
- (void)removeTargetNode:(BSDAGNode *)node;
- (void)removeAllTargetNodes;

- (NSSet<BSDAGNode *> *)connectedNodes;

@end

@interface BSDAG : NSObject
@property (nonatomic, readonly) NSSet<BSDAGNode *> *nodes;
- (instancetype)initWithNodes:(NSSet<BSDAGNode *> *)nodes;
- (instancetype)initWithNode:(BSDAGNode *)node;
@end

@interface BSDAGStrongConnectedComponent : NSObject
@property (nonatomic, readonly) NSArray<BSDAGNode *> *nodes;
@end


@interface BSDAG (Cycles)
- (NSArray<BSDAGStrongConnectedComponent *> *)findStronglyConnectedComponents;
@end
