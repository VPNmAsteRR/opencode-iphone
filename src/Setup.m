#import "Setup.h"
#import "API.h"
#import "Components.h"
#import "Store.h"
#import "Theme.h"

@interface OCSSetupController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *urlField;
@property (nonatomic, strong) UITextField *userField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) OCPrimaryButton *connectButton;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) OCAPI *probeAPI;

@end

@implementation OCSSetupController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [OCPalette background];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];

    [stack addArrangedSubview:[self brandHeader]];
    [stack addArrangedSubview:[self fieldsCard]];
    [stack addArrangedSubview:[self errorLabel]];
    [stack addArrangedSubview:[self connectButton]];
    [stack addArrangedSubview:[self hintLabel]];

    if (self.canCancel) {
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:@"Отмена"
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(cancel)];
        self.navigationItem.leftBarButtonItem.tintColor = [OCPalette secondaryText];
    }

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:28],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-28],
    ]];

    [self fillFromConnection];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:!self.canCancel animated:animated];
}

- (void)dismissKeyboard { [self.view endEditing:YES]; }

- (void)cancel {
    if (self.onCancel) self.onCancel();
}

// MARK: Вид

- (UIView *)brandHeader {
    UIStackView *header = [[UIStackView alloc] init];
    header.axis = UILayoutConstraintAxisVertical;
    header.alignment = UIStackViewAlignmentLeading;
    header.spacing = 12;

    OCSparkView *spark = [[OCSparkView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    spark.translatesAutoresizingMaskIntoConstraints = NO;
    [spark.widthAnchor constraintEqualToConstant:44].active = YES;
    [spark.heightAnchor constraintEqualToConstant:44].active = YES;

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Подключение";
    title.font = OCRoundedFontScaled(UIFontTextStyleTitle1, 28, UIFontWeightBold);
    title.textColor = [OCPalette text];

    UILabel *body = [[UILabel alloc] init];
    body.text = @"Адрес того же сервера, к которому подключён компьютер. Логин и пароль берутся из настроек OpenCode.";
    body.font = OCFont(UIFontTextStyleSubheadline, UIFontWeightRegular, 14);
    body.textColor = [OCPalette secondaryText];
    body.numberOfLines = 0;

    [header addArrangedSubview:spark];
    [header addArrangedSubview:title];
    [header addArrangedSubview:body];
    return header;
}

- (UIView *)fieldsCard {
    OCCardView *card = [[OCCardView alloc] init];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    _urlField = [self fieldWithPlaceholder:@"https://сервер:4096" secure:NO];
    _urlField.textContentType = UITextContentTypeURL;
    _urlField.keyboardType = UIKeyboardTypeURL;
    _urlField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _urlField.autocorrectionType = UITextAutocorrectionTypeNo;
    _urlField.returnKeyType = UIReturnKeyNext;

    _userField = [self fieldWithPlaceholder:@"opencode" secure:NO];
    _userField.textContentType = UITextContentTypeUsername;
    _userField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _userField.autocorrectionType = UITextAutocorrectionTypeNo;
    _userField.returnKeyType = UIReturnKeyNext;

    _passwordField = [self fieldWithPlaceholder:@"Пароль сервера" secure:YES];
    _passwordField.textContentType = UITextContentTypePassword;
    _passwordField.returnKeyType = UIReturnKeyGo;
    _passwordField.delegate = self;

    for (UITextField *field in @[_urlField, _userField, _passwordField]) {
        [stack addArrangedSubview:field];
        if (field != _passwordField) {
            UIView *line = [[UIView alloc] init];
            line.backgroundColor = [OCPalette separator];
            line.translatesAutoresizingMaskIntoConstraints = NO;
            [line.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale].active = YES;
            [stack addArrangedSubview:line];
        }
    }

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:6],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-6],
    ]];
    return card;
}

- (UITextField *)fieldWithPlaceholder:(NSString *)placeholder secure:(BOOL)secure {
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.font = OCFont(UIFontTextStyleBody, UIFontWeightRegular, 16);
    field.textColor = [OCPalette text];
    field.tintColor = [OCPalette blue];
    field.secureTextEntry = secure;
    field.borderStyle = UITextBorderStyleNone;
    field.attributedPlaceholder =
        [[NSAttributedString alloc] initWithString:placeholder
                                        attributes:@{NSForegroundColorAttributeName: [OCPalette tertiaryText]}];
    field.accessibilityLabel = placeholder;
    [field.heightAnchor constraintEqualToConstant:48].active = YES;
    return field;
}

- (UILabel *)errorLabel {
    if (_errorLabel) return _errorLabel;
    _errorLabel = [[UILabel alloc] init];
    _errorLabel.font = OCFont(UIFontTextStyleFootnote, UIFontWeightMedium, 13);
    _errorLabel.textColor = [OCPalette coral];
    _errorLabel.numberOfLines = 0;
    _errorLabel.hidden = YES;
    return _errorLabel;
}

- (OCPrimaryButton *)connectButton {
    _connectButton = [[OCPrimaryButton alloc] initWithFrame:CGRectZero];
    [_connectButton setTitle:@"Подключиться" forState:UIControlStateNormal];
    [_connectButton addTarget:self action:@selector(connect) forControlEvents:UIControlEventTouchUpInside];
    return _connectButton;
}

- (UILabel *)hintLabel {
    UILabel *hint = [[UILabel alloc] init];
    hint.text = @"Адрес можно взять из команды oc-remote status на компьютере. Пароль хранится в Keychain.";
    hint.font = OCFont(UIFontTextStyleCaption1, UIFontWeightRegular, 12);
    hint.textColor = [OCPalette tertiaryText];
    hint.numberOfLines = 0;
    return hint;
}

- (void)fillFromConnection {
    OCConnection *connection = [OCConnection shared];
    _urlField.text = connection.baseURL;
    _userField.text = connection.username.length ? connection.username : @"opencode";
    _passwordField.text = connection.password;
}

// MARK: Действие

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self connect];
    return YES;
}

- (void)connect {
    [self.view endEditing:YES];

    NSString *raw = [_urlField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *user = _userField.text.length ? _userField.text : @"opencode";
    NSString *password = _passwordField.text;

    if (raw.length == 0) {
        [self showError:@"Укажите адрес сервера."];
        return;
    }
    if (![raw containsString:@"://"]) raw = [@"https://" stringByAppendingString:raw];
    NSURLComponents *components = [NSURLComponents componentsWithString:raw];
    if (components.host.length == 0) {
        [self showError:@"Адрес не похож на ссылку. Пример: https://oc.example.com:8443"];
        return;
    }
    if (password.length == 0) {
        [self showError:@"Нужен пароль сервера."];
        return;
    }

    [self hideError];
    [_connectButton setBusy:YES title:@"Проверяю"];

    self.probeAPI = [[OCAPI alloc] initWithBaseURL:components.string username:user password:password];
    __weak typeof(self) weakSelf = self;
    [self.probeAPI probeWithCompletion:^(NSString *version, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OCSSetupController *strongSelf = weakSelf;
            if (strongSelf == nil) return;

            if (error) {
                [strongSelf.connectButton setBusy:NO title:@"Подключиться"];
                [strongSelf showError:error.localizedDescription];
                return;
            }

            OCConnection *connection = [OCConnection shared];
            connection.baseURL = components.string;
            connection.username = user;
            connection.password = password;
            [connection save];

            [strongSelf.connectButton setBusy:NO title:@"Подключиться"];
            [OCHaptic success];
            if (strongSelf.onConnected) strongSelf.onConnected();
        });
    }];
}

- (void)showError:(NSString *)text {
    _errorLabel.text = text;
    _errorLabel.hidden = NO;
}

- (void)hideError {
    _errorLabel.text = nil;
    _errorLabel.hidden = YES;
}

@end
