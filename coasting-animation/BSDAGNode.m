//
//  BSDAGNode.m
//  coasting-animation
//
//  Created by Dan Wright on 4/19/16.
//  Copyright © 2016 Dan Wright. All rights reserved.
//

#import "BSDAGNode.h"

@implementation BSDAG
- (instancetype)initWithNodes:(NSSet<BSDAGNode *> *)nodes
{
    if (self = [super init]) {
        _nodes = [nodes copy] ?: [NSSet set];
    }
    return self;
}

- (instancetype)initWithNode:(BSDAGNode *)node
{
    return [self initWithNodes:[node connectedNodes]];
}

@end


@interface BSDAGNode ()
@property (nonatomic) NSUInteger index;
@property (nonatomic) NSUInteger lowLink;
@property (nonatomic, getter = isOnStack) BOOL onStack;
@end

@implementation BSDAGNode
{
    NSMutableSet<BSDAGNode *> *_targetNodes;
}

- (instancetype)initWithObject:(id)object targetNodes:(NSSet<BSDAGNode *> *)targetNodes
{
    if (self = [super init]) {
        _object = object;
        _targetNodes = [targetNodes mutableCopy] ?: [NSMutableSet set];
        _lowLink = NSNotFound;
    }
    return self;
}

- (instancetype)initWithObject:(id)object
{
    return [self initWithObject:object targetNodes:nil];
}

- (instancetype)init
{
    return [self initWithObject:nil];
}

- (instancetype)initWithNode:(BSDAGNode *)node
{
    return [self initWithObject:node.object targetNodes:node.targetNodes];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithNode:self];
}

- (BOOL)isEqualToNode:(BSDAGNode *)node
{
    if (self == node) {
        return YES;
    }
    if (!node) {
        return NO;
    }
    return (self.object == node.object && [self.targetNodes isEqualToSet:node.targetNodes]);
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    return [self isEqualToNode:object];
}

- (NSSet<BSDAGNode *> *)targetNodes
{
    return [_targetNodes copy];
}

- (void)addTargetNode:(BSDAGNode *)node
{
    [_targetNodes addObject:node];
}

- (void)removeTargetNode:(BSDAGNode *)node
{
    [_targetNodes removeObject:node];
}

- (void)removeAllTargetNodes
{
    [_targetNodes removeAllObjects];
}

#pragma mark -

- (NSSet<BSDAGNode *> *)connectedNodes
{
    NSMutableSet<BSDAGNode *> *set = [NSMutableSet set];
    NSMutableArray<BSDAGNode *> *stack = [NSMutableArray arrayWithObject:self];
    NSLog(@"-[BSDAGNode allConnectedNodes] starting with <%@ %p>", NSStringFromClass([self class]), (__bridge void *)self);
    
    while ([stack count]) {
        NSLog(@"-[BSDAGNode allConnectedNodes] stack has %d elements", (int)[stack count]);
        BSDAGNode *poppedNode = [stack lastObject];
        [stack removeLastObject];
        if ([set containsObject:poppedNode]) {
            continue;
        }
        [set addObject:poppedNode];
        for (BSDAGNode *node in poppedNode.targetNodes) {
            if (![set containsObject:node]) {
                [stack addObject:node];
            }
        }
    }
    return [set copy];
}


@end

@interface NodeStack : NSObject
@property (nonatomic, readonly) NSMutableArray<BSDAGNode *> *nodes;
- (void)push:(BSDAGNode *)node;
- (BSDAGNode *)pop;
@end

@implementation NodeStack

-(instancetype)init
{
    if (self = [super init]) {
        _nodes = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    [self removeAll];
}

- (void)removeAll
{
    for (BSDAGNode *node in _nodes) {
        [node setOnStack:NO];
    }
    [_nodes removeAllObjects];
}

- (void)push:(BSDAGNode *)node
{
    [_nodes addObject:node];
    [node setOnStack:YES];
}

- (BSDAGNode *)pop
{
    BSDAGNode *node = [_nodes lastObject];
    [_nodes removeLastObject];
    [node setOnStack:NO];
    return node;
}

@end

@implementation BSDAGStrongConnectedComponent

- (instancetype)initWithNodes:(NSArray<BSDAGNode *> *)nodes
{
    if (self = [super init]) {
        _nodes = [nodes copy];
    }
    return self;
}

@end

@implementation BSDAG (Cycles)

static void strongconnect(NodeStack *stack, BSDAGNode *node, NSUInteger *depthIndex, NSMutableArray<BSDAGStrongConnectedComponent *> *stronglyConnectedComponents)
{
    [node setIndex:*depthIndex];
    [node setLowLink:*depthIndex];
    *depthIndex += 1;
    [stack push:node];
    
    for (BSDAGNode *w in node.targetNodes) {
        NSUInteger wIndex = [w index];
        if (wIndex == NSNotFound){
            // w has not yet been visited
            strongconnect(stack, w, depthIndex, stronglyConnectedComponents);
            node.lowLink = MIN(node.lowLink, w.lowLink);
        } else if (w.onStack) {
            node.lowLink = MIN(node.lowLink, wIndex);
        }
    }
    
    // If node is a root node, pop the stack and generate an SCC
    if (node.lowLink == [node index]) {
        NSMutableArray<BSDAGNode *> *nodes = [NSMutableArray array];
        BSDAGNode *w;
        do {
            w = [stack pop];
            [nodes addObject:w];
        } while (w != node);
        BSDAGStrongConnectedComponent *scc = [[BSDAGStrongConnectedComponent alloc] initWithNodes:nodes];
        [stronglyConnectedComponents addObject:scc];
    }
}

- (NSArray<BSDAGStrongConnectedComponent *> *)findStronglyConnectedComponents
{
    NodeStack *stack = [[NodeStack alloc] init];
    NSMutableArray<BSDAGStrongConnectedComponent *> *stronglyConnectedComponents = [NSMutableArray array];
    NSUInteger depthIndex = 1;
    for (BSDAGNode *node in self.nodes) {
        NSUInteger index = [node index];
        if (index == NSNotFound) {
            strongconnect(stack, node, &depthIndex, stronglyConnectedComponents);
        }
    }
    return [stronglyConnectedComponents copy];
}

@end

