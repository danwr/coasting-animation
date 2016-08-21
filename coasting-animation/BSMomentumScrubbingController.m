//
//  BSMomentumScrubbingController.m
//  coasting-animation
//
//  Created by Dan Wright on 8/19/16.
//  Copyright © 2016 Dan Wright. All rights reserved.
//

#import "BSMomentumScrubbingController.h"
#import <UIKit/UIKit.h>
#import "BSCoastingController.h"
#import "BSScrubbingGestureRecognizer.h"

@interface BSMomentumScrubbingController () <BSScrubbingGestureDelegate, BSCoastingControllerDelegate>
@property (nonatomic) BSCoastingController *coastingController;
@property (nonatomic) CGPoint positionAtCoastingStart;
@end

static const double MinimumCoastingSpeed = 4.0; // REVIEW
static const double CoefficientOfResistance = 0.20; // Determined via +[BSCoastingModel coeeficientOfResistenceToEndAfter:2.0 fromInitialSpeed:100.0 minimumCoastingSpeed:MinimumCoastingSpeed]

NS_INLINE double pinf(double min, double max, double v)
{
    return MAX(min, MIN(max, v));
}

@implementation BSMomentumScrubbingController

- (instancetype)init
{
    if (self = [super init]) {
        BSCoastingModel *coastingModel = [[BSCoastingModel alloc] initWithCoefficientOfResistance:CoefficientOfResistance minimumCoastingSpeed:MinimumCoastingSpeed];
        _coastingController = [[BSCoastingController alloc] initWithCoastingModel:coastingModel];
        [_coastingController setDelegate:self];
        _gestureRecognizer = [[BSScrubbingGestureRecognizer alloc] initWithTarget:self action:@selector(panAndCoastGesture:)];
        [_gestureRecognizer setScrubbingAxis:BSScrubbingAxisHorizontal];
        [_gestureRecognizer setScrubbingGestureDelegate:self];
    }
    return self;
}

- (void)panAndCoastGesture:(BSScrubbingGestureRecognizer *)gestureRecognizer
{
    // This space intentionally left blank.
}

- (void)setEnabled:(BOOL)enabled
{
    if (enabled != _enabled) {
        _enabled = enabled;
        [self.gestureRecognizer setEnabled:enabled];
        [self.coastingController stop];
    }
}

- (BOOL)isCoasting
{
    return [self.coastingController isCoasting];
}

- (BOOL)isTouching
{
    UIGestureRecognizerState state = [self.gestureRecognizer state];
    return [self.gestureRecognizer isTouching] && (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStatePossible || state == UIGestureRecognizerStateChanged);
}

- (void)setPosition:(CGPoint)position
{
//    NSLog(@"changing position from %@ to %@", NSStringFromCGPoint(_position), NSStringFromCGPoint(position));
    _position = position;
}

#pragma mark - scrubbingGestureRecognizer

- (void)scrubbingGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer didMoveOnAxis:(CGFloat)distance velocity:(CGFloat)velocity
{
    [self.coastingController stop];
    CGPoint adjustedPosition = self.position;
    if (self.gestureRecognizer.scrubbingAxis == BSScrubbingAxisHorizontal) {
        adjustedPosition.x += distance;
    } else if (self.gestureRecognizer.scrubbingAxis == BSScrubbingAxisVertical) {
        adjustedPosition.y += distance;
    }
    adjustedPosition.x = pinf(CGRectGetMinX(self.bounds), CGRectGetMaxX(self.bounds), adjustedPosition.x);
    adjustedPosition.y = pinf(CGRectGetMinY(self.bounds), CGRectGetMaxY(self.bounds), adjustedPosition.y);
//    NSLog(@"p&c: setPosition:%@", NSStringFromCGPoint(adjustedPosition));
    [self setPosition:adjustedPosition];
}

- (void)scrubbingGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer willCoastWithInitialVelocity:(CGFloat)v0
{
    [self.coastingController startCoastingWithInitialVelocity:v0];
}

- (void)didCancelScrubbingGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer
{
    [self.coastingController stop];
}

- (void)scrubbingGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer didRestingTouch:(UITouch *)touch
{
}

- (void)scrubbingGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer didStopRestingTouch:(UITouch *)touch
{
    
}

#pragma mark - BSCoastingControllerDelegate

- (void)willStartCoast
{
    [self setPositionAtCoastingStart:self.position];
}

- (void)didCancelCoast
{
    
}

- (void)didEndCoast
{
    
}

- (void)continueCoastingAtTime:(CFTimeInterval)time velocity:(double)velocity distance:(double)distance
{
    CGPoint adjustedPosition = self.positionAtCoastingStart;
    if (self.gestureRecognizer.scrubbingAxis == BSScrubbingAxisHorizontal) {
        adjustedPosition.x += distance;
    } else if (self.gestureRecognizer.scrubbingAxis == BSScrubbingAxisVertical) {
        adjustedPosition.y += distance;
    }
    adjustedPosition.x = pinf(CGRectGetMinX(self.bounds), CGRectGetMaxX(self.bounds), adjustedPosition.x);
    adjustedPosition.y = pinf(CGRectGetMinY(self.bounds), CGRectGetMaxY(self.bounds), adjustedPosition.y);
    [self setPosition:adjustedPosition];
}

@end
