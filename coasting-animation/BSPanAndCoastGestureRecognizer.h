//
//  BSPanningWithCoastingGestureRecognizer.h
//  coasting-animation
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, BSPanningAxis) {
	BSPanningAxisNone,
	BSPanningAxisHorizontal,
	BSPanningAxisVertical
};

@class BSPanAndCoastGestureRecognizer;

@protocol BSPanningDelegate <NSObject>
- (void)panAndCoastGestureRecognizer:(BSPanAndCoastGestureRecognizer *)gestureRecognizer didRestingTouch:(UITouch *)touch;
- (void)panAndCoastGestureRecognizer:(BSPanAndCoastGestureRecognizer *)gestureRecognizer didStopRestingTouch:(UITouch *)touch;

- (void)panAndCoastGestureRecognizer:(BSPanAndCoastGestureRecognizer *)gestureRecognizer didMoveOnAxis:(CGFloat)distance velocity:(CGFloat)velocity;
- (void)panAndCoastGestureRecognizer:(BSPanAndCoastGestureRecognizer *)gestureRecognizer willCoastWithInitialVelocity:(CGFloat)v0;
- (void)didCancelPanAndCoastGestureRecognizer:(BSPanAndCoastGestureRecognizer *)gestureRecognizer;

@end

@interface BSPanAndCoastGestureRecognizer : UIGestureRecognizer
@property (nonatomic) BSPanningAxis panningAxis; // default: BSPanningAxisHorizontal
@property (nonatomic, weak) id<BSPanningDelegate> panAndCoastDelegate;
@end
