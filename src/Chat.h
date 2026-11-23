#import <UIKit/UIKit.h>

@class OCChatStore;

NS_ASSUME_NONNULL_BEGIN

@interface OCChatController : UIViewController

- (instancetype)initWithStore:(OCChatStore *)store;

@end

NS_ASSUME_NONNULL_END
