//
//  BSMomentumScrubbingController.h
//  coasting-animation
//

#import <UIKit/UIKit.h>
//#import "BSCoastingController.h"

@class BSCoastingController;
@class BSScrubbingGestureRecognizer;

@interface BSMomentumScrubbingController : NSObject

@property (nonatomic) CGRect bounds; // `position` must stay within these bounds
@property (nonatomic) CGPoint position; // Observable!

@property (nonatomic, getter = isEnabled) BOOL enabled;

@property (nonatomic, readonly) BSScrubbingGestureRecognizer *gestureRecognizer;
@property (nonatomic, readonly) BSCoastingController *coastingController;

@property (nonatomic, readonly, getter = isCoasting) BOOL coasting;
@property (nonatomic, readonly, getter = isTouching) BOOL touching;

@end
