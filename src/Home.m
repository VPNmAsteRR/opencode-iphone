#import "Home.h"
#import "Chat.h"
#import "ChatStore.h"
#import "Components.h"
#import "Models.h"
#import "Settings.h"
#import "Setup.h"
#import "Store.h"
#import "Theme.h"

// MARK: - Строка сессии

@interface OCSessionRow : UIControl <UIContextMenuInteractionDelegate>

@property (nonatomic, strong) OCSession *session;
@property (nonatomic, copy) void (^onDelete)(OCSession *session);

@end

@implementation OCSessionRow {
    UILabel *_title;
    UILabel *_subtitle;
    UIImageView *_chevron;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        UIStackView *texts = [[UIStackView alloc] init];
        texts.axis = UILayoutConstraintAxisVertical;
        texts.spacing = 3;
        texts.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:texts];

        _title = [[UILabel alloc] init];
        _title.font = OCFont(UIFontTextStyleBody, UIFontWeightMedium, 16);
        _title.textColor = [OCPalette text];
        _title.numberOfLines = 1;
        _title.lineBreakMode = NSLineBreakByTruncatingTail;

        _subtitle = [[UILabel alloc] init];
        _subtitle.font = OCFont(UIFontTextStyleFootnote, UIFontWeightRegular, 13);
        _subtitle.textColor = [OCPalette secondaryText];
        _subtitle.numberOfLines = 1;

        [texts addArrangedSubview:_title];
        [texts addArrangedSubview:_subtitle];

        _chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"
                                                              withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12
                                                                                                                                         weight:UIImageSymbolWeightSemibold]]];
        _chevron.tintColor = [OCPalette tertiaryText];
        _chevron.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_chevron];

        [NSLayoutConstraint activateConstraints:@[
            [texts.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [texts.topAnchor constraintEqualToAnchor:self.topAnchor constant:14],
            [texts.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-14],
            [texts.trailingAnchor constraintLessThanOrEqualToAnchor:_chevron.leadingAnchor constant:-12],

            [_chevron.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_chevron.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];

        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;

        __weak typeof(self) weakSelf = self;
        UIContextMenuInteraction *menu = [[UIContextMenuInteraction alloc] initWithDelegate:weakSelf];
        [self addInteraction:menu];
    }
    return self;
}

- (void)setSession:(OCSession *)session {
    _session = session;
    _title.text = session.displayTitle;

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    formatter.doesRelativeDateFormatting = YES;

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:session.updatedAt];
    _subtitle.text = [NSString stringWithFormat:@"%@ · %@", session.projectName,
                      date ? [formatter stringFromDate:date] : @""];

    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", _title.text, _subtitle.text];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? [OCPalette raised] : UIColor.clearColor;
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location {
    __weak typeof(self) weakSelf = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        UIAction *delete = [UIAction actionWithTitle:@"Удалить"
                                              image:[UIImage systemImageNamed:@"trash"]
                                         identifier:nil
                                            handler:^(UIAction *action) {
            if (weakSelf.onDelete) weakSelf.onDelete(weakSelf.session);
        }];
        delete.attributes = UIMenuElementAttributesDestructive;
        return [UIMenu menuWithTitle:@"" children:@[delete]];
    }];
}

@end

// MARK: - Главный экран

@interface OCHomeController ()

@property (nonatomic, strong) OCChatStore *store;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *content;
@property (nonatomic, strong) OCComposer *composer;
@property (nonatomic, strong) UIStackView *recentList;
@property (nonatomic, strong) UIView *greeting;
@property (nonatomic, strong) UIView *chips;
@property (nonatomic, strong) UILabel *emptyHint;
@property (nonatomic, strong) UILabel *sectionTitle;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, assign) BOOL setupAnnounced;

@end

@implementation OCHomeController

- (instancetype)initWithStore:(OCChatStore *)store {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _store = store;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [OCPalette background];
    self.title = @"OpenCode";

    _scroll = [[UIScrollView alloc] init];
    _scroll.translatesAutoresizingMaskIntoConstraints = NO;
    _scroll.alwaysBounceVertical = YES;
    _scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:_scroll];

    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    _scroll.refreshControl = _refreshControl;

    _content = [[UIStackView alloc] init];
    _content.axis = UILayoutConstraintAxisVertical;
    _content.translatesAutoresizingMaskIntoConstraints = NO;
    [_scroll addSubview:_content];

    _greeting = [self greetingView];
    _chips = [self chipsView];

    [_content addArrangedSubview:[self headerView]];
    [_content addArrangedSubview:_greeting];
    [_content addArrangedSubview:_chips];
    [_content addArrangedSubview:[self recentSection]];

    _composer = [[OCComposer alloc] init];
    _composer.translatesAutoresizingMaskIntoConstraints = NO;
    _composer.placeholder = @"Спросите OpenCode";
    __weak typeof(self) weakSelf = self;
    _composer.onSend = ^(NSString *text) {
        [weakSelf sendFromHome:text];
    };
    [self.view addSubview:_composer];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.font = OCFont(UIFontTextStyleCaption2, UIFontWeightRegular, 11);
    _statusLabel.textColor = [OCPalette tertiaryText];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.numberOfLines = 2;
    [self.view addSubview:_statusLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [_scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scroll.bottomAnchor constraintEqualToAnchor:_composer.topAnchor constant:-8],

        [_content.topAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.topAnchor],
        [_content.leadingAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.leadingAnchor],
        [_content.trailingAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.trailingAnchor],
        [_content.bottomAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.bottomAnchor],

        [_composer.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [_composer.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [_composer.heightAnchor constraintEqualToConstant:56],
        [_composer.bottomAnchor constraintEqualToAnchor:_statusLabel.topAnchor constant:-8],

        [_statusLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [_statusLabel.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor constant:-8],
    ]];

    UITapGestureRecognizer *dismiss = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    dismiss.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:dismiss];
}

/// Обратные вызовы хранилища одиночные: чат забирает их себе и
/// отпускает при закрытии. Поэтому главный экран подписывается заново.
- (void)bindStore {
    __weak typeof(self) weakSelf = self;
    _store.onSessionsChanged = ^{
        [weakSelf reloadSessions];
    };
    _store.onPhaseChanged = ^{
        [weakSelf updateStatus];
    };
    _store.onChatChanged = ^{
        [weakSelf updateStatus];
    };
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    self.view.window.overrideUserInterfaceStyle = [OCSettings shared].interfaceStyle;
    [self bindStore];
    [self reloadSessions];
    [self updateStatus];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Экран подключения открывается сам только один раз: иначе отмена
    // мгновенно возвращает его обратно.
    if (_store.phase == OCPhaseUnauthorized && !_setupAnnounced) {
        _setupAnnounced = YES;
        [self openSetup];
    }
}

- (void)dismissKeyboard { [self.view endEditing:YES]; }

// MARK: Секции

- (UIView *)headerView {
    UIView *wrap = [[UIView alloc] init];

    UIStackView *brand = [[UIStackView alloc] init];
    brand.axis = UILayoutConstraintAxisHorizontal;
    brand.spacing = 9;
    brand.alignment = UIStackViewAlignmentCenter;
    brand.translatesAutoresizingMaskIntoConstraints = NO;
    [wrap addSubview:brand];

    OCSparkView *spark = [[OCSparkView alloc] initWithFrame:CGRectMake(0, 0, 22, 22)];
    spark.translatesAutoresizingMaskIntoConstraints = NO;
    [spark.widthAnchor constraintEqualToConstant:22].active = YES;
    [spark.heightAnchor constraintEqualToConstant:22].active = YES;

    UILabel *wordmark = [[UILabel alloc] init];
    wordmark.text = @"OpenCode";
    wordmark.font = OCRoundedFont(17, UIFontWeightSemibold);
    wordmark.textColor = [OCPalette text];

    [brand addArrangedSubview:spark];
    [brand addArrangedSubview:wordmark];

    UIButton *gear = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *gearImage = [UIImage systemImageNamed:@"slider.horizontal.3"
                                 withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17
                                                                                               weight:UIImageSymbolWeightSemibold]];
    [gear setImage:gearImage forState:UIControlStateNormal];
    gear.tintColor = [OCPalette secondaryText];
    gear.translatesAutoresizingMaskIntoConstraints = NO;
    gear.accessibilityLabel = @"Настройки";
    [gear addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
    [wrap addSubview:gear];

    [NSLayoutConstraint activateConstraints:@[
        [brand.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:20],
        [brand.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:6],
        [brand.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-14],

        [gear.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-16],
        [gear.centerYAnchor constraintEqualToAnchor:brand.centerYAnchor],
        [gear.widthAnchor constraintEqualToConstant:44],
        [gear.heightAnchor constraintEqualToConstant:44],
    ]];

    return wrap;
}

- (UIView *)greetingView {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.layoutMarginsRelativeArrangement = YES;
    stack.layoutMargins = UIEdgeInsetsMake(8, 20, 18, 20);

    UILabel *hello = [[UILabel alloc] init];
    hello.text = @"Привет";
    hello.font = OCRoundedFontScaled(UIFontTextStyleLargeTitle, 32, UIFontWeightBold);
    hello.textColor = [OCPalette text];
    hello.adjustsFontForContentSizeCategory = YES;

    OCGradientLabel *question = [[OCGradientLabel alloc] init];
    question.text = @"Чем помочь?";
    question.font = OCRoundedFontScaled(UIFontTextStyleLargeTitle, 32, UIFontWeightBold);
    question.adjustsFontForContentSizeCategory = YES;

    [stack addArrangedSubview:hello];
    [stack addArrangedSubview:question];
    return stack;
}

- (UIView *)chipsView {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.contentInset = UIEdgeInsetsMake(0, 20, 0, 20);
    scroll.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:row];

    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [row.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [row.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [row.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor],
        [scroll.heightAnchor constraintEqualToConstant:36],
    ]];

    NSArray<NSString *> *titles = @[
        @"Что делали в прошлый раз?",
        @"Найди ошибку",
        @"Добавь тесты",
        @"Объясни файл",
    ];

    __weak typeof(self) weakSelf = self;
    for (NSString *title in titles) {
        OCPillButton *chip = [OCPillButton buttonWithTitle:title];
        chip.titleLabel.font = OCFont(UIFontTextStyleSubheadline, UIFontWeightMedium, 13);
        [chip addAction:[UIAction actionWithHandler:^(UIAction *action) {
            [OCHaptic tap];
            [weakSelf.composer.field setText:title];
            [weakSelf.composer.field sendActionsForControlEvents:UIControlEventEditingChanged];
            [weakSelf.composer focus];
        }] forControlEvents:UIControlEventTouchUpInside];
        [row addArrangedSubview:chip];
    }

    UIView *wrap = [[UIView alloc] init];
    [wrap addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:wrap.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-10],
        [scroll.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor],
    ]];
    return wrap;
}

- (UIView *)recentSection {
    UIStackView *section = [[UIStackView alloc] init];
    section.axis = UILayoutConstraintAxisVertical;
    section.spacing = 0;
    section.layoutMarginsRelativeArrangement = YES;
    section.layoutMargins = UIEdgeInsetsMake(14, 20, 0, 20);

    _sectionTitle = [[UILabel alloc] init];
    _sectionTitle.text = @"Недавние";
    _sectionTitle.font = OCFont(UIFontTextStyleSubheadline, UIFontWeightSemibold, 13);
    _sectionTitle.textColor = [OCPalette secondaryText];
    _sectionTitle.hidden = YES;

    _recentList = [[UIStackView alloc] init];
    _recentList.axis = UILayoutConstraintAxisVertical;
    _recentList.spacing = 0;

    [section addArrangedSubview:_sectionTitle];
    [section addArrangedSubview:_recentList];

    return section;
}

// MARK: Данные

- (void)reloadSessions {
    for (UIView *view in _recentList.arrangedSubviews) {
        [_recentList removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSArray<OCSession *> *sessions = _store.sessions;
    BOOL empty = sessions.count == 0;

    // Пока диалогов нет, экран выглядит как приглашение начать.
    // Когда они есть, приглашение уступает место списку.
    _greeting.hidden = !empty;
    _chips.hidden = !empty;
    _sectionTitle.hidden = empty;

    NSArray<OCSession *> *shown = sessions.count > 30
        ? [sessions subarrayWithRange:NSMakeRange(0, 30)]
        : sessions;
    _sectionTitle.text = sessions.count > shown.count
        ? [NSString stringWithFormat:@"Недавние · %lu из %lu", (unsigned long)shown.count, (unsigned long)sessions.count]
        : @"Недавние";

    __weak typeof(self) weakSelf = self;
    for (OCSession *session in shown) {
        OCSessionRow *row = [[OCSessionRow alloc] init];
        row.session = session;
        row.onDelete = ^(OCSession *target) {
            [weakSelf confirmDelete:target];
        };
        [row addAction:[UIAction actionWithHandler:^(UIAction *action) {
            [weakSelf openSession:session];
        }] forControlEvents:UIControlEventTouchUpInside];

        UIView *line = [[UIView alloc] init];
        line.backgroundColor = [OCPalette separator];
        line.translatesAutoresizingMaskIntoConstraints = NO;
        [line.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale].active = YES;

        [_recentList addArrangedSubview:row];
        [_recentList addArrangedSubview:line];
    }

    [self updateStatus];
}

- (void)updateStatus {
    _composer.hidden = NO;

    switch (_store.phase) {
        case OCPhaseConnecting:
            _statusLabel.text = @"Подключаюсь к серверу";
            _composer.field.enabled = NO;
            break;
        case OCPhaseReady:
            _composer.field.enabled = YES;
            _statusLabel.text = nil;
            break;
        case OCPhaseUnauthorized:
            _statusLabel.text = @"Нужен адрес и пароль · нажмите, чтобы настроить";
            _composer.field.enabled = NO;
            break;
        case OCPhaseFailed:
            _statusLabel.text = _store.phaseMessage ?: @"Сервер недоступен";
            _composer.field.enabled = NO;
            break;
    }

    if (_store.phase == OCPhaseUnauthorized || _store.phase == OCPhaseFailed) {
        _statusLabel.textColor = [OCPalette coral];
        _statusLabel.userInteractionEnabled = YES;
        if (_statusLabel.gestureRecognizers.count == 0) {
            [_statusLabel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openSetup)]];
        }
    } else {
        _statusLabel.textColor = [OCPalette tertiaryText];
        _statusLabel.userInteractionEnabled = NO;
    }
}

- (void)refresh {
    [_store reloadSessions];
    [_refreshControl endRefreshing];
}

- (void)confirmDelete:(OCSession *)session {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Удалить диалог?"
                                                                   message:session.displayTitle
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Удалить" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self.store deleteSession:session];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.view;
    alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    [self presentViewController:alert animated:YES completion:nil];
}

// MARK: Действия

- (void)sendFromHome:(NSString *)text {
    [_store startDraft];
    [self openChat];
    [_store sendText:text];
    [_composer clear];
}

- (void)openSession:(OCSession *)session {
    [OCHaptic tap];
    [_store openSession:session];
    [self openChat];
}

- (void)openChat {
    OCChatController *chat = [[OCChatController alloc] initWithStore:_store];
    [self.navigationController pushViewController:chat animated:YES];
}

- (void)openSetup {
    if (self.presentedViewController) return;
    OCSSetupController *setup = [[OCSSetupController alloc] init];
    setup.canCancel = YES;
    __weak typeof(self) weakSelf = self;
    setup.onConnected = ^{
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
        [weakSelf.store connect];
    };
    setup.onCancel = ^{
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:setup];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)openSettings {
    [OCHaptic tap];
    OCSettingsController *settings = [[OCSettingsController alloc] init];
    __weak typeof(self) weakSelf = self;
    settings.onDisconnected = ^{
        [weakSelf.store disconnect];
        [weakSelf updateStatus];
        // Настройки закроются сами, и тогда главный экран снова
        // предложит подключиться — уже с пустыми полями.
        weakSelf.setupAnnounced = NO;
    };
    settings.onReconfigure = ^{
        [weakSelf dismissViewControllerAnimated:YES completion:^{
            [weakSelf openSetup];
        }];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        nav.sheetPresentationController.prefersGrabberVisible = YES;
    }
    [self presentViewController:nav animated:YES completion:nil];
}

@end
