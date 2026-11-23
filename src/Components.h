#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Четырёхлучевая искра, знак приложения. Рисуется кодом, поэтому
/// остаётся резкой на любом размере.
@interface OCSparkView : UIView
@property (nonatomic, assign) BOOL monochrome;
@end

/// Текст с радужной заливкой. Градиент режется по глифам.
@interface OCGradientLabel : UILabel
@property (nonatomic, assign) CGFloat tracking;
@end

/// Круглая кнопка отправки с градиентом.
@interface OCSendButton : UIControl
@end

/// Поле ввода в пилюле: текст, кнопка отправки, рост по строкам.
@interface OCComposer : UIView
@property (nonatomic, copy, nullable) void (^onSend)(NSString *text);
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, readonly) UITextField *field;
- (void)focus;
- (void)clear;
@end

/// Карточка с мягкой границей.
@interface OCCardView : UIView
@end

/// Широкая кнопка с градиентом: главное действие экрана.
@interface OCPrimaryButton : UIButton
- (void)setBusy:(BOOL)busy title:(NSString *)title;
@end

/// Компактная кнопка-пилюля.
@interface OCPillButton : UIButton
+ (instancetype)buttonWithTitle:(NSString *)title;
@end

@interface OCHaptic : NSObject
+ (void)tap;
+ (void)success;
@end

NS_ASSUME_NONNULL_END
