//
//  BSCoastingController.m
//  coasting-animation
//
//  Created by Dan Wright on 4/3/16.
//  Copyright © 2016 Dan Wright. All rights reserved.
//

#import "BSCoastingController.h"

#import <Math.h>
#import <UIKit/UIKit.h>

@interface BSCoastingModel ()
@property (nonatomic, readonly) double r;
@property (nonatomic, readonly) double ln_r;
@property (nonatomic, readonly) double minSpeed;
@property (nonatomic, readonly) double ln_minSpeed;
@property (nonatomic, readonly) double ln_v0;
@end

@implementation BSCoastingModel

- (instancetype)initWithCoefficientOfResistance:(double)r minimumCoastingSpeed:(double)minSpeed initialVelocity:(double)initialVelocity
{
    if (self = [super init]) {
        _r = r;
        _minSpeed = minSpeed;
        // Precalculate the natural logs of r and minSpeed.
        _ln_r = log(r);
        _ln_minSpeed = log(minSpeed);
        _initialVelocity = initialVelocity;
        _ln_v0 = log(fabs(initialVelocity)); // log of the magnitude
    }
    return self;
}

- (instancetype)initWithCoefficientOfResistance:(double)r minimumCoastingSpeed:(double)minSpeed
{
    return [self initWithCoefficientOfResistance:r minimumCoastingSpeed:minSpeed initialVelocity:NAN];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[BSMutableCoastingModel allocWithZone:zone] initWithCoefficientOfResistance:self.r minimumCoastingSpeed:self.minSpeed initialVelocity:self.initialVelocity];
}

// Coasting
// Drag due to friction is (generally) directly-proportional to velocity (but in the opposite direction).
//
// _coefficient of resistance_ (`r`) represents this ratio. It represents the reduction of speed per second.
//
// v(t) = v0 * r^t
//
// [Digression:  r^t can be calculated "slowly" via power(r, r); this is the same as exp(t*log(r)). Since
//  r is fixed, and exp is much faster than power, we substitute exp(t * _ln_r). Remember that 'log' implements
//  the natural logarithm (base-e, i.e. ln) rather than the common logarithm (base-10).]
//
// Some materials have a property where at very low speeds, friction actually spikes; this has
// the effect of a object abruptly stopping when its speed drops below a certain threshold.
//
// We represent this minimal velocity with `vmin`.
//
// Thus the revised velocity formula:
// v'(t) = v0 * r^t
// v(t) = (v'(t) > vmin) ? v'(t) : 0
//
// The reduction in speed over an arbitrary time dt is: r'(dt) = r^dt
//
// 't_stop' represents the time until the object comes to a rest.
// We have:  vmin = v0 * r^t_stop
// Solving, ln(vmin) = ln(v0) + t_stop*ln(r)
//              t_stop = (ln(vmin) - ln(v0))/ln(r)
//
// The distance traveled at time t can also be calculated. This is determined by integrating
// the value of velocity-over-time over the time range. Generally:
//             ∫ v'(t) dt
//                          = ∫ v0 * dt * r^t = v0 * ∫ dt *r ^ t = v0 * (r^t/ln(r) - r^0/ln(r))
//                          = v0 * (r^t - 1)/ln(r)
//
// The maximum (total) distance traveled is simply:
//          distance_total = distance(t_stop)

- (double)velocityForTime:(CFTimeInterval)t
{
    double vt = _initialVelocity*exp(_ln_r*t); // v(t) = v(0)*r^t
    return fabs(vt) < _minSpeed ? 0 : vt;
}

- (CFTimeInterval)stoppingTime
{
    return (_ln_minSpeed - _ln_v0)/_ln_r;
}

- (double)distanceForTime:(CFTimeInterval)t
{
    // d(t) = v0 * (r^t - 1) / ln(r)
	return _initialVelocity*(exp(_ln_r*t) - 1.0)/_ln_r;
}

- (double)stoppingDistance
{
    return [self distanceForTime:[self stoppingTime]];
}

// How long will it take to travel a specified distance?
// distance = v0*(r^t - 1.0)/ln(r)
// --> distance*ln(r)/v0 + 1.0 = r^t
// --> ln(distance*ln(r)/v0 + 1.0) = t*ln(r)
// --> ln(distance*ln(r)/v0 + 1.0)/ln(r) = t
- (CFTimeInterval)timeForDistance:(double)distance
{
    double v0 = fabs(_initialVelocity); // Direction (sign) is irrelevant here.
    if (v0 == 0) {
        return NAN;
    }
    double inner = distance*_ln_r/v0 + 1.0;
    // When distance > distance_stop, inner will be negative.
    if (inner < 0) {
        return NAN; // We will never travel so far.
    }
    return log(inner)/_ln_r;
}

- (void)_setInitialVelocity:(double)initialVelocity
{
    // This is for the benefit of BSMutableCoastingModel
    _initialVelocity = initialVelocity;
}


+ (double)coefficientOfResistanceToEndAfter:(NSTimeInterval)desiredTime fromInitialSpeed:(double)initialSpeed minSpeed:(double)minSpeed
{
    // A handy utility for deriving a coefficent of resistance from a desired coasting time. The initialSpeed
    // is typically the maximum initial speed allowed.
    
    assert(initialSpeed > 0.0);
    assert(desiredTime > 0.0);
    // minSpeed = initialSpeed * r ^ desiredTime
    //(minSpeed / initialSpeed) = r ^ desiredTime
    // log(minSpeed / initialSpeed) = desiredTime * log(r)
    // log(r) == log(minSpeed / initialSpeed)/desiredTime
    // r = e^(log(minSpeed / initialSpeed)/desiredTime)
    
    return exp(log(minSpeed / initialSpeed) / desiredTime);
}

+ (double)coefficientOfResistanceToCoastDistance:(double)coastingDistance fromInitialSpeed:(double)initialSpeed minSpeed:(double)minSpeed
{
    // A handy utility for deriving a coefficient of resistance from a desired coasting distance.
    // This requires a binary search to find the answer; for reasonable parameters this requires fewer than
    // twenty iterations. The degenerate case takes 30 iterations (thanks to limited floating point precision).
    
    assert(initialSpeed > 0.0);
    assert(coastingDistance > 0.0);
    assert(minSpeed >= 0.0);
    assert(initialSpeed > minSpeed); // duh
    
    // We do a binary search on r for the answer.
    double minR = 0.0, maxR = 1.0, r;
    double ln_minSpeed = log(minSpeed);
    double ln_v0 = log(initialSpeed);
    double stoppingDistance;
    do {
        r = 0.5*(minR + maxR); // start half-way in between
        double ln_r = log(r);
        NSTimeInterval stoppingTime = (ln_minSpeed - ln_v0) / ln_r;
        stoppingDistance = initialSpeed * (exp(stoppingTime * ln_r) - 1.0) / ln_r;
        if (stoppingDistance > coastingDistance) {
            maxR = r;
        } else if (stoppingDistance < coastingDistance) {
            minR = r;
        }
        // The secondary check is necessary because floating point precision is finite.
    } while (fabs(stoppingDistance - coastingDistance) > 0.5 && (maxR - minR) > 0.000000001);
    return r;
}

@end

@implementation BSMutableCoastingModel

@dynamic initialVelocity;

- (id)copyWithZone:(NSZone *)zone
{
    return [[BSCoastingModel allocWithZone:zone] initWithCoefficientOfResistance:self.r minimumCoastingSpeed:self.minSpeed initialVelocity:self.initialVelocity];
}

- (void)setInitialVelocity:(double)initialVelocity
{
    [super _setInitialVelocity:initialVelocity];
}

@end

#pragma mark -

@interface BSCoastingController ()
@property (nonatomic) CFTimeInterval startTime;
@property (nonatomic) CADisplayLink *displayLink;
@end

@implementation BSCoastingController
{
	CFTimeInterval _timeFinal;
	double _distanceFinal;
	BOOL   _needTimeFinal;
	BOOL   _needDistanceFinal;
}

- (instancetype)initWithCoastingModel:(BSCoastingModel *)model
{
	if (self = [super init]) {
		_model = [model copy];
		_timeFinal = _distanceFinal = 0.0;
		_needTimeFinal = _needDistanceFinal = YES;
		_startTime = NAN;
	}
	return self;
}

- (void)invalidate
{
    [self stop];
}

- (double)initialVelocity
{
    return self.model.initialVelocity;
}

- (void)setInitialVelocity:(double)initialVelocity
{
    BSMutableCoastingModel *mutableModel = [self.model mutableCopy];
    [mutableModel setInitialVelocity:initialVelocity];
    _model = [mutableModel copy];
    _needDistanceFinal = YES;
    _needTimeFinal = YES;
}

#pragma mark - Math

- (double)vt:(CFTimeInterval)t
{
	return [self.model velocityForTime:t];
}

- (CFTimeInterval)stoppingTime
{
    return [self.model stoppingTime];
}

- (double)distanceForTime:(CFTimeInterval)t
{
	return [self.model distanceForTime:MIN(t, [self stoppingTime])];
}

- (double)stoppingDistance
{
	if (_needDistanceFinal) {
        _distanceFinal = [self.model stoppingDistance];
        _needDistanceFinal = NO;
	}
	return _needDistanceFinal;
}

- (CFTimeInterval)t_from_distance:(double)distance
{
	return [self.model timeForDistance:distance];
}

#pragma mark - Coasting notifications

- (void)willStartCoast
{
#ifdef DEBUG
	NSLog(@"willStartCoast (will end in %.3f sec)", [self stoppingTime]);
#endif
    assert(!isnan([self stoppingTime]));
	[self.delegate willStartCoast];
}

- (void)didCancelCoast
{
#ifdef DEBUG
	NSLog(@"didCancelCoast");
#endif
	[self.delegate didCancelCoast];
}

- (void)didEndCoast:(CFTimeInterval)t
{
#ifdef DEBUG
	NSLog(@"didEndCoast: %.3f", t);
#endif
	[self.delegate didEndCoast];
}

- (void)coasting:(CFTimeInterval)t velocity:(double)v distance:(double)distance
{
#ifdef DEBUG
    static unsigned long _count;
    if ((_count % 15) == 0) {
        NSLog(@"coasting: t:%.3f, v:%.3f, distance:%.3f", t, v, distance);
    }
    _count++;
#endif
    
	[self.delegate continueCoastingAtTime:t velocity:v distance:distance];
}

#pragma mark - CADisplayLink

- (void)stop
{
	if (!isnan(self.startTime)) {
		[self didCancelCoast];
	}
	CADisplayLink *link = self.displayLink;
	if (!link) {
		return;
	}
    NSLog(@"Coasting: STOP");
	[link invalidate];
	[self setDisplayLink:nil];
	[self setStartTime:NAN];
}

- (void)startCoastingWithInitialVelocity:(double)initialVelocity
{
    [self setInitialVelocity:initialVelocity];
    [self startForScreen:[UIScreen mainScreen]];
}

- (void)startForScreen:(UIScreen *)screen
{
    NSLog(@"Coasting: START");
	[self stop];
	[self setStartTime:CACurrentMediaTime()];
	[self willStartCoast];
	[self setDisplayLink:[screen displayLinkWithTarget:self selector:@selector(fireDisplayLink:)]];
    [self.displayLink setPreferredFramesPerSecond:30];
	[self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (CFTimeInterval)currentTime
{
	return CACurrentMediaTime() - self.startTime;
}

- (CFTimeInterval)endTime
{
	return self.stoppingTime;
}

- (BOOL)isCoasting
{
	return !isnan(self.startTime);
}

- (void)fireDisplayLink:(CADisplayLink *)displayLink
{
	[CATransaction begin];
	[CATransaction setAnimationDuration:0.0];
	[CATransaction setDisableActions:YES];
	
	CFTimeInterval t = [self currentTime];
	double vx = [self vt:t];
	double dx = [self distanceForTime:t];
	
	[self coasting:t velocity:vx distance:dx];

	double t_prime = [self currentTime];
	[CATransaction commit];

	if (t_prime - t >= 1.0/60.0) {
		NSLog(@"coasting call took more than 1/60th sec! (\(t_prime - t) sec)");
	}
	if (t >= self.endTime) {
        // Stop the display link, we've reached the end.
        NSLog(@"stopping; t = %.3f, endTime = %.3f", t, self.endTime);
		[displayLink invalidate];
		if (displayLink == self.displayLink) {
			[self setDisplayLink:nil];
			[self didEndCoast:t];
		}
	}
}

@end
