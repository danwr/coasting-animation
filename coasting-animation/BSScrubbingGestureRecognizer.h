//
//  BSScrubbingGestureRecognizer.h
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, BSPanningAxis) {
	BSPanningAxisNone,
	BSPanningAxisHorizontal,
	BSPanningAxisVertical
};

@class BSScrubbingGestureRecognizer;

@protocol BSPanAndCoastDelegate <NSObject>
- (void)panAndCoastGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer didRestingTouch:(UITouch *)touch;
- (void)panAndCoastGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer didStopRestingTouch:(UITouch *)touch;

- (void)panAndCoastGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer didMoveOnAxis:(CGFloat)distance velocity:(CGFloat)velocity;
- (void)panAndCoastGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer willCoastWithInitialVelocity:(CGFloat)v0;
- (void)didCancelPanAndCoastGestureRecognizer:(BSScrubbingGestureRecognizer *)gestureRecognizer;

@end

@interface BSScrubbingGestureRecognizer : UIGestureRecognizer
@property (nonatomic) BSPanningAxis panningAxis; // default: BSPanningAxisHorizontal
@property (nonatomic, weak) id<BSPanAndCoastDelegate> panAndCoastDelegate;

@property (nonatomic, readonly, getter = isTouching) BOOL touching;
@end
