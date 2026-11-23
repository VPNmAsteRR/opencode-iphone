#import <UIKit/UIKit.h>

@class OCChatStore;

NS_ASSUME_NONNULL_BEGIN

@interface OCHomeController : UIViewController

- (instancetype)initWithStore:(OCChatStore *)store;

@end

NS_ASSUME_NONNULL_END
