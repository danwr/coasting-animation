//
//  SimpleTransportBar.h
//  coasting-animation
//
//  Created by Dan Wright on 8/19/16.
//  Copyright © 2016 Dan Wright. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SimpleTransportBar : UIView
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval currentTime;
- (void)setCurrentTime:(NSTimeInterval)currentTime animating:(BOOL)animating;
@end
