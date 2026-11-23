#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCSettingsController : UIViewController

/// Сменить сервер: показать экран подключения.
@property (nonatomic, copy, nullable) void (^onReconfigure)(void);
/// Отключиться и забыть пароль.
@property (nonatomic, copy, nullable) void (^onDisconnected)(void);
@property (nonatomic, copy, nullable) void (^onStyleChanged)(void);

@end

NS_ASSUME_NONNULL_END
