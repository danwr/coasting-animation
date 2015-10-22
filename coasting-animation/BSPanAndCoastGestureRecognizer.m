//
//  BSPanAndCoastGestureRecognizer.m
//  coasting-animation
//

#import "BSPanAndCoastGestureRecognizer.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

@interface BSPanAndCoastGestureRecognizer ()
@property (nonatomic) UITouch *lastTouch;
@property (nonatomic) CGPoint startPosition;
@property (nonatomic) CGPoint lastPosition;
@property (nonatomic) NSTimeInterval startTimestamp;
@property (nonatomic, getter=isResting) BOOL resting;
@property (nonatomic) CGFloat velocity;
@property (nonatomic) CGFloat previousVelocity;
@end

static const CGFloat VELOCITY_SAMPLE_WEIGHT = 0.25;
static const CGFloat VELOCITY_SAMPLE_WEIGHT_REVERSAL = 0.75; // when sign(velocity) changes, give it more weight

NS_INLINE CGFloat sign(CGFloat x) {
	return (x < 0) ? -1.0 : (x > 0 ? +1.0 : 0.0);
}

@implementation BSPanAndCoastGestureRecognizer
{
	CGFloat _minimumOnAxisMovement;
	CGFloat _maximumOffAxisMovement;
	CGFloat _maximumVelocity;
	CGFloat _minimumCoastingVelocity;
}
- (instancetype)initWithTarget:(id)target action:(SEL)action
{
	if (self = [super initWithTarget:target action:action]) {
		_panningAxis = BSPanningAxisHorizontal;
		_minimumOnAxisMovement = 20.0;
		_maximumOffAxisMovement = 30.0;
		_maximumVelocity = 100.0;
		_minimumCoastingVelocity = 5.0;
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
	[self.panAndCoastDelegate panAndCoastGestureRecognizer:self didRestingTouch:self.lastTouch];
}

- (void)_endRestingTouch
{
	if (self.resting) {
		[self.panAndCoastDelegate panAndCoastGestureRecognizer:self didStopRestingTouch:self.lastTouch];
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
	[self performSelector:@selector(_beginRestingTouch) withObject:nil afterDelay:1.0 inModes:@[NSRunLoopCommonModes]];
}

#pragma mark -

- (CGFloat)_onAxisMovement:(CGPoint)delta
{
	return (self.panningAxis == BSPanningAxisVertical) ? delta.y : delta.x;
}

- (CGFloat)_offAxisMovement:(CGPoint)delta
{
	return (self.panningAxis == BSPanningAxisVertical) ? delta.x : delta.y;
}

- (void)didMoveOnAxisDistance:(CGFloat)distance velocity:(CGFloat)velocity
{
	[self.panAndCoastDelegate panAndCoastGestureRecognizer:self didMoveOnAxis:distance velocity:velocity];
}

- (void)didCancelPan
{
	[self.panAndCoastDelegate didCancelPanAndCoastGestureRecognizer:self];
}

- (void)willCoastWithInitialVelocity:(CGFloat)velocity
{
	[self.panAndCoastDelegate panAndCoastGestureRecognizer:self willCoastWithInitialVelocity:velocity];
}

#pragma mark - touch events

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	if ([touches count] != 1) {
		[self setState:UIGestureRecognizerStateFailed];
		return;
	}
	[self _scheduleRestingTouch];
	[self setLastTouch:[touches anyObject]];
	[self setStartPosition:[self.lastTouch locationInView:nil]];
	[self setStartTimestamp:event.timestamp];
	[self setPreviousVelocity:self.velocity];
	[self setVelocity:0.0];
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
	[self _cancelRestingTouch];
	[self _endRestingTouch];
	[self setLastTouch:nil];
	if (fabs(self.velocity) > _minimumCoastingVelocity) {
		[self willCoastWithInitialVelocity:self.velocity];
	}
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	if (self.state == UIGestureRecognizerStateBegan) {
		[self didCancelPan];
	}
	[self setState:UIGestureRecognizerStateCancelled];
	[self _cancelRestingTouch];
	[self _endRestingTouch];
	[self setLastTouch:nil];
	[self setVelocity:0];
}

@end
