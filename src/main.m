#import <UIKit/UIKit.h>
#import "ChatStore.h"
#import "Home.h"
#import "Settings.h"
#import "Setup.h"
#import "Store.h"
#import "Theme.h"

@interface OCAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) OCChatStore *store;

@end

@implementation OCAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.store = [[OCChatStore alloc] init];

    self.window.overrideUserInterfaceStyle = [OCSettings shared].interfaceStyle;
    self.window.rootViewController = [self rootController];
    [self.window makeKeyAndVisible];

    [self.store connect];
    return YES;
}

- (UIViewController *)rootController {
    if ([OCConnection shared].isComplete) {
        OCHomeController *home = [[OCHomeController alloc] initWithStore:self.store];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:home];
        nav.navigationBarHidden = YES;
        return nav;
    }

    __weak typeof(self) weakSelf = self;
    OCSSetupController *setup = [[OCSSetupController alloc] init];
    setup.canCancel = NO;
    setup.onConnected = ^{
        [weakSelf showHome];
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:setup];
    nav.navigationBarHidden = YES;
    return nav;
}

- (void)showHome {
    UIViewController *root = [self rootController];
    UIView *snapshot = [self.window snapshotViewAfterScreenUpdates:NO];
    if (snapshot) {
        snapshot.frame = self.window.bounds;
        [self.window addSubview:snapshot];
    }

    [UIView transitionWithView:self.window
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.window.rootViewController = root;
    } completion:^(BOOL finished) {
        [snapshot removeFromSuperview];
    }];

    [self.store connect];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self.store refresh];
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(OCAppDelegate.class));
    }
}
