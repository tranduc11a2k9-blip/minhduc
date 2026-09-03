
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

// IOHIDEvent+KIF.m defines all HID types locally — real IOKit imports would
// conflict with its private typedefs/enums. Keep only the public interface.
typedef struct __IOHIDEvent * IOHIDEventRef;
IOHIDEventRef kif_IOHIDEventWithTouches(NSArray *touches) CF_RETURNS_RETAINED;
