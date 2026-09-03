#import "MainApplicationDelegate.h"
#import "MainApplication.h"
#import "HomeViewController.h"
#import "ModSkinViewController.h"

#import "DevViewController.h"
#import "MDTheme.h"
#import "HUDHelper.h"
#import "ESPPrefs.h"

@implementation MainApplicationDelegate {
    HomeViewController *_homeViewController;
    UITabBarController *_tabController;
}

- (instancetype)init {
    self = [super init];
    return self;
}

- (void)themeDidChange {
    MDThemeLoadFromPrefs();
    self.window.backgroundColor = MDThemeBg();
    if (_tabController) MDThemeApplyToTabBar(_tabController.tabBar);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey,id> *)launchOptions {
    MDThemeLoadFromPrefs();

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = MDThemeBg();

    _homeViewController = [[HomeViewController alloc] init];
    ModSkinViewController *skinVC = [[ModSkinViewController alloc] init];
    DevViewController *devVC = [[DevViewController alloc] init];

    UINavigationController *homeNav =
        [[UINavigationController alloc] initWithRootViewController:_homeViewController];
    UINavigationController *skinNav =
        [[UINavigationController alloc] initWithRootViewController:skinVC];
    UINavigationController *devNav =
        [[UINavigationController alloc] initWithRootViewController:devVC];

    homeNav.navigationBarHidden = YES;
    skinNav.navigationBarHidden = YES;
    devNav.navigationBarHidden = YES;

    homeNav.view.userInteractionEnabled = YES;
    skinNav.view.userInteractionEnabled = YES;
    devNav.view.userInteractionEnabled = YES;

    if (@available(iOS 13.0, *)) {
        homeNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Home"
                                                           image:[UIImage systemImageNamed:@"house.fill"]
                                                             tag:0];
        skinNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Mod Skin"
                                                           image:[UIImage systemImageNamed:@"tshirt.fill"]
                                                             tag:1];
        if (!skinNav.tabBarItem.image) {
            skinNav.tabBarItem.image = [UIImage systemImageNamed:@"person.crop.rectangle"];
        }
        devNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Dev"
                                                          image:[UIImage systemImageNamed:@"person.crop.circle.fill"]
                                                            tag:2];
    } else {
        homeNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Home" image:nil tag:0];
        skinNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Mod Skin" image:nil tag:1];
        devNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Dev" image:nil tag:2];
    }

    UITabBarController *tab = [[UITabBarController alloc] init];
    tab.viewControllers = @[ homeNav, skinNav, devNav ];
    tab.selectedIndex = 0;
    tab.view.userInteractionEnabled = YES;
    tab.tabBar.userInteractionEnabled = YES;
    MDThemeApplyToTabBar(tab.tabBar);
    _tabController = tab;

    self.window.rootViewController = tab;
    [self.window makeKeyAndVisible];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeDidChange)
                                                 name:MDThemeDidChangeNotification
                                               object:nil];

    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    dispatch_async(dispatch_get_main_queue(), ^{
        ESPPrefsSync();
        MDThemeLoadFromPrefs();
        if (self->_tabController) MDThemeApplyToTabBar(self->_tabController.tabBar);
    });
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Undo the krw socket leak BEFORE the process dies — exiting with
    // so_usecount bumped astronomically high makes kernel zone teardown
    // panic → device respring ("reparting"). Restore makes exit clean.
    extern "C" void krw_sockets_restore(void);
    krw_sockets_restore();
}

@end
