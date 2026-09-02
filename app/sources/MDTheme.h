#import <UIKit/UIKit.h>

// Shared app + menu chrome theme (prefs: AppThemeMode, AppAccentMode, AppAccentColorR/G/B).
// Matches ModMenuViewController tokens so tipa home/settings look like the in-game menu.

#ifdef __cplusplus
extern "C" {
#endif

extern NSString * const MDThemeDidChangeNotification;

void MDThemeLoadFromPrefs(void);
void MDThemeNotifyChanged(void);

BOOL MDThemeIsLight(void);
int MDThemeAccentMode(void); // 0 default mint, 1 custom

UIColor *MDThemeBg(void);
UIColor *MDThemePanel(void);
UIColor *MDThemePanel2(void);
UIColor *MDThemeLine(void);
UIColor *MDThemeText(void);
UIColor *MDThemeMuted(void);
UIColor *MDThemeAccent(void);
UIColor *MDThemeAccentSoft(CGFloat alpha);
UIColor *MDThemeBlue(void);
UIColor *MDThemeOrange(void);
UIColor *MDThemeRed(void);

UIFont *MDThemeFont(CGFloat size, UIFontWeight weight);

// Default mint (same as menu).
extern const float kMDThemeDefaultAccentR;
extern const float kMDThemeDefaultAccentG;
extern const float kMDThemeDefaultAccentB;

// Style a UITabBarController to match MD theme.
void MDThemeApplyToTabBar(UITabBar *tabBar);

// Card helper
UIView *MDThemeMakeCard(void);

// Top-right settings gear (appearance sheet). Caller owns returned button if needed.
UIButton *MDThemeMakeSettingsButton(id target, SEL action);
// Top-corner trash (VarClean).
UIButton *MDThemeMakeTrashButton(id target, SEL action);

#ifdef __cplusplus
}
#endif
