#import "MDTheme.h"
#import "ESPPrefs.h"
#import <CoreText/CoreText.h>

NSString * const MDThemeDidChangeNotification = @"MDThemeDidChangeNotification";

const float kMDThemeDefaultAccentR = 0.208f;
const float kMDThemeDefaultAccentG = 0.827f;
const float kMDThemeDefaultAccentB = 0.604f;

static BOOL g_light = NO;
static int g_accentMode = 0;
static float g_ar = kMDThemeDefaultAccentR;
static float g_ag = kMDThemeDefaultAccentG;
static float g_ab = kMDThemeDefaultAccentB;

static void MDThemeRegisterFontsOnce(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *files = @[
            @"Inter-Regular.ttf", @"Inter-Medium.ttf", @"Inter-SemiBold.ttf", @"Inter-Bold.ttf",
            @"Font/Inter-Regular.ttf", @"Font/Inter-Medium.ttf", @"Font/Inter-SemiBold.ttf", @"Font/Inter-Bold.ttf"
        ];
        NSString *base = [[NSBundle mainBundle] bundlePath];
        for (NSString *rel in files) {
            NSString *path = [base stringByAppendingPathComponent:rel];
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) continue;
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (!data.length) continue;
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
            if (!provider) continue;
            CGFontRef font = CGFontCreateWithDataProvider(provider);
            CGDataProviderRelease(provider);
            if (!font) continue;
            CFErrorRef err = NULL;
            CTFontManagerRegisterGraphicsFont(font, &err);
            if (err) CFRelease(err);
            CGFontRelease(font);
        }
    });
}

void MDThemeLoadFromPrefs(void) {
    MDThemeRegisterFontsOnce();
    g_light = ESPPrefsBool(@"AppThemeMode", NO) ? YES : NO;
    g_accentMode = (int)ESPPrefsFloat(@"AppAccentMode", 0.0f);
    if (g_accentMode < 0) g_accentMode = 0;
    if (g_accentMode > 1) g_accentMode = 1;
    if (g_accentMode == 0) {
        g_ar = kMDThemeDefaultAccentR;
        g_ag = kMDThemeDefaultAccentG;
        g_ab = kMDThemeDefaultAccentB;
    } else {
        g_ar = ESPPrefsFloat(@"AppAccentColorR", kMDThemeDefaultAccentR);
        g_ag = ESPPrefsFloat(@"AppAccentColorG", kMDThemeDefaultAccentG);
        g_ab = ESPPrefsFloat(@"AppAccentColorB", kMDThemeDefaultAccentB);
        if (g_ar < 0) g_ar = 0; if (g_ar > 1) g_ar = 1;
        if (g_ag < 0) g_ag = 0; if (g_ag > 1) g_ag = 1;
        if (g_ab < 0) g_ab = 0; if (g_ab > 1) g_ab = 1;
    }
}

void MDThemeNotifyChanged(void) {
    MDThemeLoadFromPrefs();
    [[NSNotificationCenter defaultCenter] postNotificationName:MDThemeDidChangeNotification object:nil];
}

BOOL MDThemeIsLight(void) { return g_light; }
int MDThemeAccentMode(void) { return g_accentMode; }

UIColor *MDThemeBg(void) {
    return g_light
        ? [UIColor colorWithRed:0.945f green:0.953f blue:0.965f alpha:1.0f]
        : [UIColor colorWithRed:0.027f green:0.067f blue:0.114f alpha:1.0f];
}
UIColor *MDThemePanel(void) {
    return g_light
        ? [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.98f]
        : [UIColor colorWithRed:0.047f green:0.090f blue:0.145f alpha:0.98f];
}
UIColor *MDThemePanel2(void) {
    return g_light
        ? [UIColor colorWithRed:0.945f green:0.953f blue:0.965f alpha:0.98f]
        : [UIColor colorWithRed:0.071f green:0.122f blue:0.188f alpha:0.95f];
}
UIColor *MDThemeLine(void) {
    return g_light
        ? [UIColor colorWithWhite:0.0f alpha:0.10f]
        : [UIColor colorWithWhite:1.0f alpha:0.085f];
}
UIColor *MDThemeText(void) {
    return g_light
        ? [UIColor colorWithRed:0.08f green:0.10f blue:0.14f alpha:1.0f]
        : [UIColor colorWithRed:0.969f green:0.976f blue:1.0f alpha:1.0f];
}
UIColor *MDThemeMuted(void) {
    return g_light
        ? [UIColor colorWithRed:0.40f green:0.45f blue:0.52f alpha:1.0f]
        : [UIColor colorWithRed:0.533f green:0.580f blue:0.659f alpha:1.0f];
}
UIColor *MDThemeAccent(void) {
    return [UIColor colorWithRed:g_ar green:g_ag blue:g_ab alpha:1.0f];
}
UIColor *MDThemeAccentSoft(CGFloat alpha) {
    return [UIColor colorWithRed:g_ar green:g_ag blue:g_ab alpha:alpha];
}
UIColor *MDThemeBlue(void) { return [UIColor colorWithRed:0.220f green:0.741f blue:0.973f alpha:1.0f]; }
UIColor *MDThemeOrange(void) { return [UIColor colorWithRed:0.984f green:0.573f blue:0.235f alpha:1.0f]; }
UIColor *MDThemeRed(void) { return [UIColor colorWithRed:0.984f green:0.443f blue:0.522f alpha:1.0f]; }

UIFont *MDThemeFont(CGFloat size, UIFontWeight weight) {
    MDThemeRegisterFontsOnce();
    NSString *name = @"Inter-Regular";
    if (weight >= UIFontWeightBold) name = @"Inter-Bold";
    else if (weight >= UIFontWeightSemibold) name = @"Inter-SemiBold";
    else if (weight >= UIFontWeightMedium) name = @"Inter-Medium";
    UIFont *f = [UIFont fontWithName:name size:size];
    return f ?: [UIFont systemFontOfSize:size weight:weight];
}

void MDThemeApplyToTabBar(UITabBar *tabBar) {
    if (!tabBar) return;
    MDThemeLoadFromPrefs();
    tabBar.translucent = NO;
    tabBar.tintColor = MDThemeAccent();
    if ([tabBar respondsToSelector:@selector(setUnselectedItemTintColor:)]) {
        tabBar.unselectedItemTintColor = MDThemeMuted();
    }
    tabBar.barTintColor = MDThemePanel();
    tabBar.backgroundColor = MDThemePanel();
    // Avoid nested @available (needs __isOSVersionAtLeast on this toolchain).
    // UITabBarAppearance exists from iOS 13; use class check + KVC for scrollEdge.
    Class appearanceCls = NSClassFromString(@"UITabBarAppearance");
    if (appearanceCls) {
        id app = [[appearanceCls alloc] init];
        if ([app respondsToSelector:@selector(configureWithOpaqueBackground)]) {
            [app configureWithOpaqueBackground];
        }
        if ([app respondsToSelector:@selector(setBackgroundColor:)]) {
            [app setBackgroundColor:MDThemePanel()];
        }
        if ([app respondsToSelector:@selector(setShadowColor:)]) {
            [app setShadowColor:MDThemeLine()];
        }
        UIColor *sel = MDThemeAccent();
        UIColor *uns = MDThemeMuted();
        @try {
            id stacked = [app valueForKey:@"stackedLayoutAppearance"];
            id normal = [stacked valueForKey:@"normal"];
            id selected = [stacked valueForKey:@"selected"];
            [normal setValue:uns forKey:@"iconColor"];
            [normal setValue:@{ NSForegroundColorAttributeName: uns } forKey:@"titleTextAttributes"];
            [selected setValue:sel forKey:@"iconColor"];
            [selected setValue:@{ NSForegroundColorAttributeName: sel } forKey:@"titleTextAttributes"];
        } @catch (__unused NSException *e) {}
        if ([tabBar respondsToSelector:@selector(setStandardAppearance:)]) {
            [tabBar setValue:app forKey:@"standardAppearance"];
        }
        // iOS 15+ scrollEdgeAppearance — set via KVC if present.
        if ([tabBar respondsToSelector:NSSelectorFromString(@"setScrollEdgeAppearance:")]) {
            @try { [tabBar setValue:app forKey:@"scrollEdgeAppearance"]; } @catch (__unused NSException *e) {}
        }
    }
}

UIView *MDThemeMakeCard(void) {
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    card.backgroundColor = MDThemePanel();
    card.layer.cornerRadius = 16.0f;
    card.layer.borderWidth = 1.0f;
    card.layer.borderColor = MDThemeLine().CGColor;
    card.clipsToBounds = YES;
    return card;
}

static UIButton *MDThemeMakeRoundIconButton(NSString *systemName, id target, SEL action) {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.backgroundColor = MDThemePanel2();
    btn.layer.cornerRadius = 18.0f;
    btn.layer.borderWidth = 1.0f;
    btn.layer.borderColor = MDThemeLine().CGColor;
    btn.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        UIImage *img = [UIImage systemImageNamed:systemName withConfiguration:cfg];
        [btn setImage:img forState:UIControlStateNormal];
        btn.tintColor = MDThemeText();
    } else {
        [btn setTitle:([systemName containsString:@"trash"] ? @"🗑" : @"⚙") forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:16];
    }
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

UIButton *MDThemeMakeSettingsButton(id target, SEL action) {
    return MDThemeMakeRoundIconButton(@"gearshape.fill", target, action);
}

UIButton *MDThemeMakeTrashButton(id target, SEL action) {
    return MDThemeMakeRoundIconButton(@"trash.fill", target, action);
}
