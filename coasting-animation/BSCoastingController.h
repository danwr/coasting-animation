//
//  BSCoastingController.h
//  coasting-animation
//
//  Created by Dan Wright on 4/3/16.
//  Copyright © 2016 Dan Wright. All rights reserved.
//

#import <Foundation/Foundation.h>

@class UIScreen;

@interface BSCoastingModel : NSObject <NSCopying, NSMutableCopying>
/*!
	@method initWithCoefficientOfResistance:minimumCoastingSpeed:
	@param	r
		Coefficient of resistance (0.0 means no resistance, coasting never ends/slows; 1.0 means no coasting, infinite friction).
	@param minSpeed
		Minimum speed; below this, resistance spikes and coasting stops. Should be >= 0.0.
 */
- (instancetype)initWithCoefficientOfResistance:(double)r minimumCoastingSpeed:(double)minSpeed;
- (instancetype)initWithCoefficientOfResistance:(double)r minimumCoastingSpeed:(double)minSpeed initialVelocity:(double)initialVelocity;

@property (nonatomic, readonly) double initialVelocity; // Set to the initial velocity (sign is direction) when coasting begins.

@property (nonatomic, readonly) CFTimeInterval stoppingTime; // Time at which coasting will stop. Requires initialVelocity.
@property (nonatomic, readonly) double stoppingDistance; // Distance traveled when coasting stops. Requires initialVelocity.

- (double)velocityForTime:(CFTimeInterval)t;    // Velocity(t). Requires initialVelocity.
- (CFTimeInterval)timeForDistance:(double)distance; // Time at which coasting will have traveled `distance`. Requires initialVelocity; returns NAN if it coasting will never travel `distance`.

// Tool: Determine the coefficient of resistance to used to have a coast end in the desired time. Typically, pass
// the maximum initial speed.
+ (double)coefficientOfResistanceToEndAfter:(NSTimeInterval)desiredTime fromInitialSpeed:(double)initialSpeed minSpeed:(double)minSpeed;

@end

@interface BSMutableCoastingModel : BSCoastingModel
@property (nonatomic) double initialVelocity;
@end

@protocol BSCoastingControllerDelegate <NSObject>
- (void)willStartCoast;
- (void)didCancelCoast;
- (void)didEndCoast;
- (void)continueCoastingAtTime:(CFTimeInterval)time velocity:(double)velocity distance:(double)distance;
@end

@interface BSCoastingController : NSObject
@property (nonatomic, readonly, copy) BSCoastingModel *model;
@property (nonatomic) id<BSCoastingControllerDelegate> delegate;
@property (nonatomic) double initialVelocity;

- (instancetype)initWithCoastingModel:(BSCoastingModel *)model;

- (void)invalidate;

- (void)startCoastingWithInitialVelocity:(double)initialVelocity;
- (void)stop;
- (BOOL)isCoasting;

@end
