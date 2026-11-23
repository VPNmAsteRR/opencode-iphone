#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Цвета Gemini: нейтральная основа плюс один радужный акцент.
/// Тёмная и светлая темы живут одновременно, выбор хранится в настройках.
@interface OCPalette : NSObject

+ (UIColor *)background;
+ (UIColor *)surface;
+ (UIColor *)raised;
+ (UIColor *)text;
+ (UIColor *)secondaryText;
+ (UIColor *)tertiaryText;
+ (UIColor *)separator;
+ (UIColor *)border;

+ (UIColor *)blue;
+ (UIColor *)violet;
+ (UIColor *)coral;
+ (UIColor *)warning;

/// Порядок важен: градиент идёт синий -> фиолетовый -> коралловый.
+ (NSArray<UIColor *> *)brandColors;
+ (NSArray *)brandCGColorsFor:(UITraitCollection *)traits;

@end

/// Скруглённый шрифт для заголовков, обычный для текста.
UIFont *OCRoundedFont(CGFloat size, UIFontWeight weight);
/// Скруглённый шрифт, который растёт вместе с системным размером текста.
UIFont *OCRoundedFontScaled(UIFontTextStyle style, CGFloat size, UIFontWeight weight);
UIFont *OCFont(UIFontTextStyle style, UIFontWeight weight, CGFloat size);

NS_ASSUME_NONNULL_END
