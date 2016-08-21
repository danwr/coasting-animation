//
//  SimpleTransportBar.m
//  coasting-animation
//
//  Created by Dan Wright on 8/19/16.
//  Copyright © 2016 Dan Wright. All rights reserved.
//

#import "SimpleTransportBar.h"

static const CGFloat TransportBarHeight = 16.0;
static const CGFloat NeedleWidth = 3.0;
static const CGFloat SideMargin = 90.0;
static const CGFloat BottomMargin = 90.0;

@interface RoundRectView : UIView
@end

@implementation RoundRectView

- (void)drawRect:(CGRect)rect
{
    [[UIColor darkGrayColor] setFill];
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:[self bounds] cornerRadius:8.0];
    [path fill];
}

@end

@interface SimpleTransportBar ()
@property (nonatomic) RoundRectView *roundRectView;
@property (nonatomic) UIView *needleView;
@property (nonatomic) UILabel *timeRemainingLabel;
@end

@implementation SimpleTransportBar

static SimpleTransportBar *CommonInit(SimpleTransportBar *self)
{
    if (!self) {
        return self;
    }
    
    UIScreen *screen = [UIScreen mainScreen];
    CGRect screenBounds = [screen bounds];
    
    self->_roundRectView = [[RoundRectView alloc] initWithFrame:CGRectMake(0, 0, screenBounds.size.width - 2*SideMargin, TransportBarHeight)];
    [self->_roundRectView setAutoresizingMask:0];
    self->_needleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, NeedleWidth, TransportBarHeight+4.0)];
    self->_timeRemainingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [self->_timeRemainingLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody compatibleWithTraitCollection:nil]];
    [self->_timeRemainingLabel setTextColor:[UIColor whiteColor]];
    [self->_needleView setBackgroundColor:[UIColor whiteColor]];
    [self addSubview:self->_roundRectView];
    [self addSubview:self->_needleView];
    
    self->_duration = 3600.0;
    self->_currentTime = 60.0;
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    return CommonInit([super initWithFrame:frame]);
}

- (CGSize)intrinsicContentSize
{
    UIScreen *screen = [UIScreen mainScreen];
    CGRect screenBounds = [screen bounds];
    return CGSizeMake(screenBounds.size.width - SideMargin*2.0, TransportBarHeight);
}

- (void)setCurrentTime:(NSTimeInterval)currentTime animating:(BOOL)animating
{
    if (animating) {
        [UIView animateWithDuration:0.25 delay:0.0 options:0 animations:^{
            [self setCurrentTime:currentTime animating:NO];
        } completion:nil];
    } else {
        _currentTime = MAX(0.0, MIN(self.duration, currentTime));
        [self setNeedsLayout];
        [self.timeRemainingLabel setText:[NSString stringWithFormat:@"-%.0f sec", self.duration - self.currentTime]];
        [self layoutIfNeeded];
    }
}

- (void)layoutSubviews
{
    [self.roundRectView setFrame:self.bounds];
    double fraction = self.currentTime / self.duration;
    CGFloat usableWidth = self.bounds.size.width - 8.0;
    [self.needleView setCenter:CGPointMake(self.bounds.origin.x + 4.0 + usableWidth * fraction, CGRectGetMidY(self.bounds))];
    [self.timeRemainingLabel setCenter:CGPointMake(CGRectGetMaxX(self.bounds) - self.timeRemainingLabel.bounds.size.width, CGRectGetMidY(self.bounds))];
}
@end
