//
//  KeepAlive.h — silent audio player to prevent iOS suspension
//  (Fl0rk KeepAlive* equivalent: AVAudioSession playback with muted
//  player keeps the process alive while the ESP overlay is active,
//  even when the app is in the background drawing over the game.)
//
#ifndef KeepAlive_h
#define KeepAlive_h

#import <Foundation/Foundation.h>

@interface KeepAlive : NSObject
+ (instancetype)shared;
// start silent-audio keepalive; call when ESP overlay turns on
- (void)start;
// stop; call when ESP overlay turns off
- (void)stop;
- (BOOL)running;
@end

#endif /* KeepAlive_h */
