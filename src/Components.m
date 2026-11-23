#import "Components.h"
#import "Theme.h"
#import <CoreText/CoreText.h>

static void OCDrawBrandGradient(CGContextRef ctx, CGRect rect, UITraitCollection *traits) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = [OCPalette brandCGColorsFor:traits];
    CGFloat locations[3] = {0.0, 0.55, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, locations);
    CGContextDrawLinearGradient(ctx, gradient,
                                CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)),
                                CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)),
                                kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
}

// MARK: - Искра

@implementation OCSparkView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentMode = UIViewContentModeRedraw;
        self.isAccessibilityElement = NO;
    }
    return self;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGFloat side = MIN(CGRectGetWidth(rect), CGRectGetHeight(rect));
    if (side <= 0) return;

    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGFloat radius = side / 2.0;
    CGFloat pull = side * 0.16;

    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(center.x, center.y - radius)];
    [path addQuadCurveToPoint:CGPointMake(center.x + radius, center.y)
                 controlPoint:CGPointMake(center.x + pull, center.y - pull)];
    [path addQuadCurveToPoint:CGPointMake(center.x, center.y + radius)
                 controlPoint:CGPointMake(center.x + pull, center.y + pull)];
    [path addQuadCurveToPoint:CGPointMake(center.x - radius, center.y)
                 controlPoint:CGPointMake(center.x - pull, center.y + pull)];
    [path addQuadCurveToPoint:CGPointMake(center.x, center.y - radius)
                 controlPoint:CGPointMake(center.x - pull, center.y - pull)];
    [path closePath];

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    [path addClip];

    if (self.monochrome) {
        [[OCPalette text] setFill];
        [path fill];
    } else {
        OCDrawBrandGradient(ctx, rect, self.traitCollection);
    }
    CGContextRestoreGState(ctx);
}

@end

// MARK: - Градиентный текст

@implementation OCGradientLabel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.numberOfLines = 1;
        [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    if (self.text.length == 0 || self.font == nil) {
        [super drawRect:rect];
        return;
    }

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);

    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = self.textAlignment;
    NSMutableDictionary *attrs = [@{
        NSFontAttributeName: self.font,
        NSForegroundColorAttributeName: UIColor.blackColor,
        NSParagraphStyleAttributeName: style,
    } mutableCopy];
    if (self.tracking != 0) attrs[NSKernAttributeName] = @(self.tracking);

    NSAttributedString *string = [[NSAttributedString alloc] initWithString:self.text attributes:attrs];
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);

    CGFloat width = CGRectGetWidth(rect);
    CGFloat baseline = (CGRectGetHeight(rect) - self.font.lineHeight) / 2.0 + self.font.ascender;
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
    CGContextSetTextPosition(ctx, 0, baseline);
    CGContextSetTextDrawingMode(ctx, kCGTextClip);
    CTLineDraw(line, ctx);

    OCDrawBrandGradient(ctx, CGRectMake(0, 0, width, CGRectGetHeight(rect)), self.traitCollection);

    CFRelease(line);
    CGContextRestoreGState(ctx);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    [self setNeedsDisplay];
}

- (void)setText:(NSString *)text {
    [super setText:text];
    [self setNeedsDisplay];
}

- (void)setFont:(UIFont *)font {
    [super setFont:font];
    [self setNeedsDisplay];
}

@end

// MARK: - Кнопка отправки

@implementation OCSendButton {
    CAGradientLayer *_gradient;
    UIImageView *_icon;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _gradient = [CAGradientLayer layer];
        _gradient.startPoint = CGPointMake(0, 0);
        _gradient.endPoint = CGPointMake(1, 1);
        _gradient.colors = [OCPalette brandCGColorsFor:self.traitCollection];
        _gradient.cornerRadius = 20;
        [self.layer addSublayer:_gradient];

        _icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.up"
                                                           withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17
                                                                                                                                      weight:UIImageSymbolWeightBold]]];
        _icon.tintColor = UIColor.whiteColor;
        _icon.contentMode = UIViewContentModeCenter;
        _icon.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_icon];
        [NSLayoutConstraint activateConstraints:@[
            [_icon.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_icon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];

        self.enabled = YES;
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = @"Отправить";
        self.accessibilityTraits = UIAccessibilityTraitButton;
        [self updateEnabledLook];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _gradient.frame = self.bounds;
    _gradient.cornerRadius = CGRectGetHeight(self.bounds) / 2.0;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    _gradient.colors = [OCPalette brandCGColorsFor:self.traitCollection];
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    [self updateEnabledLook];
}

- (void)updateEnabledLook {
    BOOL on = self.enabled;
    _gradient.opacity = on ? 1.0 : 0.35;
    _icon.alpha = on ? 1.0 : 0.7;
}

@end

// MARK: - Пилюля ввода

@interface OCComposer () <UITextFieldDelegate>
@end

@implementation OCComposer {
    UITextField *_field;
    OCSendButton *_send;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [OCPalette surface];
        self.layer.cornerRadius = 28;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [OCPalette border].CGColor;

        _field = [[UITextField alloc] init];
        _field.translatesAutoresizingMaskIntoConstraints = NO;
        _field.font = OCFont(UIFontTextStyleBody, UIFontWeightRegular, 16);
        _field.textColor = [OCPalette text];
        _field.tintColor = [OCPalette blue];
        _field.returnKeyType = UIReturnKeySend;
        _field.delegate = self;
        _field.borderStyle = UITextBorderStyleNone;
        [_field addTarget:self action:@selector(textChanged) forControlEvents:UIControlEventEditingChanged];
        [self addSubview:_field];

        _send = [[OCSendButton alloc] init];
        _send.translatesAutoresizingMaskIntoConstraints = NO;
        [_send addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_send];

        [NSLayoutConstraint activateConstraints:@[
            [_field.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [_field.trailingAnchor constraintEqualToAnchor:_send.leadingAnchor constant:-12],
            [_field.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_field.heightAnchor constraintGreaterThanOrEqualToConstant:24],

            [_send.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [_send.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_send.widthAnchor constraintEqualToConstant:40],
            [_send.heightAnchor constraintEqualToConstant:40],
        ]];

        self.placeholder = @"Спросите OpenCode";
        _send.enabled = NO;
    }
    return self;
}

- (UITextField *)field {
    return _field;
}

- (void)setPlaceholder:(NSString *)placeholder {
    _placeholder = [placeholder copy];
    _field.attributedPlaceholder =
        [[NSAttributedString alloc] initWithString:placeholder
                                        attributes:@{NSForegroundColorAttributeName: [OCPalette secondaryText]}];
    _field.accessibilityLabel = placeholder;
}

- (void)focus {
    [_field becomeFirstResponder];
}

- (void)clear {
    _field.text = @"";
    [self textChanged];
}

- (void)textChanged {
    BOOL hasText = _field.text.length > 0;
    _send.enabled = hasText;
}

- (void)sendTapped {
    NSString *text = [_field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (text.length == 0) return;
    [OCHaptic tap];
    if (self.onSend) self.onSend(text);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [_field resignFirstResponder];
    [self sendTapped];
    return YES;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    self.layer.borderColor = [OCPalette border].CGColor;
    self.backgroundColor = [OCPalette surface];
}

@end

// MARK: - Карточка

@implementation OCCardView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [OCPalette surface];
        self.layer.cornerRadius = 24;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [OCPalette border].CGColor;
    }
    return self;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    self.backgroundColor = [OCPalette surface];
    self.layer.borderColor = [OCPalette border].CGColor;
}

@end

// MARK: - Главная кнопка

@implementation OCPrimaryButton {
    CAGradientLayer *_gradient;
    UIActivityIndicatorView *_spinner;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _gradient = [CAGradientLayer layer];
        _gradient.startPoint = CGPointMake(0, 0);
        _gradient.endPoint = CGPointMake(1, 1);
        _gradient.colors = [OCPalette brandCGColorsFor:self.traitCollection];
        _gradient.cornerRadius = 26;
        _gradient.cornerCurve = kCACornerCurveContinuous;
        [self.layer insertSublayer:_gradient atIndex:0];

        self.titleLabel.font = OCFont(UIFontTextStyleHeadline, UIFontWeightSemibold, 16);
        [self setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [self.heightAnchor constraintEqualToConstant:52].active = YES;

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _spinner.color = UIColor.whiteColor;
        _spinner.hidesWhenStopped = YES;
        _spinner.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_spinner];
        [NSLayoutConstraint activateConstraints:@[
            [_spinner.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_spinner.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _gradient.frame = self.bounds;
    _gradient.cornerRadius = CGRectGetHeight(self.bounds) / 2.0;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    _gradient.colors = [OCPalette brandCGColorsFor:self.traitCollection];
}

- (void)setBusy:(BOOL)busy title:(NSString *)title {
    self.enabled = !busy;
    self.alpha = busy ? 0.75 : 1.0;
    [self setTitle:title forState:UIControlStateNormal];
    self.titleLabel.alpha = busy ? 0.0 : 1.0;
    if (busy) {
        [_spinner startAnimating];
    } else {
        [_spinner stopAnimating];
    }
}

@end

// MARK: - Кнопка-пилюля

@implementation OCPillButton

+ (instancetype)buttonWithTitle:(NSString *)title {
    OCPillButton *button = [OCPillButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = OCFont(UIFontTextStyleSubheadline, UIFontWeightMedium, 14);
    [button setTitleColor:[OCPalette text] forState:UIControlStateNormal];
    button.backgroundColor = [OCPalette surface];
    button.layer.cornerRadius = 18;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [OCPalette border].CGColor;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button.heightAnchor constraintEqualToConstant:36].active = YES;
    return button;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    self.backgroundColor = [OCPalette surface];
    self.layer.borderColor = [OCPalette border].CGColor;
    [self setTitleColor:[OCPalette text] forState:UIControlStateNormal];
}

@end

// MARK: - Отклик

@implementation OCHaptic

+ (void)tap {
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [generator impactOccurred];
}

+ (void)success {
    UINotificationFeedbackGenerator *generator = [UINotificationFeedbackGenerator new];
    [generator notificationOccurred:UINotificationFeedbackTypeSuccess];
}

@end
