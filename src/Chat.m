#import "Chat.h"
#import "ChatStore.h"
#import "Components.h"
#import "Models.h"
#import "Store.h"
#import "Theme.h"

// MARK: - Разметка

/// Лёгкий разбор markdown: заголовки, списки, цитаты и блоки кода.
/// Без внешних библиотек: одного NSAttributedString хватает.
static NSAttributedString *OCFormatMarkdown(NSString *text) {
    if (text.length == 0) return [[NSAttributedString alloc] initWithString:@""];

    UIFont *body = OCFont(UIFontTextStyleBody, UIFontWeightRegular, 16);
    UIFont *bold = OCFont(UIFontTextStyleBody, UIFontWeightSemibold, 16);
    UIFont *code = [UIFont monospacedSystemFontOfSize:13.5 weight:UIFontWeightRegular];
    UIColor *ink = [OCPalette text];
    UIColor *codeInk = [OCPalette text];

    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];

    NSMutableParagraphStyle *bodyStyle = [NSMutableParagraphStyle new];
    bodyStyle.lineSpacing = 3;
    bodyStyle.paragraphSpacing = 8;

    NSMutableParagraphStyle *codeStyle = [NSMutableParagraphStyle new];
    codeStyle.lineSpacing = 2;
    codeStyle.paragraphSpacing = 10;
    codeStyle.headIndent = 12;
    codeStyle.firstLineHeadIndent = 12;

    NSMutableParagraphStyle *listStyle = [NSMutableParagraphStyle new];
    listStyle.lineSpacing = 3;
    listStyle.paragraphSpacing = 6;
    listStyle.headIndent = 16;
    listStyle.firstLineHeadIndent = 2;

    BOOL inCode = NO;
    NSMutableArray<NSString *> *codeLines = [NSMutableArray array];

    NSArray<NSString *> *lines = [text componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];

        if ([trimmed hasPrefix:@"```"]) {
            if (inCode) {
                NSString *block = [[codeLines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
                NSAttributedString *chunk = [[NSAttributedString alloc] initWithString:block attributes:@{
                    NSFontAttributeName: code,
                    NSForegroundColorAttributeName: codeInk,
                    NSBackgroundColorAttributeName: [OCPalette raised],
                    NSParagraphStyleAttributeName: codeStyle,
                }];
                [result appendAttributedString:chunk];
                [codeLines removeAllObjects];
                inCode = NO;
            } else {
                inCode = YES;
            }
            continue;
        }

        if (inCode) {
            [codeLines addObject:line];
            continue;
        }

        if (trimmed.length == 0) {
            [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:@{
                NSFontAttributeName: body,
                NSParagraphStyleAttributeName: bodyStyle,
            }]];
            continue;
        }

        // Заголовки
        NSUInteger hashes = 0;
        while (hashes < trimmed.length && [trimmed characterAtIndex:hashes] == '#') hashes++;
        if (hashes > 0 && hashes <= 4 && trimmed.length > hashes + 1) {
            NSString *title = [trimmed substringFromIndex:hashes];
            title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            UIFont *font = hashes <= 2 ? OCFont(UIFontTextStyleHeadline, UIFontWeightSemibold, 17)
                                       : OCFont(UIFontTextStyleSubheadline, UIFontWeightSemibold, 15);
            [result appendAttributedString:[[NSAttributedString alloc] initWithString:[title stringByAppendingString:@"\n"]
                                                                           attributes:@{
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: ink,
                NSParagraphStyleAttributeName: bodyStyle,
            }]];
            continue;
        }

        // Пункты списка
        BOOL isBullet = [trimmed hasPrefix:@"- "] || [trimmed hasPrefix:@"* "] || [trimmed hasPrefix:@"+ "];
        NSString *lineText = line;
        if (isBullet) {
            lineText = [@"•  " stringByAppendingString:[trimmed substringFromIndex:2]];
        }

        NSMutableAttributedString *chunk =
            [[NSMutableAttributedString alloc] initWithString:[lineText stringByAppendingString:@"\n"]
                                                   attributes:@{
                NSFontAttributeName: body,
                NSForegroundColorAttributeName: ink,
                NSParagraphStyleAttributeName: isBullet ? listStyle : bodyStyle,
            }];

        // `код` внутри строки
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"`([^`]+)`" options:0 error:nil];
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:chunk.string options:0 range:NSMakeRange(0, chunk.length)];
        for (NSTextCheckingResult *match in matches.reverseObjectEnumerator) {
            NSRange full = match.range;
            NSRange inner = [match rangeAtIndex:1];
            NSString *value = [chunk.string substringWithRange:inner];
            [chunk replaceCharactersInRange:full withString:value];
            NSRange applied = NSMakeRange(full.location, value.length);
            [chunk addAttribute:NSFontAttributeName value:code range:applied];
            [chunk addAttribute:NSBackgroundColorAttributeName value:[OCPalette raised] range:applied];
        }

        // **жирный**
        NSArray<NSTextCheckingResult *> *bolds = [[NSRegularExpression regularExpressionWithPattern:@"\\*\\*([^*]+)\\*\\*"
                                                                                            options:0 error:nil]
                                                  matchesInString:chunk.string options:0 range:NSMakeRange(0, chunk.length)];
        for (NSTextCheckingResult *match in bolds.reverseObjectEnumerator) {
            NSRange inner = [match rangeAtIndex:1];
            NSString *value = [chunk.string substringWithRange:inner];
            [chunk replaceCharactersInRange:match.range withString:value];
            [chunk addAttribute:NSFontAttributeName value:bold range:NSMakeRange(inner.location, value.length)];
        }

        [result appendAttributedString:chunk];
    }

    if (inCode && codeLines.count) {
        NSString *block = [[codeLines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:block attributes:@{
            NSFontAttributeName: code,
            NSForegroundColorAttributeName: codeInk,
            NSBackgroundColorAttributeName: [OCPalette raised],
            NSParagraphStyleAttributeName: codeStyle,
        }]];
    }

    return result;
}

// MARK: - Пузырь

@interface OCBubbleCell : UITableViewCell

- (void)configureWithMessage:(OCMessage *)message expanded:(BOOL)expanded;
- (void)configureWithStreamingText:(NSString *)text reasoning:(NSString *)reasoning;

@property (nonatomic, copy) void (^onToggleReasoning)(void);

@end

@implementation OCBubbleCell {
    UIView *_bubble;
    UILabel *_label;
    UIButton *_expand;
    NSLayoutConstraint *_leftInset;
    NSLayoutConstraint *_rightInset;
    NSLayoutConstraint *_plainBottom;
    NSLayoutConstraint *_expandedBottom;
    NSLayoutConstraint *_minLeading;
    NSLayoutConstraint *_maxTrailing;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _bubble = [[UIView alloc] init];
        _bubble.translatesAutoresizingMaskIntoConstraints = NO;
        _bubble.layer.cornerRadius = 18;
        _bubble.layer.cornerCurve = kCACornerCurveContinuous;
        [self.contentView addSubview:_bubble];

        _label = [[UILabel alloc] init];
        _label.translatesAutoresizingMaskIntoConstraints = NO;
        _label.numberOfLines = 0;
        [_bubble addSubview:_label];

        _expand = [UIButton buttonWithType:UIButtonTypeSystem];
        _expand.translatesAutoresizingMaskIntoConstraints = NO;
        _expand.titleLabel.font = OCFont(UIFontTextStyleCaption1, UIFontWeightMedium, 12);
        [_expand setTitleColor:[OCPalette blue] forState:UIControlStateNormal];
        [_expand addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
        [_bubble addSubview:_expand];

        _leftInset = [_bubble.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16];
        _rightInset = [_bubble.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16];
        _minLeading = [_bubble.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:56];
        _maxTrailing = [_bubble.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16];

        [NSLayoutConstraint activateConstraints:@[
            [_bubble.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],

            [_label.topAnchor constraintEqualToAnchor:_bubble.topAnchor constant:12],
            [_label.leadingAnchor constraintEqualToAnchor:_bubble.leadingAnchor constant:14],
            [_label.trailingAnchor constraintEqualToAnchor:_bubble.trailingAnchor constant:-14],

            [_expand.topAnchor constraintEqualToAnchor:_label.bottomAnchor constant:4],
            [_expand.leadingAnchor constraintEqualToAnchor:_label.leadingAnchor],
            [_expand.heightAnchor constraintEqualToConstant:20],

            [_bubble.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        ]];

        _plainBottom = [_label.bottomAnchor constraintEqualToAnchor:_bubble.bottomAnchor constant:-12];
        _expandedBottom = [_expand.bottomAnchor constraintEqualToAnchor:_bubble.bottomAnchor constant:-8];
        _plainBottom.active = YES;
    }
    return self;
}

- (void)toggle {
    if (self.onToggleReasoning) self.onToggleReasoning();
}

- (void)configureWithMessage:(OCMessage *)message expanded:(BOOL)expanded {
    BOOL user = message.isUser;

    UIColor *fill = user ? [OCPalette raised] : UIColor.clearColor;
    _bubble.backgroundColor = fill;
    _bubble.layer.borderWidth = user ? 0 : 0;

    _leftInset.active = NO;
    _rightInset.active = NO;
    _minLeading.active = NO;
    _maxTrailing.active = NO;
    _plainBottom.active = NO;
    _expandedBottom.active = NO;
    _plainBottom.active = YES;
    if (user) {
        _rightInset.active = YES;
        _minLeading.active = YES;
    } else {
        _leftInset.active = YES;
        _maxTrailing.active = YES;
    }

    if (user) {
        _label.font = OCFont(UIFontTextStyleBody, UIFontWeightRegular, 16);
        _label.textColor = [OCPalette text];
        _label.attributedText = [[NSAttributedString alloc] initWithString:message.userText attributes:@{
            NSFontAttributeName: OCFont(UIFontTextStyleBody, UIFontWeightRegular, 16),
            NSForegroundColorAttributeName: [OCPalette text],
        }];
        _expand.hidden = YES;
        _expand.titleLabel.text = @"";
        return;
    }

    // Ассистент: рассуждения, инструменты, текст.
    NSMutableString *reasoning = [NSMutableString string];
    NSMutableString *answer = [NSMutableString string];
    NSMutableArray<OCPart *> *tools = [NSMutableArray array];

    for (OCPart *part in message.parts) {
        if (part.isReasoning && part.text.length) [reasoning appendString:part.text];
        if (part.isText && part.text.length) [answer appendString:part.text];
        if (part.isTool) [tools addObject:part];
    }
    if (answer.length == 0 && message.text.length) [answer appendString:message.text];

    NSMutableAttributedString *combined = [[NSMutableAttributedString alloc] init];

    if (tools.count) {
        NSMutableString *toolLine = [NSMutableString string];
        for (OCPart *tool in tools) {
            NSString *mark = tool.isFailed ? @"⚠︎" : (tool.isRunning ? @"·" : @"✓");
            NSString *detail = tool.summary.length ? [NSString stringWithFormat:@" %@", tool.summary] : @"";
            [toolLine appendFormat:@"%@ %@%@\n", mark, tool.toolTitle, detail];
        }
        [combined appendAttributedString:[[NSAttributedString alloc] initWithString:toolLine attributes:@{
            NSFontAttributeName: [UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightRegular],
            NSForegroundColorAttributeName: [OCPalette secondaryText],
        }]];
        [combined appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    }

    if (reasoning.length) {
        NSString *shown = reasoning;
        if (!expanded && shown.length > 320) {
            shown = [[shown substringToIndex:320] stringByAppendingString:@"…"];
        }
        NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
        style.lineSpacing = 2;
        style.paragraphSpacing = 8;
        [combined appendAttributedString:[[NSAttributedString alloc] initWithString:[shown stringByAppendingString:@"\n"]
                                                                        attributes:@{
            NSFontAttributeName: OCFont(UIFontTextStyleFootnote, UIFontWeightRegular, 13),
            NSForegroundColorAttributeName: [OCPalette tertiaryText],
            NSParagraphStyleAttributeName: style,
        }]];
    }

    if (answer.length) {
        [combined appendAttributedString:OCFormatMarkdown(answer)];
    } else if (reasoning.length == 0 && tools.count == 0) {
        [combined appendAttributedString:[[NSAttributedString alloc] initWithString:@"…" attributes:@{
            NSFontAttributeName: OCFont(UIFontTextStyleBody, UIFontWeightRegular, 16),
            NSForegroundColorAttributeName: [OCPalette tertiaryText],
        }]];
    }

    _label.attributedText = combined;

    BOOL canExpand = reasoning.length > 320;
    _expand.hidden = !canExpand;
    if (canExpand) {
        _plainBottom.active = NO;
        _expandedBottom.active = YES;
    }
    [_expand setTitle:(expanded ? @"Свернуть" : @"Показать размышления") forState:UIControlStateNormal];

    self.accessibilityLabel = user ? message.userText : (answer.length ? answer : reasoning);
}

- (void)configureWithStreamingText:(NSString *)text reasoning:(NSString *)reasoning {
    _bubble.backgroundColor = UIColor.clearColor;
    _leftInset.active = YES;
    _rightInset.active = NO;
    _minLeading.active = NO;
    _maxTrailing.active = YES;
    _expand.hidden = YES;
    _expandedBottom.active = NO;
    _plainBottom.active = YES;

    NSMutableAttributedString *combined = [[NSMutableAttributedString alloc] init];
    if (reasoning.length) {
        NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
        style.lineSpacing = 2;
        style.paragraphSpacing = 8;
        NSString *shown = reasoning.length > 320
            ? [[reasoning substringToIndex:320] stringByAppendingString:@"…"]
            : reasoning;
        [combined appendAttributedString:[[NSAttributedString alloc] initWithString:[shown stringByAppendingString:@"\n"]
                                                                        attributes:@{
            NSFontAttributeName: OCFont(UIFontTextStyleFootnote, UIFontWeightRegular, 13),
            NSForegroundColorAttributeName: [OCPalette tertiaryText],
            NSParagraphStyleAttributeName: style,
        }]];
    }
    if (text.length) {
        [combined appendAttributedString:OCFormatMarkdown(text)];
    } else if (reasoning.length == 0) {
        [combined appendAttributedString:[[NSAttributedString alloc] initWithString:@"Думаю…" attributes:@{
            NSFontAttributeName: OCFont(UIFontTextStyleBody, UIFontWeightRegular, 16),
            NSForegroundColorAttributeName: [OCPalette tertiaryText],
        }]];
    }
    _label.attributedText = combined;
}

@end

// MARK: - Чат

@interface OCChatController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) OCChatStore *store;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) OCComposer *composer;
@property (nonatomic, strong) UIView *banner;
@property (nonatomic, strong) UILabel *bannerLabel;
@property (nonatomic, strong) UIView *permissionBar;
@property (nonatomic, strong) UILabel *permissionTitle;
@property (nonatomic, strong) UILabel *permissionResource;
@property (nonatomic, strong) UIStackView *permissionActions;
@property (nonatomic, strong) NSMutableSet<NSString *> *expanded;
@property (nonatomic, assign) BOOL reloadScheduled;
@property (nonatomic, strong, nullable) OCPermission *shownPermission;

@end

@implementation OCChatController

- (instancetype)initWithStore:(OCChatStore *)store {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _store = store;
        _expanded = [NSMutableSet set];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [OCPalette background];

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.translatesAutoresizingMaskIntoConstraints = NO;
    _table.backgroundColor = UIColor.clearColor;
    _table.separatorStyle = UITableViewCellSeparatorStyleNone;
    _table.dataSource = self;
    _table.delegate = self;
    _table.estimatedRowHeight = 90;
    _table.rowHeight = UITableViewAutomaticDimension;
    _table.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    _table.contentInset = UIEdgeInsetsMake(10, 0, 12, 0);
    [_table registerClass:OCBubbleCell.class forCellReuseIdentifier:@"bubble"];
    [self.view addSubview:_table];

    _composer = [[OCComposer alloc] init];
    _composer.translatesAutoresizingMaskIntoConstraints = NO;
    _composer.placeholder = @"Сообщение";
    __weak typeof(self) weakSelf = self;
    _composer.onSend = ^(NSString *text) {
        [weakSelf.store sendText:text];
        [weakSelf.composer clear];
    };
    [self.view addSubview:_composer];

    _banner = [[UIView alloc] init];
    _banner.translatesAutoresizingMaskIntoConstraints = NO;
    _banner.backgroundColor = [OCPalette raised];
    _banner.layer.cornerRadius = 14;
    _banner.layer.cornerCurve = kCACornerCurveContinuous;

    _bannerLabel = [[UILabel alloc] init];
    _bannerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _bannerLabel.font = OCFont(UIFontTextStyleFootnote, UIFontWeightMedium, 13);
    _bannerLabel.textColor = [OCPalette text];
    _bannerLabel.numberOfLines = 0;
    [_banner addSubview:_bannerLabel];

    // Разрешение спрашивает агент, и ответить на него можно только здесь.
    // Поэтому панель стоит над полем ввода, а не теряется в переписке.
    _permissionBar = [self buildPermissionBar];

    UIStackView *bottom = [[UIStackView alloc] initWithArrangedSubviews:@[_permissionBar, _banner, _composer]];
    bottom.axis = UILayoutConstraintAxisVertical;
    bottom.spacing = 8;
    bottom.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bottom];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_table.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [_table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_table.bottomAnchor constraintEqualToAnchor:bottom.topAnchor constant:-6],

        [bottom.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [bottom.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [bottom.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor constant:-10],

        [_bannerLabel.topAnchor constraintEqualToAnchor:_banner.topAnchor constant:10],
        [_bannerLabel.leadingAnchor constraintEqualToAnchor:_banner.leadingAnchor constant:12],
        [_bannerLabel.trailingAnchor constraintEqualToAnchor:_banner.trailingAnchor constant:-12],
        [_bannerLabel.bottomAnchor constraintEqualToAnchor:_banner.bottomAnchor constant:-10],

        [_composer.heightAnchor constraintEqualToConstant:56],
    ]];

}

/// Стриминг присылает десятки обновлений в секунду, а перерисовка
/// таблицы с разбором markdown — дело небыстрое. Склеиваем.
- (void)scheduleReload {
    if (_reloadScheduled) return;
    _reloadScheduled = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        OCChatController *strongSelf = weakSelf;
        if (strongSelf == nil) return;
        strongSelf->_reloadScheduled = NO;
        [strongSelf reload];
    });
}

- (UIView *)buildPermissionBar {
    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = [[OCPalette warning] colorWithAlphaComponent:0.1];
    bar.layer.cornerRadius = 18;
    bar.layer.cornerCurve = kCACornerCurveContinuous;
    bar.layer.borderWidth = 1;
    bar.layer.borderColor = [[OCPalette warning] colorWithAlphaComponent:0.25].CGColor;
    bar.hidden = YES;

    _permissionTitle = [[UILabel alloc] init];
    _permissionTitle.font = OCFont(UIFontTextStyleFootnote, UIFontWeightRegular, 13);
    _permissionTitle.textColor = [OCPalette secondaryText];
    _permissionTitle.numberOfLines = 3;

    _permissionResource = [[UILabel alloc] init];
    _permissionResource.font = [UIFont monospacedSystemFontOfSize:11.5 weight:UIFontWeightRegular];
    _permissionResource.textColor = [OCPalette secondaryText];
    _permissionResource.numberOfLines = 2;
    _permissionResource.lineBreakMode = NSLineBreakByTruncatingMiddle;

    _permissionActions = [[UIStackView alloc] init];
    _permissionActions.axis = UILayoutConstraintAxisHorizontal;
    _permissionActions.spacing = 8;
    _permissionActions.distribution = UIStackViewDistributionFillEqually;

    NSArray<NSString *> *titles = @[@"Разрешить", @"Всегда", @"Нет"];
    NSArray<NSString *> *decisions = @[@"once", @"always", @"reject"];
    NSArray<UIColor *> *tints = @[[OCPalette blue], [OCPalette violet], [OCPalette coral]];
    for (NSUInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:titles[i] forState:UIControlStateNormal];
        button.titleLabel.font = OCFont(UIFontTextStyleCaption1, UIFontWeightSemibold, 12.5);
        UIColor *tint = tints[i];
        button.backgroundColor = i == 0 ? tint : [tint colorWithAlphaComponent:0.14];
        [button setTitleColor:(i == 0 ? UIColor.whiteColor : tint) forState:UIControlStateNormal];
        button.layer.cornerRadius = 11;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        [button.heightAnchor constraintEqualToConstant:34].active = YES;

        NSString *decision = decisions[i];
        __weak typeof(self) weakSelf = self;
        [button addAction:[UIAction actionWithHandler:^(UIAction *action) {
            OCChatController *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf.shownPermission == nil) return;
            [OCHaptic tap];
            [strongSelf.store replyToPermission:strongSelf.shownPermission decision:decision];
        }] forControlEvents:UIControlEventTouchUpInside];
        [_permissionActions addArrangedSubview:button];
    }

    UIImageView *shield = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.shield"]];
    shield.tintColor = [OCPalette warning];
    shield.contentMode = UIViewContentModeScaleAspectFit;
    [shield.widthAnchor constraintEqualToConstant:15].active = YES;
    [shield.heightAnchor constraintEqualToConstant:15].active = YES;

    UILabel *heading = [[UILabel alloc] init];
    heading.text = @"Нужно разрешение";
    heading.font = OCFont(UIFontTextStyleCaption1, UIFontWeightSemibold, 12.5);
    heading.textColor = [OCPalette text];

    UIStackView *head = [[UIStackView alloc] initWithArrangedSubviews:@[shield, heading]];
    head.axis = UILayoutConstraintAxisHorizontal;
    head.spacing = 7;
    head.alignment = UIStackViewAlignmentCenter;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[head, _permissionTitle, _permissionResource, _permissionActions]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:bar.topAnchor constant:14],
        [stack.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:14],
        [stack.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-14],
        [stack.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-14],
    ]];
    return bar;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [OCPalette background];
    appearance.shadowColor = UIColor.clearColor;
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: [OCPalette text],
        NSFontAttributeName: OCRoundedFont(16, UIFontWeightSemibold),
    };
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    self.navigationController.navigationBar.tintColor = [OCPalette secondaryText];
    self.navigationItem.backButtonDisplayMode = UINavigationItemBackButtonDisplayModeMinimal;

    __weak typeof(self) weakSelf = self;
    _store.onChatChanged = ^{
        [weakSelf scheduleReload];
    };

    [self updateHeader];
    [self reload];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _store.onChatChanged = nil;
}

- (void)updateHeader {
    OCSession *session = _store.currentSession;
    self.navigationItem.title = session.isDraft ? @"Новый диалог" : session.displayTitle;

    if (_store.isWorking) {
        UIBarButtonItem *stop =
            [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"stop.circle"]
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(stop)];
        stop.accessibilityLabel = @"Остановить";
        self.navigationItem.rightBarButtonItem = stop;
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)stop {
    [OCHaptic tap];
    [_store stopGeneration];
}

// MARK: Данные

- (void)reload {
    [self updateHeader];

    BOOL showBanner = _store.phase != OCPhaseReady && _store.phaseMessage.length > 0;
    _banner.hidden = !showBanner;
    _bannerLabel.text = _store.phaseMessage;

    OCPermission *permission = _store.permissions.firstObject;
    _shownPermission = permission;
    _permissionBar.hidden = permission == nil;
    if (permission) {
        _permissionTitle.text = permission.title;
        NSString *resource = permission.resourceText;
        _permissionResource.text = resource;
        _permissionResource.hidden = resource.length == 0;
    }
    _composer.field.enabled = _store.phase == OCPhaseReady;

    CGFloat distance = self.table.contentSize.height - self.table.contentOffset.y - self.table.bounds.size.height;
    BOOL nearBottom = distance < 140;
    [self.table reloadData];
    if (nearBottom || _store.isWorking) [self scrollToBottom];
}

- (void)scrollToBottom {
    [self scrollToBottomAnimated:NO];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    NSInteger sections = (NSInteger)self.table.numberOfSections;
    for (NSInteger section = sections - 1; section >= 0; section--) {
        NSInteger rows = (NSInteger)[self.table numberOfRowsInSection:section];
        if (rows == 0) continue;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:rows - 1 inSection:section]
                              atScrollPosition:UITableViewScrollPositionBottom
                                      animated:animated];
        });
        return;
    }
}

- (BOOL)hasStreaming {
    // Пока сервер работает, внизу живая строка: сначала «Думаю…»,
    // потом настоящий текст. После финиша она держит последний ответ,
    // пока лента не перечитается — иначе ответ мигает и пропадает.
    return _store.isWorking
        || _store.streamingText.length > 0
        || _store.streamingReasoning.length > 0;
}

/// Незаконченный ответ сервера и живая строка — это одно и то же.
/// Показываем живую: в ней текст приходит быстрее, чем в ленте.
- (NSArray<OCMessage *> *)visibleMessages {
    NSArray<OCMessage *> *messages = _store.messages;
    if (messages.count == 0) return messages;

    // Незаконченный ответ уже показан живой строкой — второй раз не надо.
    BOOL live = _store.isWorking
        || _store.streamingText.length > 0
        || _store.streamingReasoning.length > 0;
    if (!live) return messages;

    OCMessage *last = messages.lastObject;
    if (last.isAssistant && !last.completed) {
        return [messages subarrayWithRange:NSMakeRange(0, messages.count - 1)];
    }
    return messages;
}

// MARK: Таблица

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.visibleMessages.count + (self.hasStreaming ? 1 : 0);
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0.001;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    OCBubbleCell *cell = [tableView dequeueReusableCellWithIdentifier:@"bubble" forIndexPath:indexPath];

    NSArray<OCMessage *> *messages = self.visibleMessages;
    if (indexPath.row < (NSInteger)messages.count) {
        OCMessage *message = messages[(NSUInteger)indexPath.row];
        BOOL expanded = [_expanded containsObject:message.identifier];
        [cell configureWithMessage:message expanded:expanded];

        __weak typeof(self) weakSelf = self;
        cell.onToggleReasoning = ^{
            if (expanded) {
                [weakSelf.expanded removeObject:message.identifier];
            } else {
                [weakSelf.expanded addObject:message.identifier];
            }
            [weakSelf.table reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        };
    } else {
        cell.onToggleReasoning = nil;
        [cell configureWithStreamingText:_store.streamingText reasoning:_store.streamingReasoning];
    }
    return cell;
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                    point:(CGPoint)point {
    NSArray<OCMessage *> *messages = self.visibleMessages;
    if (indexPath.row >= (NSInteger)messages.count) return nil;

    OCMessage *message = messages[(NSUInteger)indexPath.row];
    NSString *text = message.isUser ? message.userText : message.assistantText;
    if (text.length == 0) return nil;

    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        return [UIMenu menuWithTitle:@""
                            children:@[[UIAction actionWithTitle:@"Скопировать"
                                                           image:[UIImage systemImageNamed:@"doc.on.doc"]
                                                      identifier:nil
                                                         handler:^(UIAction *action) {
            UIPasteboard.generalPasteboard.string = text;
            [OCHaptic success];
        }]]];
    }];
}

@end
