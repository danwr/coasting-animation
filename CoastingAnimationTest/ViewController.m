//
//  ViewController.m
//  CoastingAnimationTest
//
//  Created by Dan Wright on 8/20/16.
//  Copyright © 2016 Dan Wright. All rights reserved.
//

#import "ViewController.h"
#import "SimpleTransportBar.h"
#import "BSMomentumScrubbingController.h"
#import "BSScrubbingGestureRecognizer.h"
#import "BSKVOController.h"

@interface ViewController ()
@property (nonatomic) SimpleTransportBar *transportBar;
@property (nonatomic) BSMomentumScrubbingController *scrubbingController;
@property (nonatomic) BSKVOController *kvo;
@end

NS_INLINE double pinf(double min, double max, double val)
{
    return MAX(min, MIN(max, val));
}

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _kvo = [[BSKVOController alloc] initWithObservedObject:self];
    [self.view setBackgroundColor:[UIColor blackColor]];
    CGRect bounds = [self.view bounds];
    _transportBar = [[SimpleTransportBar alloc] initWithFrame:CGRectMake(90.0, CGRectGetMaxY(bounds)-100.0, bounds.size.width-90.0*2, 20.0)];
    [_transportBar sizeToFit];
    [self.view addSubview:_transportBar];
    _scrubbingController = [[BSMomentumScrubbingController alloc] init];
    [self.view addGestureRecognizer:_scrubbingController.gestureRecognizer];
    [self.scrubbingController setEnabled:YES];

    [_kvo keyPath:@"scrubbingController.position" options:NSKeyValueObservingOptionInitial addObserver:^(id object, NSDictionary *changes) {
        if ([self.scrubbingController isEnabled]) {
            NSTimeInterval time = [self timeFromPosition:self.scrubbingController.position];
            if (fabs(self.transportBar.currentTime - time) > 0.5) {
                [self.transportBar setCurrentTime:time animating:NO];
            }
        }
    }];
}

- (NSTimeInterval)timeFromPosition:(CGPoint)position
{
    double f = position.x / self.transportBar.bounds.size.width;
    f = pinf(0.0, 1.0, f);
    return f * self.transportBar.duration;
}

- (CGPoint)positionFromTime:(NSTimeInterval)t
{
    assert(self.transportBar.duration > 0);
    double f = t / self.transportBar.duration;
    f = pinf(0.0, 1.0, f);
    return CGPointMake(f * self.transportBar.bounds.size.width, 0.0);
}

- (void)setScrubbing:(BOOL)scrubbing
{
    [self.scrubbingController setEnabled:scrubbing];
}
- (void)_moveTransportBar
{
    NSTimeInterval time = rand() % 3600;
    [self.transportBar setCurrentTime:time animating:YES];
    [_scrubbingController setPosition:[self positionFromTime:time]];
    [self performSelector:_cmd withObject:nil afterDelay:3.0];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [_scrubbingController setBounds:CGRectMake(0, 0, self.transportBar.bounds.size.width, 0.0)];
    [_scrubbingController setPosition:[self positionFromTime:self.transportBar.currentTime]];
}
@end
