#import "Settings.h"
#import "API.h"
#import "Components.h"
#import "Store.h"
#import "Theme.h"

@interface OCSettingsController ()

@property (nonatomic, strong) UISegmentedControl *themeControl;
@property (nonatomic, strong) UILabel *connectionStatus;
@property (nonatomic, strong) UILabel *serverLabel;
@property (nonatomic, strong) UILabel *accountLabel;
@property (nonatomic, strong) OCAPI *probeAPI;

@end

@implementation OCSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Настройки";
    self.view.backgroundColor = [OCPalette background];

    [self configureNavigationItem];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 26;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];

    [stack addArrangedSubview:[self connectionSection]];
    [stack addArrangedSubview:[self themeSection]];
    [stack addArrangedSubview:[self aboutSection]];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshConnection];
}

- (void)configureNavigationItem {
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Готово"
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(close)];
    self.navigationItem.rightBarButtonItem.tintColor = [OCPalette blue];

    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [OCPalette background];
    appearance.shadowColor = UIColor.clearColor;
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: [OCPalette text],
        NSFontAttributeName: OCRoundedFont(17, UIFontWeightSemibold),
    };
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UIView *)sectionTitle:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = OCFont(UIFontTextStyleSubheadline, UIFontWeightSemibold, 13);
    label.textColor = [OCPalette secondaryText];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

// MARK: Подключение

- (UIView *)connectionSection {
    UIStackView *section = [[UIStackView alloc] init];
    section.axis = UILayoutConstraintAxisVertical;
    section.spacing = 10;

    OCCardView *card = [[OCCardView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *inner = [[UIStackView alloc] init];
    inner.axis = UILayoutConstraintAxisVertical;
    inner.spacing = 12;
    inner.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:inner];

    [NSLayoutConstraint activateConstraints:@[
        [inner.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [inner.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [inner.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [inner.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],
    ]];

    _serverLabel = [self valueLabel];
    _accountLabel = [self valueLabel];
    _connectionStatus = [[UILabel alloc] init];
    _connectionStatus.font = OCFont(UIFontTextStyleFootnote, UIFontWeightMedium, 12);
    _connectionStatus.textColor = [OCPalette tertiaryText];
    _connectionStatus.numberOfLines = 0;

    [inner addArrangedSubview:[self infoRow:@"Сервер" valueLabel:_serverLabel]];
    [inner addArrangedSubview:[self infoRow:@"Аккаунт" valueLabel:_accountLabel]];
    [inner addArrangedSubview:_connectionStatus];

    UIStackView *actions = [[UIStackView alloc] init];
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.spacing = 8;
    actions.distribution = UIStackViewDistributionFillEqually;

    OCPillButton *reconfigure = [OCPillButton buttonWithTitle:@"Сменить сервер"];
    [reconfigure addAction:[UIAction actionWithHandler:^(UIAction *action) {
        [OCHaptic tap];
        if (self.onReconfigure) self.onReconfigure();
    }] forControlEvents:UIControlEventTouchUpInside];
    [reconfigure.heightAnchor constraintEqualToConstant:38].active = YES;

    OCPillButton *forget = [OCPillButton buttonWithTitle:@"Отключиться"];
    [forget addAction:[UIAction actionWithHandler:^(UIAction *action) {
        [self confirmForget];
    }] forControlEvents:UIControlEventTouchUpInside];
    [forget.heightAnchor constraintEqualToConstant:38].active = YES;

    [actions addArrangedSubview:reconfigure];
    [actions addArrangedSubview:forget];
    [inner addArrangedSubview:actions];

    [section addArrangedSubview:[self sectionTitle:@"Подключение"]];
    [section addArrangedSubview:card];
    return section;
}

- (UILabel *)valueLabel {
    UILabel *label = [[UILabel alloc] init];
    label.font = OCFont(UIFontTextStyleBody, UIFontWeightMedium, 14);
    label.textColor = [OCPalette text];
    label.textAlignment = NSTextAlignmentRight;
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                           forAxis:UILayoutConstraintAxisHorizontal];
    return label;
}

- (UIView *)infoRow:(NSString *)title valueLabel:(UILabel *)valueLabel {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 12;

    UILabel *name = [[UILabel alloc] init];
    name.text = title;
    name.font = OCFont(UIFontTextStyleBody, UIFontWeightRegular, 15);
    name.textColor = [OCPalette secondaryText];
    [name setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    [row addArrangedSubview:name];
    [row addArrangedSubview:valueLabel];
    return row;
}

- (void)refreshConnection {
    OCConnection *connection = [OCConnection shared];

    _serverLabel.text = connection.baseURL.length ? connection.baseURL : @"не задан";
    _accountLabel.text = connection.username.length ? connection.username : @"—";

    if (!connection.isComplete) {
        _connectionStatus.text = @"Подключение не настроено.";
        _connectionStatus.textColor = [OCPalette tertiaryText];
        return;
    }

    _connectionStatus.text = @"Проверяю сервер…";
    _connectionStatus.textColor = [OCPalette tertiaryText];

    OCAPI *api = [[OCAPI alloc] initWithBaseURL:connection.baseURL
                                       username:connection.username
                                       password:connection.password];
    self.probeAPI = api;

    __weak typeof(self) weakSelf = self;
    [api probeWithCompletion:^(NSString *version, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OCSettingsController *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf.probeAPI != api) return;

            if (error) {
                strongSelf.connectionStatus.text = error.localizedDescription;
                strongSelf.connectionStatus.textColor = [OCPalette coral];
                return;
            }
            strongSelf.connectionStatus.text = version.length
                ? [NSString stringWithFormat:@"Сервер отвечает · версия %@", version]
                : @"Сервер отвечает";
            strongSelf.connectionStatus.textColor = [OCPalette blue];
        });
    }];
}

- (void)confirmForget {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Отключиться от сервера?"
                                                                   message:@"Адрес и пароль будут удалены с телефона. Диалоги останутся на компьютере."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отключиться" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[OCConnection shared] forget];
        [self refreshConnection];
        if (self.onDisconnected) self.onDisconnected();
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// MARK: Оформление

- (UIView *)themeSection {
    UIStackView *section = [[UIStackView alloc] init];
    section.axis = UILayoutConstraintAxisVertical;
    section.spacing = 10;

    _themeControl = [[UISegmentedControl alloc] initWithItems:@[@"Системная", @"Светлая", @"Тёмная"]];
    _themeControl.translatesAutoresizingMaskIntoConstraints = NO;
    _themeControl.selectedSegmentTintColor = [OCPalette raised];

    NSString *theme = [OCSettings shared].theme;
    if ([theme isEqualToString:@"light"]) {
        _themeControl.selectedSegmentIndex = 1;
    } else if ([theme isEqualToString:@"dark"]) {
        _themeControl.selectedSegmentIndex = 2;
    } else {
        _themeControl.selectedSegmentIndex = 0;
    }

    NSDictionary *normal = @{NSForegroundColorAttributeName: [OCPalette text],
                             NSFontAttributeName: OCFont(UIFontTextStyleSubheadline, UIFontWeightMedium, 13)};
    [_themeControl setTitleTextAttributes:normal forState:UIControlStateNormal];
    [_themeControl setTitleTextAttributes:normal forState:UIControlStateSelected];
    [_themeControl addTarget:self action:@selector(themeChanged) forControlEvents:UIControlEventValueChanged];

    [section addArrangedSubview:[self sectionTitle:@"Оформление"]];
    [section addArrangedSubview:_themeControl];
    return section;
}

- (void)themeChanged {
    [OCHaptic tap];
    switch (_themeControl.selectedSegmentIndex) {
        case 1: [OCSettings shared].theme = @"light"; break;
        case 2: [OCSettings shared].theme = @"dark"; break;
        default: [OCSettings shared].theme = @"system"; break;
    }
    UIUserInterfaceStyle style = [OCSettings shared].interfaceStyle;
    self.navigationController.overrideUserInterfaceStyle = style;
    self.navigationController.view.window.overrideUserInterfaceStyle = style;
    if (self.onStyleChanged) self.onStyleChanged();
}

// MARK: О приложении

- (UIView *)aboutSection {
    UIStackView *section = [[UIStackView alloc] init];
    section.axis = UILayoutConstraintAxisVertical;
    section.spacing = 10;

    OCCardView *card = [[OCCardView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *inner = [[UIStackView alloc] init];
    inner.axis = UILayoutConstraintAxisVertical;
    inner.spacing = 12;
    inner.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:inner];

    [NSLayoutConstraint activateConstraints:@[
        [inner.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [inner.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [inner.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [inner.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],
    ]];

    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"1";
    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier] ?: @"dev.opencode2.mobile";

    [inner addArrangedSubview:[self infoRow:@"Версия" value:[NSString stringWithFormat:@"%@ (%@)", version, build]]];
    [inner addArrangedSubview:[self infoRow:@"Идентификатор" value:identifier]];

    UILabel *note = [[UILabel alloc] init];
    note.text = @"Телефон работает с тем же сервером, что и компьютер. Пароль хранится в Keychain и никуда больше не уходит.";
    note.font = OCFont(UIFontTextStyleFootnote, UIFontWeightRegular, 12);
    note.textColor = [OCPalette tertiaryText];
    note.numberOfLines = 0;
    [inner addArrangedSubview:note];

    [section addArrangedSubview:[self sectionTitle:@"О приложении"]];
    [section addArrangedSubview:card];
    return section;
}

- (UIView *)infoRow:(NSString *)title value:(NSString *)value {
    UILabel *val = [self valueLabel];
    val.text = value;
    return [self infoRow:title valueLabel:val];
}

@end
