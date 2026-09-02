//
//  KeepAlive.m — silent audio keepalive (Fl0rk-style)
//
//  iOS suspends background apps ~10s after backgrounding unless:
//  - an audio session with .playback category is ACTIVE, or
//  - a background task is held (limited time)
//
//  We do both:
//  1. AVAudioSession category .playback + silent PCM player looping
//  2. long-running UIBackgroundTask as belt & suspenders
//

#import "KeepAlive.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@implementation KeepAlive {
    AVAudioPlayer *_player;
    UIBackgroundTaskIdentifier _bgTask;
    BOOL _running;
}

+ (instancetype)shared {
    static KeepAlive *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [KeepAlive new]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    _bgTask = UIBackgroundTaskInvalid;
    return self;
}

- (BOOL)running { return _running; }

- (void)start {
    if (_running) return;
    _running = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        // 1. audio session: playback = background audio entitlement path
        NSError *err = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback
                        mode:AVAudioSessionModeDefault
                     options:AVAudioSessionCategoryOptionMixWithOthers
                       error:&err];
        [session setActive:YES error:&err];

        // 2. generate 1s of pure silence (PCM 16-bit mono 8kHz)
        NSUInteger sampleRate = 8000;
        NSUInteger samples    = sampleRate;          // 1 second
        NSUInteger byteCount  = samples * sizeof(int16_t);
        NSMutableData *silence = [NSMutableData dataWithCapacity:byteCount];
        int16_t zero = 0;
        for (NSUInteger i = 0; i < samples; i++)
            [silence appendBytes:&zero length:sizeof(zero)];

        NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ka.wav"];
        [silence writeToFile:tmp atomically:YES];
        NSURL *url = [NSURL fileURLWithPath:tmp];
        _player = [[AVAudioPlayer alloc] initWithContentsOfURL:url
                                                         error:&err];
        if (!_player) {
            // fallback: empty wav-shaped data through dataWithContentsOfURL
            NSLog(@"[KeepAlive] player init failed: %@", err);
        } else {
            _player.numberOfLoops = -1;   // infinite
            _player.volume = 0.01f;       // effectively silent
            [_player play];
        }

        // 3. background task as backup
        if (_bgTask == UIBackgroundTaskInvalid) {
            _bgTask = [[UIApplication sharedApplication]
                beginBackgroundTaskWithName:@"ESPKeepAlive"
                          expirationHandler:^{
                // near-expiry: restart to renew window
                [[UIApplication sharedApplication] endBackgroundTask:self->_bgTask];
                self->_bgTask = UIBackgroundTaskInvalid;
                if (self->_running) [self start];
            }];
        }

        NSLog(@"[KeepAlive] started");
    });
}

- (void)stop {
    if (!_running) return;
    _running = NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        [_player stop];
        _player = nil;
        [[AVAudioSession sharedInstance] setActive:NO
            withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                  error:nil];

        if (_bgTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
            _bgTask = UIBackgroundTaskInvalid;
        }

        NSLog(@"[KeepAlive] stopped");
    });
}

@end
