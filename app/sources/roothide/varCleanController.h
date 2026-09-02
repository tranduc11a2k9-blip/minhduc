
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface varCleanController : UITableViewController

+ (instancetype)sharedInstance;

- (void)runVarCleanNowWithCompletion:(void (^ _Nullable)(BOOL authorized))completion;

@end

NS_ASSUME_NONNULL_END
