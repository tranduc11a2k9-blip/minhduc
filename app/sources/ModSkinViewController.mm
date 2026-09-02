#import "ModSkinViewController.h"
#import "MDTheme.h"
#import "AppSettingsViewController.h"
#import "roothide/varCleanController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <MobileCoreServices/MobileCoreServices.h>

// Free Fire TH / MAX common data-container bundle IDs.
static NSString *const kFFBundleId    = @"vn.vng.freefireth";
static NSString *const kFFMaxBundleId = @"com.dts.freefiremax";

// Relative paths under <Data>/Documents/
static NSString *const kAvatarRel =
    @"Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles";
static NSString *const kWeaponRel =
    @"Documents/contentcache/Optional/ios/gameassetbundles";

typedef NS_ENUM(NSInteger, ModSkinGame) {
    ModSkinGameFF = 0,
    ModSkinGameFFMax = 1,
};

typedef NS_ENUM(NSInteger, ModSkinKind) {
    ModSkinKindAvatar = 0,
    ModSkinKindWeapon = 1,
};

@interface ModSkinViewController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UISegmentedControl *gameSeg;
@property (nonatomic, strong) UISegmentedControl *kindSeg;
@property (nonatomic, strong) UILabel *pathLabel;
@property (nonatomic, strong) UILabel *fileLabel;
@property (nonatomic, strong) UIButton *pickBtn;
@property (nonatomic, strong) UIButton *installBtn;
@property (nonatomic, strong) UIButton *restoreBtn;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *toastBanner;
@property (nonatomic, strong) UILabel *toastLabel;
@property (nonatomic, strong) UIActivityIndicatorView *busySpinner;
@property (nonatomic, assign) BOOL isBusy;

@property (nonatomic, strong) NSURL *pickedFileURL;
@property (nonatomic, assign) BOOL pickedNeedsStopAccess;
@property (nonatomic, strong) UIButton *settingsBtn;
@property (nonatomic, strong) UIButton *trashBtn;
@property (nonatomic, strong) UIView *mainCard;
@end

@implementation ModSkinViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    MDThemeLoadFromPrefs();
    self.view.backgroundColor = MDThemeBg();

    _scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.alwaysBounceVertical = YES;
    [self.view addSubview:_scroll];

    _settingsBtn = MDThemeMakeSettingsButton(self, @selector(openSettings));
    _trashBtn = MDThemeMakeTrashButton(self, @selector(openVarClean));
    [self.view addSubview:_settingsBtn];
    [self.view addSubview:_trashBtn];

    CGFloat w = self.view.bounds.size.width;
    CGFloat pad = 18.0f;
    CGFloat y = 56.0f;
    CGFloat contentW = w - pad * 2;

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, contentW, 36)];
    _titleLabel.text = @"Mod Skin";
    _titleLabel.font = MDThemeFont(30, UIFontWeightBold);
    _titleLabel.textColor = MDThemeText();
    [_scroll addSubview:_titleLabel];
    y += 40;

    _subLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, contentW, 18)];
    _subLabel.text = @"FF / FF MAX · Avatar · Weapon · 1 file / lần";
    _subLabel.font = MDThemeFont(12, UIFontWeightSemibold);
    _subLabel.textColor = MDThemeMuted();
    [_scroll addSubview:_subLabel];
    y += 32;

    // Card
    UIView *card = MDThemeMakeCard();
    card.frame = CGRectMake(pad, y, contentW, 420);
    card.tag = 9001;
    _mainCard = card;
    [_scroll addSubview:card];

    CGFloat cy = 16;
    CGFloat cw = contentW - 28;

    UILabel *gLbl = [self sectionLabel:@"1. Chọn game" frame:CGRectMake(14, cy, cw, 18)];
    [card addSubview:gLbl];
    cy += 26;

    _gameSeg = [[UISegmentedControl alloc] initWithItems:@[ @"Free Fire", @"Free Fire MAX" ]];
    _gameSeg.frame = CGRectMake(14, cy, cw, 34);
    _gameSeg.selectedSegmentIndex = 0;
    [_gameSeg addTarget:self action:@selector(selectionChanged) forControlEvents:UIControlEventValueChanged];
    [card addSubview:_gameSeg];
    cy += 48;

    UILabel *kLbl = [self sectionLabel:@"2. Loại skin" frame:CGRectMake(14, cy, cw, 18)];
    [card addSubview:kLbl];
    cy += 26;

    _kindSeg = [[UISegmentedControl alloc] initWithItems:@[ @"Nhân vật (Avatar)", @"Súng (Weapon)" ]];
    _kindSeg.frame = CGRectMake(14, cy, cw, 34);
    _kindSeg.selectedSegmentIndex = 0;
    [_kindSeg addTarget:self action:@selector(selectionChanged) forControlEvents:UIControlEventValueChanged];
    [card addSubview:_kindSeg];
    cy += 48;

    UILabel *pTitle = [self sectionLabel:@"3. Thư mục đích (tự tìm theo bundle id)" frame:CGRectMake(14, cy, cw, 18)];
    [card addSubview:pTitle];
    cy += 24;

    _pathLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, cy, cw, 54)];
    _pathLabel.numberOfLines = 3;
    if (@available(iOS 13.0, *)) {
        _pathLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    } else {
        _pathLabel.font = [UIFont systemFontOfSize:10];
    }
    _pathLabel.textColor = MDThemeMuted();
    _pathLabel.text = @"—";
    [card addSubview:_pathLabel];
    cy += 62;

    UILabel *fTitle = [self sectionLabel:@"4. File (1 file / lần)" frame:CGRectMake(14, cy, cw, 18)];
    [card addSubview:fTitle];
    cy += 24;

    _fileLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, cy, cw, 36)];
    _fileLabel.numberOfLines = 2;
    _fileLabel.font = MDThemeFont(12, UIFontWeightMedium);
    _fileLabel.textColor = MDThemeText();
    _fileLabel.text = @"Chưa chọn file";
    [card addSubview:_fileLabel];
    cy += 44;

    _pickBtn = [self actionButton:@"Chọn file…" y:cy width:cw];
    [_pickBtn addTarget:self action:@selector(pickFileTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:_pickBtn];
    cy += 52;

    _installBtn = [self actionButton:@"Cài skin vào game" y:cy width:cw];
    _installBtn.backgroundColor = MDThemeAccent();
    [_installBtn addTarget:self action:@selector(installTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:_installBtn];
    cy += 52;

    _restoreBtn = [self actionButton:@"Khôi phục mặc định (xóa file đã mod)" y:cy width:cw];
    _restoreBtn.backgroundColor = MDThemeRed();
    [_restoreBtn addTarget:self action:@selector(restoreTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:_restoreBtn];
    cy += 52;

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, cy, cw, 64)];
    _statusLabel.numberOfLines = 0;
    _statusLabel.font = MDThemeFont(13, UIFontWeightSemibold);
    _statusLabel.textColor = MDThemeMuted();
    _statusLabel.text = @"Chọn file rồi nhấn Cài skin.";
    [card addSubview:_statusLabel];
    cy += 72;

    card.frame = CGRectMake(pad, y, contentW, cy + 8);
    _scroll.contentSize = CGSizeMake(w, CGRectGetMaxY(card.frame) + 40);

    // Fixed toast on the VC view (not inside scroll) so it cannot be missed/scrolled away.
    _toastBanner = [[UIView alloc] initWithFrame:CGRectMake(pad, 12, contentW, 0)];
    _toastBanner.backgroundColor = [UIColor colorWithRed:0.12 green:0.55 blue:0.32 alpha:0.96];
    _toastBanner.layer.cornerRadius = 12;
    _toastBanner.hidden = YES;
    _toastBanner.userInteractionEnabled = NO;
    _toastBanner.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_toastBanner];

    _toastLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, contentW - 24, 40)];
    _toastLabel.numberOfLines = 0;
    _toastLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    _toastLabel.textColor = [UIColor whiteColor];
    _toastLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_toastBanner addSubview:_toastLabel];

    if (@available(iOS 13.0, *)) {
        _busySpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    } else {
        _busySpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    }
    _busySpinner.hidesWhenStopped = YES;
    _busySpinner.center = CGPointMake(w * 0.5f, self.view.bounds.size.height * 0.45f);
    _busySpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:_busySpinner];

    [self selectionChanged];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme)
                                                 name:MDThemeDidChangeNotification
                                               object:nil];
    [self applyTheme];
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

- (void)applyTheme {
    MDThemeLoadFromPrefs();
    self.view.backgroundColor = MDThemeBg();
    _titleLabel.textColor = MDThemeText();
    _titleLabel.font = MDThemeFont(30, UIFontWeightBold);
    _subLabel.textColor = MDThemeMuted();
    _mainCard.backgroundColor = MDThemePanel();
    _mainCard.layer.borderColor = MDThemeLine().CGColor;
    _pathLabel.textColor = MDThemeMuted();
    _fileLabel.textColor = MDThemeText();
    _statusLabel.textColor = MDThemeMuted();
    _pickBtn.backgroundColor = MDThemePanel2();
    [_pickBtn setTitleColor:MDThemeText() forState:UIControlStateNormal];
    _installBtn.backgroundColor = MDThemeAccent();
    _restoreBtn.backgroundColor = MDThemeRed();
    if (@available(iOS 13.0, *)) {
        _gameSeg.selectedSegmentTintColor = MDThemeAccentSoft(0.35f);
        _kindSeg.selectedSegmentTintColor = MDThemeAccentSoft(0.35f);
        NSDictionary *attrs = @{ NSForegroundColorAttributeName: MDThemeText() };
        [_gameSeg setTitleTextAttributes:attrs forState:UIControlStateNormal];
        [_kindSeg setTitleTextAttributes:attrs forState:UIControlStateNormal];
    }
    for (UIView *sub in _mainCard.subviews) {
        if ([sub isKindOfClass:[UILabel class]] && sub != _pathLabel && sub != _fileLabel && sub != _statusLabel) {
            ((UILabel *)sub).textColor = MDThemeText();
        }
    }
    _settingsBtn.backgroundColor = MDThemePanel2();
    _settingsBtn.layer.borderColor = MDThemeLine().CGColor;
    _settingsBtn.tintColor = MDThemeText();
    _trashBtn.backgroundColor = MDThemePanel2();
    _trashBtn.layer.borderColor = MDThemeLine().CGColor;
    _trashBtn.tintColor = MDThemeText();
    if (self.tabBarController) MDThemeApplyToTabBar(self.tabBarController.tabBar);
}

- (UILabel *)sectionLabel:(NSString *)text frame:(CGRect)frame {
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.text = text;
    l.font = MDThemeFont(13, UIFontWeightBold);
    l.textColor = MDThemeText();
    return l;
}

- (UIButton *)actionButton:(NSString *)title y:(CGFloat)y width:(CGFloat)w {
    // Custom (not System) so title/background always render as set — System tint can hide feedback.
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = CGRectMake(14, y, w, 44);
    b.backgroundColor = MDThemePanel2();
    b.layer.cornerRadius = 12;
    b.layer.borderWidth = 1;
    b.layer.borderColor = MDThemeLine().CGColor;
    b.clipsToBounds = YES;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:MDThemeText() forState:UIControlStateNormal];
    [b setTitleColor:MDThemeMuted() forState:UIControlStateDisabled];
    [b setTitleColor:MDThemeMuted() forState:UIControlStateHighlighted];
    b.titleLabel.font = MDThemeFont(15, UIFontWeightSemibold);
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.minimumScaleFactor = 0.8f;
    return b;
}

- (UIViewController *)md_topPresenter {
    UIViewController *root = self.view.window.rootViewController ?: self.tabBarController ?: self.navigationController ?: self;
    UIViewController *top = root;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    return top ?: self;
}

- (void)setBusy:(BOOL)busy {
    _isBusy = busy;
    _pickBtn.enabled = !busy;
    _installBtn.enabled = !busy;
    _restoreBtn.enabled = !busy;
    _gameSeg.enabled = !busy;
    _kindSeg.enabled = !busy;
    if (busy) {
        [_busySpinner startAnimating];
        [self.view bringSubviewToFront:_busySpinner];
        [_installBtn setTitle:@"Đang cài…" forState:UIControlStateNormal];
    } else {
        [_busySpinner stopAnimating];
        [_installBtn setTitle:@"Cài skin vào game" forState:UIControlStateNormal];
    }
}

- (void)showToast:(NSString *)msg error:(BOOL)isError {
    if (msg.length == 0) return;
    _toastLabel.text = msg;
    CGFloat w = self.view.bounds.size.width;
    CGFloat pad = 18.0f;
    CGFloat contentW = MAX(120.0f, w - pad * 2);
    CGSize sz = [_toastLabel sizeThatFits:CGSizeMake(contentW - 24, 200)];
    CGFloat h = MAX(44.0f, sz.height + 20.0f);
    CGFloat topSafe = 12.0f;
    if (@available(iOS 11.0, *)) {
        topSafe = MAX(12.0f, self.view.safeAreaInsets.top + 6.0f);
    }
    _toastBanner.frame = CGRectMake(pad, topSafe, contentW, h);
    _toastLabel.frame = CGRectMake(12, 10, contentW - 24, h - 20);
    _toastBanner.backgroundColor = isError
        ? [UIColor colorWithRed:0.72 green:0.18 blue:0.16 alpha:0.96]
        : [UIColor colorWithRed:0.12 green:0.55 blue:0.32 alpha:0.96];
    _toastBanner.hidden = NO;
    _toastBanner.alpha = 0;
    [self.view bringSubviewToFront:_toastBanner];
    [UIView animateWithDuration:0.18 animations:^{ self->_toastBanner.alpha = 1; }];

    // Auto-hide only success after a few seconds; keep errors longer.
    NSTimeInterval hideAfter = isError ? 8.0 : 5.0;
    NSInteger token = (NSInteger)(_toastBanner.tag + 1);
    _toastBanner.tag = token;
    __weak __typeof(self) wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(hideAfter * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (!wself || wself.toastBanner.tag != token) return;
        [UIView animateWithDuration:0.25 animations:^{
            wself.toastBanner.alpha = 0;
        } completion:^(__unused BOOL finished) {
            if (wself.toastBanner.tag == token) wself.toastBanner.hidden = YES;
        }];
    });
}

#pragma mark - Bundle / path helpers

- (NSString *)selectedBundleId {
    return (_gameSeg.selectedSegmentIndex == ModSkinGameFFMax) ? kFFMaxBundleId : kFFBundleId;
}

- (NSString *)relativeSkinFolder {
    return (_kindSeg.selectedSegmentIndex == ModSkinKindWeapon) ? kWeaponRel : kAvatarRel;
}

/// Read MCM metadata plist inside a data container UUID folder.
- (NSString *)bundleIdForDataContainerAtPath:(NSString *)containerPath {
    NSString *metaPath = [containerPath stringByAppendingPathComponent:
                          @".com.apple.mobile_container_manager.metadata.plist"];
    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
    if (![meta isKindOfClass:[NSDictionary class]]) return nil;
    id bid = meta[@"MCMMetadataIdentifier"];
    if ([bid isKindOfClass:[NSString class]] && [(NSString *)bid length] > 0) {
        return (NSString *)bid;
    }
    // Some firmwares nest identifier.
    id alt = meta[@"com.apple.MobileInstallation.BundleIdentifier"];
    if ([alt isKindOfClass:[NSString class]]) return (NSString *)alt;
    return nil;
}

/// Scan /var/mobile/Containers/Data/Application for the game data container.
/// probeRelativePath is optional fallback path under the container (thread-safe; no UI access).
- (NSString *)dataContainerPathForBundleId:(NSString *)bundleId
                        probeRelativePath:(NSString *)probeRelativePath {
    if (bundleId.length == 0) return nil;
    NSString *root = @"/var/mobile/Containers/Data/Application";
    NSError *err = nil;
    NSArray *uuids = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:&err];
    if (err || uuids.count == 0) {
        // Alternate rootless / older layout
        root = @"/private/var/mobile/Containers/Data/Application";
        uuids = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:&err];
    }
    if (uuids.count == 0) return nil;

    for (NSString *uuid in uuids) {
        if ([uuid hasPrefix:@"."]) continue;
        NSString *container = [root stringByAppendingPathComponent:uuid];
        BOOL isDir = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:container isDirectory:&isDir] || !isDir) {
            continue;
        }
        NSString *bid = [self bundleIdForDataContainerAtPath:container];
        if (bid && [bid caseInsensitiveCompare:bundleId] == NSOrderedSame) {
            return container;
        }
    }

    // Fallback: find by known contentcache structure (if metadata unreadable).
    NSString *probeTail = probeRelativePath.length ? probeRelativePath : nil;
    if (!probeTail) return nil;
    for (NSString *uuid in uuids) {
        if ([uuid hasPrefix:@"."]) continue;
        NSString *container = [root stringByAppendingPathComponent:uuid];
        NSString *docs = [container stringByAppendingPathComponent:@"Documents/contentcache"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:docs]) {
            // Prefer container that already has the target folder or parent contentcache/Optional/ios
            NSString *target = [container stringByAppendingPathComponent:probeTail];
            NSString *iosRoot = [container stringByAppendingPathComponent:@"Documents/contentcache/Optional/ios"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:target] ||
                [[NSFileManager defaultManager] fileExistsAtPath:iosRoot]) {
                // Heuristic only when single match — still verify bundle if possible
                NSString *bid = [self bundleIdForDataContainerAtPath:container];
                if (!bid || [bid.lowercaseString containsString:@"freefire"]) {
                    if (!bid || [bid caseInsensitiveCompare:bundleId] == NSOrderedSame ||
                        ([bundleId containsString:@"max"] && [bid.lowercaseString containsString:@"max"]) ||
                        (![bundleId containsString:@"max"] && ![bid.lowercaseString containsString:@"max"])) {
                        return container;
                    }
                }
            }
        }
    }
    return nil;
}

- (NSString *)dataContainerPathForBundleId:(NSString *)bundleId {
    return [self dataContainerPathForBundleId:bundleId probeRelativePath:[self relativeSkinFolder]];
}

- (NSString *)destinationDirectoryPath {
    NSString *container = [self dataContainerPathForBundleId:[self selectedBundleId]
                                          probeRelativePath:[self relativeSkinFolder]];
    if (!container) return nil;
    return [container stringByAppendingPathComponent:[self relativeSkinFolder]];
}

/// Prefs key tracking files this app installed (per game + kind).
- (NSString *)installedListPrefsKey {
    NSString *game = (_gameSeg.selectedSegmentIndex == ModSkinGameFFMax) ? @"ffmax" : @"ff";
    NSString *kind = (_kindSeg.selectedSegmentIndex == ModSkinKindWeapon) ? @"weapon" : @"avatar";
    return [NSString stringWithFormat:@"ModSkinInstalled_%@_%@", game, kind];
}

- (NSArray<NSString *> *)installedFileNames {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:[self installedListPrefsKey]];
    if (![arr isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *out = [NSMutableArray array];
    for (id o in arr) {
        if ([o isKindOfClass:[NSString class]] && [(NSString *)o length] > 0) {
            [out addObject:o];
        }
    }
    return out;
}

- (void)rememberInstalledFileName:(NSString *)name {
    if (name.length == 0) return;
    NSMutableArray *arr = [[self installedFileNames] mutableCopy];
    if (![arr containsObject:name]) {
        [arr addObject:name];
        [[NSUserDefaults standardUserDefaults] setObject:arr forKey:[self installedListPrefsKey]];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)clearInstalledList {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self installedListPrefsKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/// Files that look like mod packs (optionalab_avatar_* / optionalab_weapon_*).
- (NSArray<NSString *> *)modLikeFileNamesInDirectory:(NSString *)dir {
    if (dir.length == 0) return @[];
    NSError *err = nil;
    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:&err];
    if (err || items.count == 0) return @[];
    BOOL weapon = (_kindSeg.selectedSegmentIndex == ModSkinKindWeapon);
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *name in items) {
        if ([name hasPrefix:@"."]) continue;
        NSString *lower = name.lowercaseString;
        if (weapon) {
            if ([lower containsString:@"optionalab_weapon"] || [lower containsString:@"weapon_"]) {
                [out addObject:name];
            }
        } else {
            if ([lower containsString:@"optionalab_avatar"] || [lower containsString:@"avatar_"]) {
                [out addObject:name];
            }
        }
    }
    return out;
}

/// Update path label only — does NOT clear status (install/restore need to keep feedback).
- (void)refreshDestinationPathLabel {
    NSString *dst = [self destinationDirectoryPath];
    if (dst) {
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:dst];
        NSUInteger tracked = [self installedFileNames].count;
        _pathLabel.text = [NSString stringWithFormat:@"%@\n%@ · đã ghi nhận %lu file mod",
                           dst,
                           exists ? @"(thư mục đã có)" : @"(sẽ tạo nếu chưa có)",
                           (unsigned long)tracked];
        _pathLabel.textColor = [UIColor colorWithWhite:1 alpha:0.75];
    } else {
        _pathLabel.text = [NSString stringWithFormat:
                           @"Không tìm thấy container của %@.\nCài game, mở 1 lần, rồi thử lại (cần TrollStore/JB + quyền file).",
                           [self selectedBundleId]];
        _pathLabel.textColor = [UIColor colorWithRed:1 green:0.55 blue:0.45 alpha:1];
    }
}

- (void)selectionChanged {
    [self refreshDestinationPathLabel];
    // Don't wipe status while an install is in flight, or right after a result.
    if (!_isBusy) {
        _statusLabel.text = @"Chọn file rồi nhấn Cài skin.";
        _statusLabel.textColor = [UIColor colorWithWhite:1 alpha:0.75];
    }
}

#pragma mark - Picker / install

- (void)clearPickedFile {
    if (_pickedNeedsStopAccess && _pickedFileURL) {
        [_pickedFileURL stopAccessingSecurityScopedResource];
    }
    _pickedNeedsStopAccess = NO;
    _pickedFileURL = nil;
    _fileLabel.text = @"Chưa chọn file";
}

- (void)pickFileTapped {
    [self clearPickedFile];

    UIDocumentPickerViewController *picker = nil;
    if (@available(iOS 14.0, *)) {
        // Public item = any file (skin packs often have no/odd extension).
        NSArray *types = @[
            UTTypeItem,
            UTTypeData,
            UTTypeContent,
        ];
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    } else {
        picker = [[UIDocumentPickerViewController alloc]
                  initWithDocumentTypes:@[ @"public.item", @"public.data", @"public.content" ]
                  inMode:UIDocumentPickerModeImport];
    }
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;
    if (urls.count == 0) return;
    NSURL *url = urls.firstObject;
    // asCopy:YES usually gives a non-security-scoped temp copy; still try access.
    BOOL ok = [url startAccessingSecurityScopedResource];
    _pickedNeedsStopAccess = ok;
    _pickedFileURL = url;
    _fileLabel.text = url.lastPathComponent ?: url.path;
    _statusLabel.text = @"Đã chọn 1 file. Nhấn Cài skin.";
    _statusLabel.textColor = [UIColor colorWithWhite:1 alpha:0.8];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    (void)controller;
}

- (void)installTapped {
    if (_isBusy) return;

    if (!_pickedFileURL) {
        [self showStatus:@"Hãy chọn 1 file trước." error:YES];
        return;
    }

    // Re-assert security-scoped access if picker held it (or if asCopy temp URL still needs it).
    if (!_pickedNeedsStopAccess) {
        if ([_pickedFileURL startAccessingSecurityScopedResource]) {
            _pickedNeedsStopAccess = YES;
        }
    }

    NSURL *srcURL = _pickedFileURL;
    NSString *name = srcURL.lastPathComponent;
    if (name.length == 0) {
        [self showStatus:@"Tên file không hợp lệ." error:YES];
        return;
    }

    NSInteger kindIndex = _kindSeg.selectedSegmentIndex;
    NSString *bundleId = [[self selectedBundleId] copy];
    NSString *relFolder = [[self relativeSkinFolder] copy];
    BOOL isWeapon = (kindIndex == ModSkinKindWeapon);

    // Immediate UI feedback before any heavy work.
    [self setBusy:YES];
    [self showToast:@"Đang cài skin…" error:NO];
    _statusLabel.text = @"Đang cài skin…";
    _statusLabel.textColor = [UIColor colorWithWhite:1 alpha:0.9];

    __weak __typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        ModSkinViewController *sself = wself;
        if (!sself) return;

        // Resolve destination on background (container scan can be slow). Thread-safe: no UI reads.
        NSString *container = [sself dataContainerPathForBundleId:bundleId probeRelativePath:relFolder];
        NSString *dstDir = container ? [container stringByAppendingPathComponent:relFolder] : nil;
        if (!dstDir) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself setBusy:NO];
                [wself showStatus:@"Không tìm thấy thư mục game. Mở game 1 lần rồi thử lại." error:YES];
                [wself refreshDestinationPathLabel];
            });
            return;
        }

        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *err = nil;
        if (![fm fileExistsAtPath:dstDir]) {
            if (![fm createDirectoryAtPath:dstDir withIntermediateDirectories:YES attributes:nil error:&err]) {
                NSString *msg = [NSString stringWithFormat:@"Không tạo được thư mục: %@",
                                 err.localizedDescription ?: @"unknown"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [wself setBusy:NO];
                    [wself showStatus:msg error:YES];
                });
                return;
            }
        }

        NSString *dstPath = [dstDir stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:dstPath]) {
            [fm removeItemAtPath:dstPath error:nil];
        }

        err = nil;
        BOOL copied = [fm copyItemAtURL:srcURL toURL:[NSURL fileURLWithPath:dstPath] error:&err];
        if (!copied) {
            err = nil;
            copied = [fm copyItemAtPath:srcURL.path toPath:dstPath error:&err];
        }
        if (!copied) {
            err = nil;
            NSData *data = [NSData dataWithContentsOfURL:srcURL options:NSDataReadingMappedIfSafe error:&err];
            if (!data) {
                data = [NSData dataWithContentsOfFile:srcURL.path options:NSDataReadingMappedIfSafe error:&err];
            }
            if (data) {
                err = nil;
                copied = [data writeToFile:dstPath options:NSDataWritingAtomic error:&err];
            }
        }

        if (!copied) {
            NSString *msg = [NSString stringWithFormat:@"Copy lỗi: %@", err.localizedDescription ?: @"unknown"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself setBusy:NO];
                [wself showStatus:msg error:YES];
            });
            return;
        }

        if (![fm fileExistsAtPath:dstPath]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself setBusy:NO];
                [wself showStatus:@"Copy xong nhưng không thấy file đích." error:YES];
            });
            return;
        }

        unsigned long long sz = [[fm attributesOfItemAtPath:dstPath error:nil] fileSize];
        NSString *kind = isWeapon ? @"súng" : @"nhân vật";
        NSString *okMsg = [NSString stringWithFormat:@"OK · mod %@ · %@ (%.1f KB)\nMở lại game để load skin.",
                           kind, name, sz / 1024.0];

        dispatch_async(dispatch_get_main_queue(), ^{
            ModSkinViewController *ui = wself;
            if (!ui) return;
            [ui setBusy:NO];
            [ui rememberInstalledFileName:name];
            [ui showStatus:okMsg error:NO];
            [ui refreshDestinationPathLabel];
        });
    });
}

#pragma mark - Restore default (delete installed mods)

- (void)restoreTapped {
    NSString *dstDir = [self destinationDirectoryPath];
    if (!dstDir) {
        [self showStatus:@"Không tìm thấy thư mục game để khôi phục." error:YES];
        [self refreshDestinationPathLabel];
        return;
    }

    NSString *kind = (_kindSeg.selectedSegmentIndex == ModSkinKindWeapon) ? @"súng" : @"nhân vật";
    NSString *game = (_gameSeg.selectedSegmentIndex == ModSkinGameFFMax) ? @"FF MAX" : @"FF";
    NSString *msg = [NSString stringWithFormat:
                     @"Xóa file mod %@ đã cài cho %@?\n\n"
                     @"• Ưu tiên xóa file app đã ghi nhận khi cài.\n"
                     @"• Nếu danh sách trống, xóa file dạng optionalab_%@_* trong thư mục đích.",
                     kind, game,
                     (_kindSeg.selectedSegmentIndex == ModSkinKindWeapon) ? @"weapon" : @"avatar"];

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Khôi phục mặc định"
                                            message:msg
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    __weak ModSkinViewController *wself = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Xóa file mod" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
        [wself performRestoreDefault];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performRestoreDefault {
    NSString *dstDir = [self destinationDirectoryPath];
    if (!dstDir) {
        [self showStatus:@"Không tìm thấy thư mục game." error:YES];
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *tracked = [self installedFileNames];
    NSArray<NSString *> *toDelete = tracked;

    // If we never tracked installs (old sessions / manual copy), fall back to name pattern.
    if (toDelete.count == 0) {
        toDelete = [self modLikeFileNamesInDirectory:dstDir];
    }

    if (toDelete.count == 0) {
        [self showStatus:@"Không có file mod nào để xóa trong thư mục này." error:YES];
        return;
    }

    NSUInteger removed = 0;
    NSUInteger failed = 0;
    NSMutableArray *stillThere = [NSMutableArray array];
    for (NSString *name in toDelete) {
        NSString *path = [dstDir stringByAppendingPathComponent:name];
        if (![fm fileExistsAtPath:path]) {
            continue; // already gone
        }
        NSError *err = nil;
        if ([fm removeItemAtPath:path error:&err]) {
            removed++;
        } else {
            failed++;
            [stillThere addObject:name];
        }
    }

    if (stillThere.count == 0) {
        [self clearInstalledList];
    } else {
        // Keep only files we failed to delete.
        [[NSUserDefaults standardUserDefaults] setObject:stillThere forKey:[self installedListPrefsKey]];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    if (failed > 0) {
        [self showStatus:[NSString stringWithFormat:@"Đã xóa %lu file, lỗi %lu (thiếu quyền?).",
                          (unsigned long)removed, (unsigned long)failed]
                   error:YES];
    } else {
        [self showStatus:[NSString stringWithFormat:@"Đã khôi phục · xóa %lu file mod.\nMở lại game để về skin gốc.",
                          (unsigned long)removed]
                   error:NO];
    }
    [self refreshDestinationPathLabel];
}

- (void)showStatus:(NSString *)msg error:(BOOL)isError {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showStatus:msg error:isError];
        });
        return;
    }
    if (msg.length == 0) {
        _statusLabel.text = @"";
        return;
    }
    _statusLabel.text = msg;
    _statusLabel.textColor = isError
        ? [UIColor colorWithRed:1 green:0.45 blue:0.40 alpha:1]
        : [UIColor colorWithRed:0.35 green:0.90 blue:0.55 alpha:1];

    // Fixed banner at top of screen — always visible even if status label is off-scroll.
    [self showToast:msg error:isError];

    // Ensure status is on-screen (card is tall; install result sits at bottom).
    if (_statusLabel.superview && _scroll) {
        CGRect r = [_statusLabel convertRect:_statusLabel.bounds toView:_scroll];
        [_scroll scrollRectToVisible:CGRectInset(r, 0, -24) animated:YES];
    }

    // Always surface a modal so "nhấn cài không hiện gì" cannot happen again.
    NSString *title = isError ? @"Cài skin lỗi" : @"Cài skin";
    NSString *lower = msg.lowercaseString;
    if ([lower containsString:@"khôi phục"] || [lower containsString:@"xóa"]) {
        title = isError ? @"Khôi phục lỗi" : @"Khôi phục";
    } else if ([msg containsString:@"Hãy chọn"] || [msg containsString:@"Không tìm thấy"]) {
        title = isError ? @"Chưa sẵn sàng" : @"Thông báo";
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:msg
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

    // Present from top-most VC (tab/nav/picker-dismiss edge cases).
    // After restore confirm, wait until prior modal finishes dismissing.
    __weak __typeof(self) wself = self;
    __block void (^presentWhenReady)(NSInteger) = nil;
    __weak __block void (^weakPresent)(NSInteger) = nil;
    presentWhenReady = ^(NSInteger triesLeft) {
        ModSkinViewController *sself = wself;
        if (!sself) {
            return;
        }
        UIViewController *host = [sself md_topPresenter];
        if (host && host.presentedViewController == nil) {
            [host presentViewController:alert animated:YES completion:nil];
            return;
        }
        // If host itself is already presenting something else that isn't us waiting, retry.
        if (triesLeft <= 0) {
            // Last-ditch: present on self anyway (may no-op if still blocked).
            if (sself.presentedViewController == nil) {
                [sself presentViewController:alert animated:YES completion:nil];
            }
            return;
        }
        void (^again)(NSInteger) = weakPresent;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (again) again(triesLeft - 1);
        });
    };
    weakPresent = presentWhenReady;
    presentWhenReady(40); // ~2s max wait for prior modal to finish dismissing
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self clearPickedFile];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _scroll.frame = self.view.bounds;
    UIEdgeInsets in = self.view.safeAreaInsets;
    CGFloat w = self.view.bounds.size.width;
    CGFloat gear = 36.0f;
    _settingsBtn.frame = CGRectMake(w - in.right - 16 - gear, in.top + 8, gear, gear);
    _trashBtn.frame = CGRectMake(CGRectGetMinX(_settingsBtn.frame) - 10 - gear, in.top + 8, gear, gear);

    UIView *card = [self.view viewWithTag:9001];
    if (!card) {
        // card is inside scroll
        for (UIView *v in _scroll.subviews) {
            if (v.tag == 9001) { card = v; break; }
        }
    }
    CGFloat pad = 18.0f;
    CGFloat contentW = w - pad * 2;
    if (card) {
        CGRect f = card.frame;
        f.origin.x = pad;
        f.size.width = contentW;
        card.frame = f;
        // reflow horizontal controls roughly
        for (UIView *sub in card.subviews) {
            if ([sub isKindOfClass:[UISegmentedControl class]] ||
                [sub isKindOfClass:[UIButton class]]) {
                CGRect sf = sub.frame;
                sf.origin.x = 14;
                sf.size.width = contentW - 28;
                sub.frame = sf;
            } else if ([sub isKindOfClass:[UILabel class]]) {
                CGRect sf = sub.frame;
                if (sf.origin.x >= 14) {
                    sf.size.width = contentW - 28;
                    sub.frame = sf;
                }
            }
        }
        _scroll.contentSize = CGSizeMake(w, CGRectGetMaxY(card.frame) + 40);
    }
}

@end
