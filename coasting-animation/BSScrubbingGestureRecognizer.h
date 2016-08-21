//
//  BSScrubbingGestureRecognizer.h
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, BSScrubbingAxis) {
	BSScrubbingAxisHorizontal,
	BSScrubbingAxisVertical
};

@class BSScrubbingGestureRecognizer;

@protocol BSScrubbingGestureDelegate <NSObject>
- (void)scrubbingGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer didRestingTouch:(UITouch *)touch;
- (void)scrubbingGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer didStopRestingTouch:(UITouch *)touch;

- (void)scrubbingGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer didMoveOnAxis:(CGFloat)distance velocity:(CGFloat)velocity;
- (void)scrubbingGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer willCoastWithInitialVelocity:(CGFloat)v0;
- (void)didCancelScrubbingGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer;

@end

@interface BSScrubbingGestureRecognizer : UIGestureRecognizer
@property (nonatomic) BSScrubbingAxis scrubbingAxis; // default: BSScrubbingAxisHorizontal
@property (nonatomic, weak) id<BSScrubbingGestureDelegate> scrubbingGestureDelegate;

@property (nonatomic, readonly, getter = isTouching) BOOL touching;
@end
