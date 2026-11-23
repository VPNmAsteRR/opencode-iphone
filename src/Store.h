#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Адрес сервера, логин и пароль. Пароль лежит в Keychain,
/// адрес и логин в NSUserDefaults.
@interface OCConnection : NSObject

@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;

@property (nonatomic, readonly) BOOL isComplete;

+ (instancetype)shared;
- (void)save;
- (void)forget;

@end

/// Настройки оформления.
@interface OCSettings : NSObject

@property (nonatomic, copy) NSString *theme;   // system | light | dark
@property (nonatomic, readonly) UIUserInterfaceStyle interfaceStyle;

+ (instancetype)shared;

@end

NS_ASSUME_NONNULL_END
