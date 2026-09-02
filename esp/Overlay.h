#pragma once
#import <UIKit/UIKit.h>

@interface ESPOverlayView : UIView
@property (nonatomic, strong) NSArray *entities;
@end

@interface ESPOverlay : NSObject
+ (instancetype)shared;
- (void)start;
- (void)stop;
- (void)updateEntities:(NSArray *)entities;
@end
