#import <UIKit/UIKit.h>

// Block để xử lý hành động bật/tắt
typedef void (^ToggleActionBlock)(BOOL isOn);

@interface CustomToggleView : UIView

// Khởi tạo nút
- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title action:(ToggleActionBlock)action;

// Quản lý hiển thị giống menu.h
+ (instancetype)shared;
+ (void)showSpeedButton:(BOOL)show;
- (void)showMenu;
- (void)hideMenu;

// --- HỆ THỐNG XỬ LÝ CẢM ỨNG XUYÊN GAME (GIỐNG MENU.H) ---
- (BOOL)handleTouchAtWindowPoint:(CGPoint)windowPoint phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId;
- (BOOL)handleTouchAtLocalPoint:(CGPoint)localPoint phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId;

// Properties
@property (nonatomic, copy) ToggleActionBlock actionBlock;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISwitch *toggleSwitch;

@end

//button by @hatronghoann