//
//  BSScrubbingGestureRecognizer.m
//
//  Tracks scrubbing gesture.
//

#import "BSScrubbingGestureRecognizer.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

@interface BSScrubbingGestureRecognizer ()
@property (nonatomic) UITouch *lastTouch;
@property (nonatomic) CGPoint startPosition;
@property (nonatomic) CGPoint lastPosition;
@property (nonatomic) NSTimeInterval startTimestamp;
@property (nonatomic, getter=isResting) BOOL resting;
@property (nonatomic) CGFloat velocity;
@property (nonatomic) CGFloat previousVelocity;
@property (nonatomic, getter = isTouching) BOOL touching;
@end

static const CGFloat VELOCITY_SAMPLE_WEIGHT = 0.25;
static const CGFloat VELOCITY_SAMPLE_WEIGHT_REVERSAL = 0.75; // when sign(velocity) changes, give it more weight

// The value returned by `sign` is an integer; this is fast and most appropriate when comparing the signs of two expressions. To copy the sign to a new float, use copysign.
NS_INLINE int sign(CGFloat x) {
    return (x > 0) - (x < 0);
}

@implementation BSScrubbingGestureRecognizer
{
    CGFloat _maximumDistanceCoveredByIsolatedScrub;
	CGFloat _minimumOnAxisMovement;
	CGFloat _maximumOffAxisMovement;
	CGFloat _maximumVelocity;
	CGFloat _minimumCoastingVelocity;
	NSTimeInterval _restingTouchMinimumInterval;
    CGFloat _movementScale;
}
- (instancetype)initWithTarget:(id)target action:(SEL)action
{
	if (self = [super initWithTarget:target action:action]) {
        // Original figures, derived for 1080p screens, need to be scaled to appropriately handle other resolutions.
        CGFloat screenWidth = CGRectGetWidth([[UIScreen mainScreen] bounds]);
        _movementScale = 0.1; // Sliding the full width of the touch surface moves 1/10 of the way across the screen.
        // The maximum distance covered by a single, isolated scrub gesture (ignoring momentum).
        _maximumDistanceCoveredByIsolatedScrub = screenWidth * _movementScale;
		_scrubbingAxis = BSScrubbingAxisHorizontal;
        _minimumOnAxisMovement = screenWidth / 96.0; // This is 20px on 1080p screens
		_maximumOffAxisMovement = _minimumOnAxisMovement * 1.5;
        _maximumVelocity = screenWidth * _movementScale;
		_minimumCoastingVelocity = 5.0;
		_restingTouchMinimumInterval = 1.0;
        [super setAllowedTouchTypes:@[@(UITouchTypeIndirect)]];
	}
	return self;
}

- (void)dealloc
{
	[self _cancelRestingTouch];
}

#pragma mark - resting touches

- (void)_beginRestingTouch
{
	[self setResting:YES];
	[self.scrubbingGestureDelegate scrubbingGestureRecognizer:self didRestingTouch:self.lastTouch];
}

- (void)_endRestingTouch
{
	if (self.resting) {
		[self.scrubbingGestureDelegate scrubbingGestureRecognizer:self didStopRestingTouch:self.lastTouch];
		[self setResting:NO];
	}
}

- (void)_cancelRestingTouch
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_beginRestingTouch) object:nil];
}

- (void)_scheduleRestingTouch
{
	[self _cancelRestingTouch];
	[self performSelector:@selector(_beginRestingTouch) withObject:nil afterDelay:_restingTouchMinimumInterval inModes:@[NSRunLoopCommonModes]];
}

#pragma mark -

- (CGFloat)_onAxisMovement:(CGPoint)delta
{
	return ((self.scrubbingAxis == BSScrubbingAxisVertical) ? delta.y : delta.x)*_movementScale;
}

- (CGFloat)_offAxisMovement:(CGPoint)delta
{
	return ((self.scrubbingAxis == BSScrubbingAxisVertical) ? delta.x : delta.y)*_movementScale;
}

- (void)didMoveOnAxisDistance:(CGFloat)distance velocity:(CGFloat)velocity
{
	[self.scrubbingGestureDelegate scrubbingGestureRecognizer:self didMoveOnAxis:distance velocity:velocity];
}

- (void)didCancelPan
{
	[self.scrubbingGestureDelegate didCancelScrubbingGestureRecognizer:self];
}

- (void)willCoastWithInitialVelocity:(CGFloat)velocity
{
	[self.scrubbingGestureDelegate scrubbingGestureRecognizer:self willCoastWithInitialVelocity:velocity];
}

#pragma mark -

- (void)reset
{
    [self setTouching:NO];
    [self _cancelRestingTouch];
}

#pragma mark - touch events

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	if ([touches count] != 1) {
		[self setState:UIGestureRecognizerStateFailed];
		return;
	}
    [self setTouching:YES];
    [self.scrubbingGestureDelegate didStartTouchesForScrubbingGestureRecognizer:self];
	[self _scheduleRestingTouch];
	[self setLastTouch:[touches anyObject]];
	[self setStartPosition:[self.lastTouch locationInView:nil]];
	[self setStartTimestamp:event.timestamp];
	[self setPreviousVelocity:self.velocity];
	[self setVelocity:0.0];
    [self setLastPosition:self.startPosition];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	[self _scheduleRestingTouch];
	[self _endRestingTouch];
	[self setLastTouch:[touches anyObject]];
	CGPoint currentPosition = [self.lastTouch locationInView:nil];
	CGPoint priorPosition = self.lastPosition;
	[self setLastPosition:currentPosition];
	
	CGPoint deltaSinceStart = {currentPosition.x - self.startPosition.x, currentPosition.y - self.startPosition.y};
	if (self.state == UIGestureRecognizerStatePossible) {
		CGFloat onAxisMovement = [self _onAxisMovement:deltaSinceStart], offAxisMovement = [self _offAxisMovement:deltaSinceStart];
		CGFloat absOnAxisMovement = fabs(onAxisMovement), absOffAxisMovement = fabs(offAxisMovement);
		if (absOnAxisMovement > absOffAxisMovement && absOnAxisMovement > _minimumOnAxisMovement) {
			[self setState:UIGestureRecognizerStateBegan];
		} else if (absOnAxisMovement < absOffAxisMovement && absOffAxisMovement > _maximumOffAxisMovement) {
			[self setState:UIGestureRecognizerStateFailed];
			return;
		}
	}
	CGPoint deltaSinceLast = {currentPosition.x - priorPosition.x, currentPosition.y - priorPosition.y};
//    NSLog(@"touchesMoved: since last: %@", NSStringFromCGPoint(deltaSinceLast));
	
	// Calculate the raw velocity of this sample
	NSTimeInterval currentTimestamp = event.timestamp;
	CGFloat v_previous = (currentTimestamp - self.startTimestamp < 0.25) ? self.previousVelocity : 0.0;
	CGFloat v_sample = [self _onAxisMovement:deltaSinceLast] / (currentTimestamp - self.lastTouch.timestamp);
    
	// Now "smooth" out the velocity to remove spikes and anomolies
	CGFloat sampleWeight = VELOCITY_SAMPLE_WEIGHT;
	if (sign(v_sample) != sign(self.velocity)) {
		sampleWeight = VELOCITY_SAMPLE_WEIGHT_REVERSAL;
	}
	CGFloat velocity = v_sample * sampleWeight + self.velocity * (1.0 - sampleWeight);
	if (fabs(velocity) > _maximumVelocity) {
		velocity = copysign(_maximumVelocity, velocity);
	}
	[self setVelocity:velocity];
    
	CGFloat effectiveVelocity = v_previous + velocity;
	[self didMoveOnAxisDistance:[self _onAxisMovement:deltaSinceLast] velocity:effectiveVelocity];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
//    NSLog(@"touchesEnded: %@", NSStringFromCGPoint([[touches anyObject] locationInView:nil]));
	[self _cancelRestingTouch];
	[self _endRestingTouch];
	[self setLastTouch:nil];
	if (fabs(self.velocity) > _minimumCoastingVelocity) {
		[self willCoastWithInitialVelocity:self.velocity];
	}
    [self setTouching:NO];
    [self setState:UIGestureRecognizerStateRecognized];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesCancelled!");
	if (self.state == UIGestureRecognizerStateBegan) {
		[self didCancelPan];
	}
	[self setState:UIGestureRecognizerStateCancelled];
	[self _cancelRestingTouch];
	[self _endRestingTouch];
	[self setLastTouch:nil];
	[self setVelocity:0];
    [self setTouching:NO];
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
	if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStatePossible) {
		[self setState:UIGestureRecognizerStateFailed];
	}
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
	if (self.state == UIGestureRecognizerStateFailed) {
		[self setState:UIGestureRecognizerStatePossible];
	}
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
	if (self.state == UIGestureRecognizerStateFailed) {
		[self setState:UIGestureRecognizerStatePossible];
	}
}

@end
