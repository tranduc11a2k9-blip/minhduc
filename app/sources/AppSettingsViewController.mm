#import "AppSettingsViewController.h"
#import "MDTheme.h"
#import "ESPPrefs.h"
#include <math.h>

// Local draft only — prefs + MDThemeNotifyChanged only on Confirm.
// Theme/accent segment no longer writes prefs immediately (that closed/applied mid-edit).

@interface AppSettingsViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *themeLabel;
@property (nonatomic, strong) UISegmentedControl *themeSeg;
@property (nonatomic, strong) UILabel *accentLabel;
@property (nonatomic, strong) UISegmentedControl *accentSeg;
@property (nonatomic, strong) UIView *previewSwatch;
@property (nonatomic, strong) UILabel *previewLabel;
@property (nonatomic, strong) UIView *customBox;
@property (nonatomic, strong) UIImageView *spectrumView;
@property (nonatomic, strong) UIView *cursorView;
@property (nonatomic, strong) UILabel *rgbLabel;
@property (nonatomic, strong) UIButton *cancelBtn;
@property (nonatomic, strong) UIButton *confirmBtn;

// Draft (not saved until Confirm)
@property (nonatomic, assign) BOOL draftLight;
@property (nonatomic, assign) int draftAccentMode; // 0 default, 1 custom
@property (nonatomic, assign) float draftR;
@property (nonatomic, assign) float draftG;
@property (nonatomic, assign) float draftB;
@end

@implementation AppSettingsViewController

#pragma mark - Spectrum helpers (same mapping as menu color board)

static UIImage *ASSpectrumImage(void) {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const int W = 256, H = 160;
        unsigned char *rgba = (unsigned char *)calloc(W * H * 4, 1);
        if (!rgba) return;
        for (int y = 0; y < H; y++) {
            float v = (float)y / (float)(H - 1); // 0 top white-ish → 1 bottom black
            for (int x = 0; x < W; x++) {
                float hue = (float)x / (float)(W - 1); // 0..1
                // HSV: S increases from left-mid, V from top
                // Map like common pickers: X = hue, Y = value (1 top → 0 bottom), S fixed high with white top via mix
                float sat = 1.0f;
                float val = 1.0f - v;
                // Top row: blend toward white (sat→0)
                float topBlend = fmaxf(0.f, 1.f - v * 2.2f); // upper portion desaturates
                float s = sat * (1.f - topBlend);
                // HSV → RGB
                float hh = hue * 6.f;
                int i = (int)floorf(hh);
                float f = hh - i;
                float p = val * (1.f - s);
                float q = val * (1.f - s * f);
                float t = val * (1.f - s * (1.f - f));
                float rr = 0, gg = 0, bb = 0;
                switch (i % 6) {
                    case 0: rr = val; gg = t; bb = p; break;
                    case 1: rr = q; gg = val; bb = p; break;
                    case 2: rr = p; gg = val; bb = t; break;
                    case 3: rr = p; gg = q; bb = val; break;
                    case 4: rr = t; gg = p; bb = val; break;
                    default: rr = val; gg = p; bb = q; break;
                }
                int idx = (y * W + x) * 4;
                rgba[idx + 0] = (unsigned char)(rr * 255.f);
                rgba[idx + 1] = (unsigned char)(gg * 255.f);
                rgba[idx + 2] = (unsigned char)(bb * 255.f);
                rgba[idx + 3] = 255;
            }
        }
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate(rgba, W, H, 8, W * 4, cs, kCGImageAlphaPremultipliedLast);
        CGImageRef cg = ctx ? CGBitmapContextCreateImage(ctx) : NULL;
        if (cg) {
            img = [UIImage imageWithCGImage:cg scale:1.0 orientation:UIImageOrientationUp];
            CGImageRelease(cg);
        }
        if (ctx) CGContextRelease(ctx);
        if (cs) CGColorSpaceRelease(cs);
        free(rgba);
    });
    return img;
}

static void ASColorAtUV(float u, float v, float *outR, float *outG, float *outB) {
    if (u < 0) u = 0; if (u > 1) u = 1;
    if (v < 0) v = 0; if (v > 1) v = 1;
    float hue = u;
    float sat = 1.0f;
    float val = 1.0f - v;
    float topBlend = fmaxf(0.f, 1.f - v * 2.2f);
    float s = sat * (1.f - topBlend);
    float hh = hue * 6.f;
    int i = (int)floorf(hh);
    float f = hh - i;
    float p = val * (1.f - s);
    float q = val * (1.f - s * f);
    float t = val * (1.f - s * (1.f - f));
    float rr = 0, gg = 0, bb = 0;
    switch (i % 6) {
        case 0: rr = val; gg = t; bb = p; break;
        case 1: rr = q; gg = val; bb = p; break;
        case 2: rr = p; gg = val; bb = t; break;
        case 3: rr = p; gg = q; bb = val; break;
        case 4: rr = t; gg = p; bb = val; break;
        default: rr = val; gg = p; bb = q; break;
    }
    if (outR) *outR = rr;
    if (outG) *outG = gg;
    if (outB) *outB = bb;
}

// Approximate UV from RGB for cursor placement (hue from max channel, v from value).
static void ASUVFromRGB(float r, float g, float b, float *outU, float *outV) {
    float maxc = fmaxf(r, fmaxf(g, b));
    float minc = fminf(r, fminf(g, b));
    float delta = maxc - minc;
    float hue = 0.f;
    if (delta > 0.0001f) {
        if (maxc == r) hue = fmodf((g - b) / delta, 6.f);
        else if (maxc == g) hue = (b - r) / delta + 2.f;
        else hue = (r - g) / delta + 4.f;
        hue /= 6.f;
        if (hue < 0) hue += 1.f;
    }
    float val = maxc;
    float v = 1.f - val;
    if (outU) *outU = hue;
    if (outV) *outV = v;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // Snapshot current prefs into draft (edit without applying until Confirm).
    MDThemeLoadFromPrefs();
    _draftLight = MDThemeIsLight();
    _draftAccentMode = MDThemeAccentMode();
    _draftR = ESPPrefsFloat(@"AppAccentColorR", kMDThemeDefaultAccentR);
    _draftG = ESPPrefsFloat(@"AppAccentColorG", kMDThemeDefaultAccentG);
    _draftB = ESPPrefsFloat(@"AppAccentColorB", kMDThemeDefaultAccentB);

    self.view.backgroundColor = [UIColor clearColor];

    _dimView = [[UIView alloc] initWithFrame:CGRectZero];
    _dimView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45f];
    [self.view addSubview:_dimView];

    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cancelTapped)];
    bgTap.cancelsTouchesInView = NO;
    bgTap.delegate = self;
    [_dimView addGestureRecognizer:bgTap];

    _card = MDThemeMakeCard();
    _card.clipsToBounds = YES;
    _card.userInteractionEnabled = YES;
    [self.view addSubview:_card];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.text = @"Giao diện";
    _titleLabel.font = MDThemeFont(20, UIFontWeightBold);
    [_card addSubview:_titleLabel];

    _themeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _themeLabel.text = @"Chủ đề";
    _themeLabel.font = MDThemeFont(13, UIFontWeightMedium);
    [_card addSubview:_themeLabel];

    _themeSeg = [[UISegmentedControl alloc] initWithItems:@[ @"Tối", @"Sáng" ]];
    _themeSeg.selectedSegmentIndex = _draftLight ? 1 : 0;
    [_themeSeg addTarget:self action:@selector(themeSegChanged) forControlEvents:UIControlEventValueChanged];
    [_card addSubview:_themeSeg];

    _accentLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _accentLabel.text = @"Màu chủ đạo";
    _accentLabel.font = MDThemeFont(13, UIFontWeightMedium);
    [_card addSubview:_accentLabel];

    _accentSeg = [[UISegmentedControl alloc] initWithItems:@[ @"Mặc định", @"Tùy chỉnh" ]];
    _accentSeg.selectedSegmentIndex = _draftAccentMode == 1 ? 1 : 0;
    [_accentSeg addTarget:self action:@selector(accentSegChanged) forControlEvents:UIControlEventValueChanged];
    [_card addSubview:_accentSeg];

    _previewSwatch = [[UIView alloc] initWithFrame:CGRectZero];
    _previewSwatch.layer.cornerRadius = 8;
    _previewSwatch.layer.borderWidth = 1;
    [_card addSubview:_previewSwatch];

    _previewLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _previewLabel.font = MDThemeFont(13, UIFontWeightMedium);
    [_card addSubview:_previewLabel];

    _customBox = [[UIView alloc] initWithFrame:CGRectZero];
    _customBox.layer.cornerRadius = 12;
    _customBox.layer.borderWidth = 1;
    _customBox.clipsToBounds = YES;
    [_card addSubview:_customBox];

    _spectrumView = [[UIImageView alloc] initWithImage:ASSpectrumImage()];
    _spectrumView.contentMode = UIViewContentModeScaleToFill;
    _spectrumView.userInteractionEnabled = YES;
    _spectrumView.layer.cornerRadius = 10;
    _spectrumView.clipsToBounds = YES;
    _spectrumView.layer.borderWidth = 1;
    [_customBox addSubview:_spectrumView];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(spectrumGesture:)];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(spectrumGesture:)];
    [_spectrumView addGestureRecognizer:pan];
    [_spectrumView addGestureRecognizer:tap];

    _cursorView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 18, 18)];
    _cursorView.layer.cornerRadius = 9;
    _cursorView.layer.borderWidth = 2;
    _cursorView.layer.borderColor = [UIColor whiteColor].CGColor;
    _cursorView.userInteractionEnabled = NO;
    [_spectrumView addSubview:_cursorView];

    _rgbLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _rgbLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    _rgbLabel.textAlignment = NSTextAlignmentCenter;
    [_customBox addSubview:_rgbLabel];

    _cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _cancelBtn.layer.cornerRadius = 14;
    _cancelBtn.layer.borderWidth = 1;
    [_cancelBtn setTitle:@"Hủy" forState:UIControlStateNormal];
    _cancelBtn.titleLabel.font = MDThemeFont(15, UIFontWeightSemibold);
    [_cancelBtn addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:_cancelBtn];

    _confirmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _confirmBtn.layer.cornerRadius = 14;
    [_confirmBtn setTitle:@"Xác nhận" forState:UIControlStateNormal];
    [_confirmBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _confirmBtn.titleLabel.font = MDThemeFont(15, UIFontWeightBold);
    [_confirmBtn addTarget:self action:@selector(confirmTapped) forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:_confirmBtn];

    [self refreshCustomVisibility];
    [self updatePreviewFromDraft];
    [self recolorSheetChrome];
    [self updateCursorFromDraft];
}

#pragma mark - Gesture delegate: dim tap only (card touches never cancel)

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // Only dimView has the cancel tap; ignore if somehow hit card.
    UIView *v = touch.view;
    if (v == _card || [v isDescendantOfView:_card]) return NO;
    return YES;
}

#pragma mark - Draft edits (no prefs write)

- (void)themeSegChanged {
    _draftLight = (_themeSeg.selectedSegmentIndex == 1);
    // Preview sheet chrome only — do NOT write prefs / notify app yet.
    [self recolorSheetChrome];
}

- (void)accentSegChanged {
    _draftAccentMode = (int)_accentSeg.selectedSegmentIndex;
    [self refreshCustomVisibility];
    [self updatePreviewFromDraft];
    [self recolorSheetChrome];
    [self.view setNeedsLayout];
}

- (void)spectrumGesture:(UIGestureRecognizer *)gr {
    CGPoint p = [gr locationInView:_spectrumView];
    CGFloat w = _spectrumView.bounds.size.width;
    CGFloat h = _spectrumView.bounds.size.height;
    if (w < 1 || h < 1) return;
    float u = (float)(p.x / w);
    float v = (float)(p.y / h);
    float r, g, b;
    ASColorAtUV(u, v, &r, &g, &b);
    _draftR = r;
    _draftG = g;
    _draftB = b;
    _draftAccentMode = 1;
    if (_accentSeg.selectedSegmentIndex != 1) {
        _accentSeg.selectedSegmentIndex = 1;
        [self refreshCustomVisibility];
    }
    [self updatePreviewFromDraft];
    [self recolorSheetChrome];
    _cursorView.center = CGPointMake(MAX(9, MIN(w - 9, p.x)), MAX(9, MIN(h - 9, p.y)));
}

- (void)refreshCustomVisibility {
    BOOL custom = _draftAccentMode == 1;
    _customBox.hidden = !custom;
    _previewLabel.text = custom ? @"Màu tùy chỉnh" : @"Xanh mint (mặc định)";
}

- (UIColor *)draftAccentColor {
    if (_draftAccentMode == 0) {
        return [UIColor colorWithRed:kMDThemeDefaultAccentR green:kMDThemeDefaultAccentG blue:kMDThemeDefaultAccentB alpha:1];
    }
    return [UIColor colorWithRed:_draftR green:_draftG blue:_draftB alpha:1];
}

- (void)updatePreviewFromDraft {
    UIColor *acc = [self draftAccentColor];
    _previewSwatch.backgroundColor = acc;
    _rgbLabel.text = [NSString stringWithFormat:@"R %.0f   G %.0f   B %.0f",
                      (_draftAccentMode == 0 ? kMDThemeDefaultAccentR : _draftR) * 255.f,
                      (_draftAccentMode == 0 ? kMDThemeDefaultAccentG : _draftG) * 255.f,
                      (_draftAccentMode == 0 ? kMDThemeDefaultAccentB : _draftB) * 255.f];
    _confirmBtn.backgroundColor = acc;
}

- (void)updateCursorFromDraft {
    float u = 0.45f, v = 0.25f;
    if (_draftAccentMode == 1) {
        ASUVFromRGB(_draftR, _draftG, _draftB, &u, &v);
    } else {
        ASUVFromRGB(kMDThemeDefaultAccentR, kMDThemeDefaultAccentG, kMDThemeDefaultAccentB, &u, &v);
    }
    CGFloat w = _spectrumView.bounds.size.width;
    CGFloat h = _spectrumView.bounds.size.height;
    if (w > 1 && h > 1) {
        _cursorView.center = CGPointMake(u * w, v * h);
    }
}

// Sheet-only recolor using draft (does not touch global MDTheme prefs).
- (void)recolorSheetChrome {
    BOOL light = _draftLight;
    UIColor *bg = light
        ? [UIColor colorWithRed:0.945f green:0.953f blue:0.965f alpha:1.0f]
        : [UIColor colorWithRed:0.027f green:0.067f blue:0.114f alpha:1.0f];
    UIColor *panel = light
        ? [UIColor colorWithRed:1 green:1 blue:1 alpha:0.98f]
        : [UIColor colorWithRed:0.047f green:0.090f blue:0.145f alpha:0.98f];
    UIColor *panel2 = light
        ? [UIColor colorWithRed:0.945f green:0.953f blue:0.965f alpha:0.98f]
        : [UIColor colorWithRed:0.071f green:0.122f blue:0.188f alpha:0.95f];
    UIColor *line = light ? [UIColor colorWithWhite:0 alpha:0.10f] : [UIColor colorWithWhite:1 alpha:0.085f];
    UIColor *text = light
        ? [UIColor colorWithRed:0.08f green:0.10f blue:0.14f alpha:1.0f]
        : [UIColor colorWithRed:0.969f green:0.976f blue:1.0f alpha:1.0f];
    UIColor *muted = light
        ? [UIColor colorWithRed:0.40f green:0.45f blue:0.52f alpha:1.0f]
        : [UIColor colorWithRed:0.533f green:0.580f blue:0.659f alpha:1.0f];
    UIColor *acc = [self draftAccentColor];

    _dimView.backgroundColor = light ? [UIColor colorWithWhite:0 alpha:0.28f] : [UIColor colorWithWhite:0 alpha:0.50f];
    _card.backgroundColor = panel;
    _card.layer.borderWidth = 1;
    _card.layer.borderColor = line.CGColor;
    _titleLabel.textColor = text;
    _themeLabel.textColor = muted;
    _accentLabel.textColor = muted;
    _previewLabel.textColor = text;
    _previewSwatch.layer.borderColor = line.CGColor;
    _customBox.backgroundColor = panel2;
    _customBox.layer.borderColor = line.CGColor;
    _spectrumView.layer.borderColor = line.CGColor;
    _rgbLabel.textColor = muted;
    _cancelBtn.backgroundColor = panel2;
    _cancelBtn.layer.borderColor = line.CGColor;
    [_cancelBtn setTitleColor:text forState:UIControlStateNormal];
    _confirmBtn.backgroundColor = acc;
    [_confirmBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    if ([_themeSeg respondsToSelector:@selector(setSelectedSegmentTintColor:)]) {
        _themeSeg.selectedSegmentTintColor = [acc colorWithAlphaComponent:0.35f];
        _accentSeg.selectedSegmentTintColor = [acc colorWithAlphaComponent:0.35f];
    }
    NSDictionary *attrs = @{ NSForegroundColorAttributeName: text };
    [_themeSeg setTitleTextAttributes:attrs forState:UIControlStateNormal];
    [_accentSeg setTitleTextAttributes:attrs forState:UIControlStateNormal];
}

#pragma mark - Actions

- (void)cancelTapped {
    // Discard draft — no prefs write.
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)confirmTapped {
    // Commit draft → prefs → notify whole app.
    ESPPrefsSetBool(@"AppThemeMode", _draftLight);
    ESPPrefsSetFloat(@"AppAccentMode", (float)_draftAccentMode);
    ESPPrefsSetFloat(@"AppAccentColorR", _draftR);
    ESPPrefsSetFloat(@"AppAccentColorG", _draftG);
    ESPPrefsSetFloat(@"AppAccentColorB", _draftB);
    ESPPrefsSetFloat(@"AppAccentColorMode", 0.0f);
    ESPPrefsSync();
    MDThemeNotifyChanged();
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    _dimView.frame = self.view.bounds;

    BOOL custom = !_customBox.hidden;
    CGFloat cardH = custom ? 520 : 320;
    CGFloat cardW = MIN(w - 36, 380);
    if (cardH > h - 40) cardH = h - 40;
    _card.frame = CGRectMake((w - cardW) * 0.5f, (h - cardH) * 0.5f, cardW, cardH);

    CGFloat pad = 18;
    CGFloat y = 18;
    _titleLabel.frame = CGRectMake(pad, y, cardW - pad * 2, 28);
    y += 40;
    _themeLabel.frame = CGRectMake(pad, y, cardW - pad * 2, 18);
    y += 22;
    _themeSeg.frame = CGRectMake(pad, y, cardW - pad * 2, 34);
    y += 46;
    _accentLabel.frame = CGRectMake(pad, y, cardW - pad * 2, 18);
    y += 22;
    _accentSeg.frame = CGRectMake(pad, y, cardW - pad * 2, 34);
    y += 46;
    _previewSwatch.frame = CGRectMake(pad, y, 28, 28);
    _previewLabel.frame = CGRectMake(pad + 40, y, cardW - pad * 2 - 40, 28);
    y += 40;

    CGFloat btnH = 44;
    CGFloat btnY = cardH - pad - btnH;
    CGFloat gap = 10;
    CGFloat btnW = (cardW - pad * 2 - gap) * 0.5f;
    _cancelBtn.frame = CGRectMake(pad, btnY, btnW, btnH);
    _confirmBtn.frame = CGRectMake(pad + btnW + gap, btnY, btnW, btnH);

    if (custom) {
        CGFloat boxBottom = btnY - 12;
        CGFloat boxH = MAX(120, boxBottom - y);
        _customBox.frame = CGRectMake(pad, y, cardW - pad * 2, boxH);
        CGFloat iw = _customBox.bounds.size.width - 24;
        _rgbLabel.frame = CGRectMake(12, 10, iw, 18);
        CGFloat spectrumH = MAX(90, boxH - 48);
        _spectrumView.frame = CGRectMake(12, 34, iw, spectrumH);
        [self updateCursorFromDraft];
    } else {
        _customBox.frame = CGRectZero;
    }
}

@end
