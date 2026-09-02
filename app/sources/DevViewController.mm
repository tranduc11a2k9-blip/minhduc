#import "DevViewController.h"
#import "MDTheme.h"
#import "AppSettingsViewController.h"
#import "roothide/varCleanController.h"
#import <SafariServices/SafariServices.h>
#import <objc/runtime.h>

static const void *kDevSocialURLKey = &kDevSocialURLKey;

// Dev profile — edit links/name here.
static NSString *const kDevName = @"Bola Minh Đức";
static NSString *const kDevTagline = @"Công việc · ib Telegram";
static NSString *const kDevZalo = @"https://zalo.me/";
static NSString *const kDevFacebook = @"https://facebook.com/";
static NSString *const kDevTelegram = @"https://t.me/";
static NSString *const kDevTikTok = @"https://www.tiktok.com/";

@interface DevViewController ()
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *content;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *settingsBtn;
@property (nonatomic, strong) UIButton *trashBtn;
@property (nonatomic, strong) UIView *profileCard;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *tagLabel;
@property (nonatomic, strong) NSArray<UIButton *> *socialBtns;
@property (nonatomic, strong) UIView *infoCard;
@property (nonatomic, strong) NSArray<UILabel *> *infoLeft;
@property (nonatomic, strong) NSArray<UILabel *> *infoRight;
@end

@implementation DevViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    MDThemeLoadFromPrefs();

    _scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scroll.alwaysBounceVertical = YES;
    _scroll.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scroll];
    _content = [[UIView alloc] initWithFrame:CGRectZero];
    [_scroll addSubview:_content];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.text = @"Dev";
    _titleLabel.font = MDThemeFont(30, UIFontWeightBold);
    [_content addSubview:_titleLabel];

    _settingsBtn = MDThemeMakeSettingsButton(self, @selector(openSettings));
    _trashBtn = MDThemeMakeTrashButton(self, @selector(openVarClean));
    [self.view addSubview:_settingsBtn];
    [self.view addSubview:_trashBtn];

    _profileCard = MDThemeMakeCard();
    [_content addSubview:_profileCard];

    _avatarView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _avatarView.contentMode = UIViewContentModeScaleAspectFill;
    _avatarView.clipsToBounds = YES;
    _avatarView.layer.cornerRadius = 36;
    _avatarView.layer.borderWidth = 2;
    UIImage *av = [UIImage imageNamed:@"logo"] ?: [UIImage imageNamed:@"ff"];
    if (!av) {
        // Placeholder circle
        _avatarView.backgroundColor = MDThemeAccentSoft(0.35f);
    } else {
        _avatarView.image = av;
    }
    [_profileCard addSubview:_avatarView];

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.text = kDevName;
    _nameLabel.font = MDThemeFont(20, UIFontWeightBold);
    [_profileCard addSubview:_nameLabel];

    _tagLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _tagLabel.text = kDevTagline;
    _tagLabel.font = MDThemeFont(12, UIFontWeightMedium);
    _tagLabel.numberOfLines = 2;
    [_profileCard addSubview:_tagLabel];

    NSArray *socials = @[
        @[ @"Zalo", kDevZalo, @"message.fill" ],
        @[ @"Facebook", kDevFacebook, @"f.circle.fill" ],
        @[ @"Telegram", kDevTelegram, @"paperplane.fill" ],
        @[ @"TikTok", kDevTikTok, @"music.note" ],
    ];
    NSMutableArray *btns = [NSMutableArray array];
    for (NSArray *s in socials) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.layer.cornerRadius = 14;
        b.layer.borderWidth = 1;
        b.titleLabel.font = MDThemeFont(14, UIFontWeightSemibold);
        [b setTitle:s[0] forState:UIControlStateNormal];
        b.accessibilityHint = s[1];
        objc_setAssociatedObject(b, kDevSocialURLKey, s[1], OBJC_ASSOCIATION_COPY_NONATOMIC);
        [b addTarget:self action:@selector(socialTapped:) forControlEvents:UIControlEventTouchUpInside];
        if (@available(iOS 13.0, *)) {
            UIImage *img = [UIImage systemImageNamed:s[2]];
            if (img) {
                [b setImage:img forState:UIControlStateNormal];
                b.imageEdgeInsets = UIEdgeInsetsMake(0, -6, 0, 0);
                b.titleEdgeInsets = UIEdgeInsetsMake(0, 6, 0, 0);
            }
        }
        [_content addSubview:b];
        [btns addObject:b];
    }
    _socialBtns = btns;

    // Build info (moved from Info tab)
    _infoCard = MDThemeMakeCard();
    [_content addSubview:_infoCard];
    NSDictionary *info = [NSBundle mainBundle].infoDictionary ?: @{};
    NSString *bundleName = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: @"—";
    NSString *bundleID = info[@"CFBundleIdentifier"] ?: @"—";
    NSString *shortVer = info[@"CFBundleShortVersionString"] ?: @"—";
    NSString *buildVer = info[@"CFBundleVersion"] ?: @"—";
    NSArray *pairs = @[
        @[ @"Build Name", bundleName ],
        @[ @"Build Number", buildVer ],
        @[ @"Product ID", bundleID ],
        @[ @"Version", shortVer ],
    ];
    NSMutableArray *L = [NSMutableArray array];
    NSMutableArray *R = [NSMutableArray array];
    for (NSArray *p in pairs) {
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
        l.text = p[0];
        l.font = MDThemeFont(13, UIFontWeightMedium);
        [_infoCard addSubview:l];
        [L addObject:l];
        UILabel *r = [[UILabel alloc] initWithFrame:CGRectZero];
        r.text = p[1];
        r.font = MDThemeFont(13, UIFontWeightRegular);
        r.textAlignment = NSTextAlignmentRight;
        r.adjustsFontSizeToFitWidth = YES;
        [_infoCard addSubview:r];
        [R addObject:r];
    }
    _infoLeft = L;
    _infoRight = R;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme)
                                                 name:MDThemeDidChangeNotification
                                               object:nil];
    [self applyTheme];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applyTheme {
    MDThemeLoadFromPrefs();
    self.view.backgroundColor = MDThemeBg();
    _titleLabel.textColor = MDThemeText();
    _profileCard.backgroundColor = MDThemePanel();
    _profileCard.layer.borderColor = MDThemeLine().CGColor;
    _avatarView.layer.borderColor = MDThemeAccent().CGColor;
    _nameLabel.textColor = MDThemeText();
    _tagLabel.textColor = MDThemeMuted();
    _infoCard.backgroundColor = MDThemePanel();
    _infoCard.layer.borderColor = MDThemeLine().CGColor;
    for (UILabel *l in _infoLeft) l.textColor = MDThemeText();
    for (UILabel *r in _infoRight) r.textColor = MDThemeMuted();
    for (UIButton *b in _socialBtns) {
        b.backgroundColor = MDThemePanel2();
        b.layer.borderColor = MDThemeLine().CGColor;
        [b setTitleColor:MDThemeText() forState:UIControlStateNormal];
        b.tintColor = MDThemeAccent();
    }
    _settingsBtn.backgroundColor = MDThemePanel2();
    _settingsBtn.layer.borderColor = MDThemeLine().CGColor;
    _settingsBtn.tintColor = MDThemeText();
    _trashBtn.backgroundColor = MDThemePanel2();
    _trashBtn.layer.borderColor = MDThemeLine().CGColor;
    _trashBtn.tintColor = MDThemeText();
    if (self.tabBarController) MDThemeApplyToTabBar(self.tabBarController.tabBar);
}

- (void)openSettings {
    AppSettingsViewController *vc = [[AppSettingsViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)openVarClean {
    varCleanController *vc = [varCleanController sharedInstance];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)socialTapped:(UIButton *)sender {
    NSString *urlStr = objc_getAssociatedObject(sender, kDevSocialURLKey);
    if (!urlStr.length) return;
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) return;
    if (@available(iOS 9.0, *)) {
        SFSafariViewController *svc = [[SFSafariViewController alloc] initWithURL:url];
        [self presentViewController:svc animated:YES completion:nil];
    } else {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets in = self.view.safeAreaInsets;
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    _scroll.frame = self.view.bounds;

    CGFloat gear = 36;
    _settingsBtn.frame = CGRectMake(w - in.right - 16 - gear, in.top + 8, gear, gear);
    _trashBtn.frame = CGRectMake(CGRectGetMinX(_settingsBtn.frame) - 10 - gear, in.top + 8, gear, gear);

    CGFloat pad = 16;
    CGFloat y = in.top + 52;
    _titleLabel.frame = CGRectMake(pad + 4, y, w - pad * 2 - 80, 36);
    y = CGRectGetMaxY(_titleLabel.frame) + 16;

    CGFloat cardW = w - pad * 2;
    _profileCard.frame = CGRectMake(pad, y, cardW, 110);
    _avatarView.frame = CGRectMake(16, 19, 72, 72);
    _nameLabel.frame = CGRectMake(104, 28, cardW - 120, 28);
    _tagLabel.frame = CGRectMake(104, 58, cardW - 120, 32);
    y = CGRectGetMaxY(_profileCard.frame) + 14;

    CGFloat gap = 10;
    CGFloat btnW = (cardW - gap) * 0.5f;
    CGFloat btnH = 48;
    for (NSUInteger i = 0; i < _socialBtns.count; i++) {
        NSUInteger col = i % 2;
        NSUInteger row = i / 2;
        CGFloat bx = pad + col * (btnW + gap);
        CGFloat by = y + row * (btnH + gap);
        _socialBtns[i].frame = CGRectMake(bx, by, btnW, btnH);
    }
    y += 2 * (btnH + gap) + 8;

    CGFloat rowH = 44;
    CGFloat infoH = rowH * _infoLeft.count;
    _infoCard.frame = CGRectMake(pad, y, cardW, infoH);
    for (NSUInteger i = 0; i < _infoLeft.count; i++) {
        _infoLeft[i].frame = CGRectMake(16, i * rowH, cardW * 0.38f, rowH);
        _infoRight[i].frame = CGRectMake(cardW * 0.40f, i * rowH, cardW * 0.55f - 16, rowH);
    }
    y = CGRectGetMaxY(_infoCard.frame) + 28 + in.bottom;

    _content.frame = CGRectMake(0, 0, w, MAX(y, h));
    _scroll.contentSize = _content.bounds.size;
}

@end
