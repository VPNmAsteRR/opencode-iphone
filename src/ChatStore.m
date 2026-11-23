#import "ChatStore.h"
#import "API.h"
#import "Store.h"

@interface OCChatStore ()

@property (nonatomic, assign) OCPhase phase;
@property (nonatomic, copy, nullable) NSString *phaseMessage;
@property (nonatomic, copy) NSArray<OCSession *> *sessions;
@property (nonatomic, copy) NSArray<OCMessage *> *messages;
@property (nonatomic, copy) NSArray<OCPermission *> *permissions;
@property (nonatomic, strong, nullable) OCSession *currentSession;
@property (nonatomic, copy) NSString *streamingText;
@property (nonatomic, copy) NSString *streamingReasoning;
@property (nonatomic, assign) BOOL isWorking;
@property (nonatomic, strong, nullable) OCAPI *api;
@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, assign) BOOL connecting;
@property (nonatomic, copy, nullable) NSString *messagesSignature;

@end

@implementation OCChatStore

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessions = @[];
        _messages = @[];
        _permissions = @[];
        _streamingText = @"";
        _streamingReasoning = @"";
        _phase = OCPhaseConnecting;
    }
    return self;
}

- (void)dealloc {
    [self.pollTimer invalidate];
    [self.api stopEventStream];
}

// MARK: - Подключение

- (void)setPhase:(OCPhase)phase message:(NSString *)message {
    _phase = phase;
    _phaseMessage = [message copy];
    if (self.onPhaseChanged) self.onPhaseChanged();
}

- (void)connect {
    if (self.connecting && self.api != nil) return;
    self.connecting = YES;

    OCConnection *connection = [OCConnection shared];
    [self.api stopEventStream];
    self.api = nil;

    if (!connection.isComplete) {
        self.connecting = NO;
        [self setPhase:OCPhaseUnauthorized message:@"Нужны адрес и пароль сервера."];
        return;
    }

    [self setPhase:OCPhaseConnecting message:nil];
    OCAPI *api = [[OCAPI alloc] initWithBaseURL:connection.baseURL
                                      username:connection.username
                                      password:connection.password];
    self.api = api;

    __weak typeof(self) weakSelf = self;
    [api probeWithCompletion:^(NSString *version, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OCChatStore *store = weakSelf;
            if (store == nil || store.api != api) return;
            store.connecting = NO;

            if (error) {
                if (error.code == OCAPIErrorCodeUnauthorized) {
                    [store setPhase:OCPhaseUnauthorized message:error.localizedDescription];
                } else {
                    [store setPhase:OCPhaseFailed message:error.localizedDescription];
                }
                return;
            }

            [store setPhase:OCPhaseReady message:nil];
            [store reloadSessions];
            [store startStream];
            [store startPolling];
        });
    }];
}

- (void)disconnect {
    self.connecting = NO;
    [self setPhase:OCPhaseUnauthorized message:@"Нужны адрес и пароль сервера."];
    [self.pollTimer invalidate];
    self.pollTimer = nil;
    [self.api stopEventStream];
    self.api = nil;
    self.currentSession = nil;
    self.messages = @[];
    self.permissions = @[];
    self.streamingText = @"";
    self.streamingReasoning = @"";
    self.isWorking = NO;
}

- (void)refresh {
    if (self.connecting) return;
    // Связь могла пропасть, пока приложение спало: тогда всё заново,
    // а не тихие 401 на каждом запросе.
    if (self.api == nil || self.phase != OCPhaseReady) {
        [self connect];
        return;
    }
    [self reloadSessions];
    if (self.currentSession && !self.currentSession.isDraft) {
        [self loadMessagesFor:self.currentSession.identifier];
    }
    [self startStream];
}

// MARK: - Список сессий

- (void)reloadSessions {
    OCAPI *api = self.api;
    if (api == nil) return;

    __weak typeof(self) weakSelf = self;
    [api fetchSessionsWithCompletion:^(NSArray<OCSession *> *sessions, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OCChatStore *store = weakSelf;
            if (store == nil || store.api != api || sessions == nil) return;
            store.sessions = sessions;
            if (store.onSessionsChanged) store.onSessionsChanged();
        });
    }];
}

- (NSArray<OCSession *> *)sessionsMatching:(NSString *)query {
    NSString *needle = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
    if (needle.length == 0) return self.sessions;
    NSMutableArray *result = [NSMutableArray array];
    for (OCSession *session in self.sessions) {
        if ([session.displayTitle.lowercaseString containsString:needle] ||
            [session.projectName.lowercaseString containsString:needle]) {
            [result addObject:session];
        }
    }
    return result;
}

// MARK: - Открытие сессии

- (void)openSession:(OCSession *)session {
    self.currentSession = session;
    self.messagesSignature = nil;
    self.messages = @[];
    self.permissions = @[];
    self.streamingText = @"";
    self.streamingReasoning = @"";
    self.isWorking = NO;
    if (self.onChatChanged) self.onChatChanged();
    if (!session.isDraft) [self loadMessagesFor:session.identifier];
}

- (void)closeSession {
    self.currentSession = nil;
    self.messagesSignature = nil;
    self.messages = @[];
    self.permissions = @[];
    self.streamingText = @"";
    self.streamingReasoning = @"";
}

- (void)startDraft {
    OCSession *draft = [OCSession new];
    draft.identifier = [@"draft-" stringByAppendingString:NSUUID.UUID.UUIDString];
    draft.title = @"";
    draft.isDraft = YES;
    [self openSession:draft];
}

- (void)loadMessagesFor:(NSString *)sessionID {
    OCAPI *api = self.api;
    if (api == nil) return;

    __weak typeof(self) weakSelf = self;
    [api fetchMessagesForSession:sessionID completion:^(NSArray<OCMessage *> *messages, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OCChatStore *store = weakSelf;
            if (store == nil || store.api != api) return;
            if (![store.currentSession.identifier isEqualToString:sessionID]) return;
            if (messages == nil) return;

            store.messages = messages;

            // Сервер отдал ленту — значит она и есть правда. Живой текст
            // держим только пока идёт работа, иначе ответ задвоится.
            NSString *beforeStream = store.streamingText ?: @"";
            OCMessage *last = messages.lastObject;
            BOOL settled = last == nil || !(last.isAssistant && !last.completed);
            if (!store.isWorking && settled) {
                store.streamingText = @"";
                store.streamingReasoning = @"";
            }
            BOOL streamChanged = ![beforeStream isEqualToString:store.streamingText ?: @""];
            if (streamChanged || ![store messagesSignatureIs:[store signatureFor:messages]]) {
                if (store.onChatChanged) store.onChatChanged();
            }
            [store loadPermissionsFor:sessionID];
        });
    }];
}

/// Отпечаток ленты: если ничего не поменялось, таблицу незачем дёргать.
- (NSString *)signatureFor:(NSArray<OCMessage *> *)messages {
    NSMutableString *signature = [NSMutableString string];
    for (OCMessage *message in messages) {
        [signature appendFormat:@"%@:%lu:%lu|", message.identifier,
                               (unsigned long)message.parts.count,
                               (unsigned long)message.assistantText.length];
    }
    return signature;
}

- (BOOL)messagesSignatureIs:(NSString *)signature {
    if (_messagesSignature == nil) {
        _messagesSignature = signature;
        return NO;
    }
    BOOL same = [_messagesSignature isEqualToString:signature];
    _messagesSignature = signature;
    return same;
}

- (NSString *)permissionSignature {
    NSMutableString *signature = [NSMutableString string];
    for (OCPermission *permission in self.permissions) {
        [signature appendFormat:@"%@|", permission.identifier];
    }
    return signature;
}

- (void)loadPermissionsFor:(NSString *)sessionID {
    OCAPI *api = self.api;
    if (api == nil) return;

    __weak typeof(self) weakSelf = self;
    [api fetchPermissionsForSession:sessionID completion:^(NSArray<OCPermission *> *permissions, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OCChatStore *store = weakSelf;
            if (store == nil || store.api != api || permissions == nil) return;
            if (![store.currentSession.identifier isEqualToString:sessionID]) return;
            NSString *before = [store permissionSignature];
            store.permissions = permissions;
            if (![[store permissionSignature] isEqualToString:before]) {
                if (store.onChatChanged) store.onChatChanged();
            }
        });
    }];
}

// MARK: - Отправка

- (void)sendText:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) return;

    if (self.api == nil || self.phase != OCPhaseReady) {
        return;
    }

    if (self.currentSession == nil) [self startDraft];

    if (self.currentSession.isDraft) {
        [self createSessionThenPrompt:trimmed];
        return;
    }
    [self prompt:trimmed sessionID:self.currentSession.identifier];
}

- (void)createSessionThenPrompt:(NSString *)text {
    OCAPI *api = self.api;
    NSString *title = [self titleFromText:text];

    __weak typeof(self) weakSelf = self;
    [api createSessionWithTitle:title completion:^(OCSession *session, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OCChatStore *store = weakSelf;
            if (store == nil || store.api != api) return;

            if (session == nil) {
                [store setPhase:OCPhaseReady message:error.localizedDescription];
                if (store.onChatChanged) store.onChatChanged();
                return;
            }

            store.currentSession = session;
            store.messagesSignature = nil;
            store.messages = @[];
            if (store.onChatChanged) store.onChatChanged();
            [store reloadSessions];
            [store prompt:text sessionID:session.identifier];
        });
    }];
}

- (void)prompt:(NSString *)text sessionID:(NSString *)sessionID {
    OCAPI *api = self.api;
    self.streamingText = @"";
    self.streamingReasoning = @"";
    self.isWorking = YES;
    if (self.onChatChanged) self.onChatChanged();

    __weak typeof(self) weakSelf = self;
    [api sendPrompt:text sessionID:sessionID completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OCChatStore *store = weakSelf;
            if (store == nil || store.api != api) return;
            store.connecting = NO;

            if (error) {
                store.isWorking = NO;
                [store setPhase:OCPhaseReady message:error.localizedDescription];
                if (store.onChatChanged) store.onChatChanged();
                return;
            }
            // Сообщение пользователя показываем сразу, не дожидаясь сервера.
            [store loadMessagesFor:sessionID];
            [store reloadSessions];
        });
    }];
}

- (void)stopGeneration {
    NSString *sessionID = self.currentSession.identifier;
    if (sessionID.length == 0) return;
    OCAPI *api = self.api;
    __weak typeof(self) weakSelf = self;
    [api interruptSession:sessionID completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.isWorking = NO;
            if (weakSelf.onChatChanged) weakSelf.onChatChanged();
        });
    }];
}

- (void)replyToPermission:(OCPermission *)permission decision:(NSString *)decision {
    NSString *sessionID = permission.sessionID.length ? permission.sessionID : self.currentSession.identifier;
    OCAPI *api = self.api;

    NSMutableArray *remaining = [self.permissions mutableCopy];
    [remaining removeObject:permission];
    self.permissions = remaining;
    if (self.onChatChanged) self.onChatChanged();

    [api replyToPermission:permission.identifier
                 sessionID:sessionID
                  decision:decision
                completion:^(NSError *error) {
        if (error == nil) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadPermissionsFor:sessionID];
        });
    }];
}

- (void)deleteSession:(OCSession *)session {
    if (session.isDraft) return;
    OCAPI *api = self.api;
    __weak typeof(self) weakSelf = self;
    [api deleteSession:session.identifier completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OCChatStore *store = weakSelf;
            NSMutableArray *remaining = [store.sessions mutableCopy];
            [remaining removeObject:session];
            store.sessions = remaining;
            if ([store.currentSession.identifier isEqualToString:session.identifier]) {
                [store closeSession];
            }
            if (store.onSessionsChanged) store.onSessionsChanged();
        });
    }];
}

// MARK: - Живой поток

- (void)startStream {
    OCAPI *api = self.api;
    if (api == nil) return;

    __weak typeof(self) weakSelf = self;
    [api startEventStream:^(NSDictionary *event) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OCChatStore *store = weakSelf;
            if (store == nil || store.api != api) return;
            [store handleEvent:event];
        });
    }];
}

- (void)handleEvent:(NSDictionary *)event {
    NSString *type = OCString(event[@"type"]);
    NSDictionary *data = OCDict(event[@"data"]);
    NSString *sessionID = OCString(data[@"sessionID"]);
    NSString *current = self.currentSession.identifier;
    BOOL mine = sessionID.length > 0 && [sessionID isEqualToString:current];

    if ([type isEqualToString:@"session.text.delta"]) {
        if (!mine) return;
        NSString *delta = OCString(data[@"delta"]) ?: @"";
        self.streamingText = [self.streamingText stringByAppendingString:delta];
        self.isWorking = YES;
        if (self.onChatChanged) self.onChatChanged();
        return;
    }

    if ([type isEqualToString:@"session.text.started"]) {
        if (!mine) return;
        self.streamingText = @"";
        self.isWorking = YES;
        if (self.onChatChanged) self.onChatChanged();
        return;
    }

    if ([type isEqualToString:@"session.text.ended"]) {
        if (!mine) return;
        NSString *full = OCString(data[@"text"]);
        if (full.length) self.streamingText = full;
        [self scheduleReload];
        return;
    }

    if ([type isEqualToString:@"session.reasoning.delta"]) {
        if (!mine) return;
        NSString *delta = OCString(data[@"delta"]) ?: @"";
        self.streamingReasoning = [self.streamingReasoning stringByAppendingString:delta];
        if (self.onChatChanged) self.onChatChanged();
        return;
    }

    if ([type isEqualToString:@"session.reasoning.started"]) {
        if (!mine) return;
        self.streamingReasoning = @"";
        if (self.onChatChanged) self.onChatChanged();
        return;
    }

    if ([type isEqualToString:@"session.execution.started"]) {
        if (!mine) return;
        self.isWorking = YES;
        if (self.onChatChanged) self.onChatChanged();
        return;
    }

    if ([type isEqualToString:@"session.execution.succeeded"] ||
        [type isEqualToString:@"session.execution.failed"] ||
        [type isEqualToString:@"session.execution.interrupted"]) {
        if (!mine) return;
        self.isWorking = NO;
        self.streamingReasoning = @"";
        [self reloadSessions];
        // Даём серверу дописать completed, иначе последний ответ
        // на мгновение приедет недописанным.
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadCurrent) object:nil];
        [self performSelector:@selector(reloadCurrent) withObject:nil afterDelay:0.35];
        return;
    }

    if ([type isEqualToString:@"permission.asked"] ||
        [type isEqualToString:@"session.step.ended"] ||
        [type isEqualToString:@"session.step.streamed"]) {
        if (mine) [self scheduleReload];
        return;
    }

    // Сообщение поставлено в очередь: работа началась, ещё до первого токена.
    if ([type isEqualToString:@"session.inbox.enqueued"]) {
        if (mine) {
            self.isWorking = YES;
            if (self.onChatChanged) self.onChatChanged();
        }
        [self reloadSessions];
        return;
    }

    if ([type isEqualToString:@"session.created"] || [type isEqualToString:@"session.deleted"] ||
        [type isEqualToString:@"session.updated"] || [type isEqualToString:@"session.archived"] ||
        [type isEqualToString:@"session.moved"]) {
        [self reloadSessions];
        return;
    }
}

- (void)scheduleReload {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadCurrent) object:nil];
    [self performSelector:@selector(reloadCurrent) withObject:nil afterDelay:0.2];
}

- (void)reloadCurrent {
    NSString *sessionID = self.currentSession.identifier;
    if (sessionID.length == 0 || self.currentSession.isDraft) return;
    [self loadMessagesFor:sessionID];
    [self loadPermissionsFor:sessionID];
}

// MARK: - Страховка

- (void)startPolling {
    [self.pollTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 repeats:YES block:^(NSTimer *timer) {
        OCChatStore *store = weakSelf;
        if (store == nil) {
            [timer invalidate];
            return;
        }
        if (store.currentSession && !store.currentSession.isDraft && !store.isWorking) {
            [store loadMessagesFor:store.currentSession.identifier];
        }
    }];
}

// MARK: - Мелочи

- (NSString *)titleFromText:(NSString *)text {
    NSString *line = [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet].firstObject ?: text;
    line = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (line.length <= 48) return line;
    NSString *cut = [line substringToIndex:48];
    NSRange space = [cut rangeOfString:@" " options:NSBackwardsSearch];
    if (space.location != NSNotFound) cut = [cut substringToIndex:space.location];
    return [cut stringByAppendingString:@"…"];
}

@end
