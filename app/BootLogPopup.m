//
//  BootLogPopup.m — Fl0rk-style boot console popup
//  Dark card, green monospace text, drag-to-dismiss not needed (auto).
//
#import "BootLogPopup.h"

@implementation BootLogPopup {
    UITextView *_tv;
    NSMutableString *_text;
}

+ (instancetype)shared {
    static BootLogPopup *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [BootLogPopup new]; });
    return s;
}

+ (void)show {
    BootLogPopup *p = [self shared];
    if (p.superview) return;

    UIWindow *window = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            window = scene.windows.firstObject;
            break;
        }
    }
    if (!window) window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;

    CGFloat w = 300, h = 380;
    p.frame = CGRectMake((window.bounds.size.width - w) / 2,
                         (window.bounds.size.height - h) / 2, w, h);
    p.layer.cornerRadius = 14;
    p.layer.shadowOpacity = 0.5;
    p.layer.shadowRadius = 20;
    p.alpha = 0;
    [window addSubview:p];
    [UIView animateWithDuration:0.25 animations:^{ p.alpha = 1; }];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.02 alpha:0.97];

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 200, 18)];
        title.text = @"@MINHDUC";
        title.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold];
        title.textColor = [UIColor whiteColor];
        [self addSubview:title];

        UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(14, 30, 270, 14)];
        sub.text = @"External for Free Fire";
        sub.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
        sub.textColor = [UIColor colorWithWhite:0.6 alpha:1];
        [self addSubview:sub];

        _text = [NSMutableString new];
        _tv = [[UITextView alloc] initWithFrame:CGRectMake(10, 52, frame.size.width - 20, frame.size.height - 64)];
        _tv.editable = NO;
        _tv.scrollEnabled = YES;
        _tv.backgroundColor = [UIColor clearColor];
        _tv.font = [UIFont monospacedSystemFontOfSize:9.5 weight:UIFontWeightRegular];
        _tv.textColor = [UIColor colorWithRed:0.55 green:0.95 blue:0.6 alpha:1];
        [self addSubview:_tv];
    }
    return self;
}

- (void)appendLine:(NSString *)line {
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_source_t source;
        static dispatch_once_t once;
        (void)once;
        [self->_text appendFormat:@"%@\n", line];
        self->_tv.text = self->_text;
        [self->_tv scrollRangeToVisible:NSMakeRange(self->_text.length, 0)];
    });
}

- (void)dismissAfter:(NSTimeInterval)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{ self.alpha = 0; }
            completion:^(BOOL finished) { [self removeFromSuperview]; }];
    });
}

@end
