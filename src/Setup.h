#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Первый запуск и правка подключения: адрес, логин, пароль.
/// Кнопка проверяет сервер по-настоящему, а не делает вид.
@interface OCSSetupController : UIViewController

@property (nonatomic, copy, nullable) void (^onConnected)(void);
@property (nonatomic, copy, nullable) void (^onCancel)(void);
@property (nonatomic, assign) BOOL canCancel;

@end

NS_ASSUME_NONNULL_END
