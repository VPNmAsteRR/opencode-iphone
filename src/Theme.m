#import "Theme.h"

static UIColor *OCDynamic(UIColor *light, UIColor *dark) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
    }];
}

static UIColor *OCRGB(CGFloat r, CGFloat g, CGFloat b) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

@implementation OCPalette

+ (UIColor *)background {
    return OCDynamic([UIColor whiteColor], OCRGB(19, 19, 20));
}

+ (UIColor *)surface {
    return OCDynamic(OCRGB(240, 244, 249), OCRGB(30, 31, 32));
}

+ (UIColor *)raised {
    return OCDynamic(OCRGB(233, 238, 246), OCRGB(40, 42, 44));
}

+ (UIColor *)text {
    return OCDynamic(OCRGB(31, 31, 31), OCRGB(227, 227, 227));
}

+ (UIColor *)secondaryText {
    return OCDynamic(OCRGB(87, 91, 95), OCRGB(154, 160, 166));
}

+ (UIColor *)tertiaryText {
    return OCDynamic(OCRGB(110, 114, 118), OCRGB(142, 145, 150));
}

+ (UIColor *)separator {
    return OCDynamic(OCRGB(226, 231, 238), OCRGB(45, 47, 49));
}

+ (UIColor *)border {
    return OCDynamic([UIColor colorWithWhite:0 alpha:0.08], [UIColor colorWithWhite:1 alpha:0.09]);
}

+ (UIColor *)blue {
    return OCRGB(66, 133, 244);
}

+ (UIColor *)violet {
    return OCRGB(155, 114, 203);
}

+ (UIColor *)coral {
    return OCRGB(217, 101, 112);
}

+ (UIColor *)warning {
    return OCRGB(249, 171, 0);
}

+ (NSArray<UIColor *> *)brandColors {
    return @[[self blue], [self violet], [self coral]];
}

+ (NSArray *)brandCGColorsFor:(UITraitCollection *)traits {
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:3];
    for (UIColor *color in [self brandColors]) {
        [colors addObject:(id)[color resolvedColorWithTraitCollection:traits].CGColor];
    }
    return colors;
}

@end

UIFont *OCRoundedFont(CGFloat size, UIFontWeight weight) {
    UIFont *base = [UIFont systemFontOfSize:size weight:weight];
    UIFontDescriptor *descriptor =
        [base.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    return descriptor ? [UIFont fontWithDescriptor:descriptor size:size] : base;
}

UIFont *OCRoundedFontScaled(UIFontTextStyle style, CGFloat size, UIFontWeight weight) {
    return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:OCRoundedFont(size, weight)];
}

UIFont *OCFont(UIFontTextStyle style, UIFontWeight weight, CGFloat size) {
    UIFont *base = [UIFont systemFontOfSize:size weight:weight];
    return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:base];
}
