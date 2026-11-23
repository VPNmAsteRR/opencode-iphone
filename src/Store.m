#import "Store.h"
#import <Security/Security.h>

static NSString *const kBaseURLKey = @"oc.connection.baseURL";
static NSString *const kUsernameKey = @"oc.connection.username";
static NSString *const kThemeKey = @"oc.settings.theme";
static NSString *const kKeychainService = @"dev.opencode2.connection";
static NSString *const kKeychainAccount = @"server-password";

@implementation OCConnection

+ (instancetype)shared {
    static OCConnection *connection;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ connection = [OCConnection new]; });
    return connection;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        _baseURL = [defaults stringForKey:kBaseURLKey] ?: @"";
        _username = [defaults stringForKey:kUsernameKey] ?: @"opencode";
        _password = [self loadPassword] ?: @"";
    }
    return self;
}

- (BOOL)isComplete {
    NSString *trimmed = [self.baseURL stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) return NO;
    NSURL *url = [NSURL URLWithString:trimmed];
    if (url.scheme.length == 0 || url.host.length == 0) return NO;
    return self.password.length > 0;
}

// MARK: Keychain

- (NSMutableDictionary *)keychainQuery {
    return [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: kKeychainAccount,
    } mutableCopy];
}

- (NSString *)loadPassword {
    NSMutableDictionary *query = [self keychainQuery];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || result == NULL) return nil;

    NSData *data = (__bridge_transfer NSData *)result;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)savePassword:(NSString *)password {
    SecItemDelete((__bridge CFDictionaryRef)[self keychainQuery]);
    if (password.length == 0) return;

    NSMutableDictionary *item = [self keychainQuery];
    item[(__bridge id)kSecValueData] = [password dataUsingEncoding:NSUTF8StringEncoding];
    item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
    SecItemAdd((__bridge CFDictionaryRef)item, NULL);
}

// MARK: Сохранение

- (void)save {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:[self.baseURL stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
                 forKey:kBaseURLKey];
    [defaults setObject:self.username ?: @"" forKey:kUsernameKey];
    [self savePassword:self.password];
}

- (void)forget {
    self.baseURL = @"";
    self.username = @"opencode";
    self.password = @"";
    [self save];
}

@end

@implementation OCSettings

+ (instancetype)shared {
    static OCSettings *settings;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ settings = [OCSettings new]; });
    return settings;
}

- (NSString *)theme {
    NSString *value = [NSUserDefaults.standardUserDefaults stringForKey:kThemeKey];
    return value.length ? value : @"system";
}

- (void)setTheme:(NSString *)theme {
    [NSUserDefaults.standardUserDefaults setObject:theme forKey:kThemeKey];
}

- (UIUserInterfaceStyle)interfaceStyle {
    if ([self.theme isEqualToString:@"dark"]) return UIUserInterfaceStyleDark;
    if ([self.theme isEqualToString:@"light"]) return UIUserInterfaceStyleLight;
    return UIUserInterfaceStyleUnspecified;
}

@end
