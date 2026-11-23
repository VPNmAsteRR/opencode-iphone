#import "API.h"
#import "Models.h"

NSString *const OCAPIErrorDomain = @"OCAPIError";

static NSError *OCError(OCAPIErrorCode code, NSString *message) {
    return [NSError errorWithDomain:OCAPIErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static NSString *OCTransportMessage(NSError *error) {
    switch (error.code) {
        case NSURLErrorNotConnectedToInternet:
            return @"Нет интернета. Проверьте сеть и VPN.";
        case NSURLErrorCannotFindHost:
        case NSURLErrorCannotConnectToHost:
        case NSURLErrorDNSLookupFailed:
            return @"Сервер не отвечает. Компьютер включён?";
        case NSURLErrorTimedOut:
            return @"Сервер не ответил вовремя.";
        case NSURLErrorNetworkConnectionLost:
            return @"Связь прервалась.";
        case NSURLErrorSecureConnectionFailed:
        case NSURLErrorServerCertificateUntrusted:
            return @"Защищённое соединение не установилось.";
        case NSURLErrorCancelled:
            return @"Запрос отменён.";
        default:
            return @"Сервер недоступен.";
    }
}

@interface OCAPI () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *streamTask;
@property (nonatomic, copy, nullable) void (^streamHandler)(NSDictionary *event);
@property (nonatomic, strong) NSMutableData *streamBuffer;
@property (nonatomic, assign) BOOL streaming;
@property (nonatomic, assign) NSInteger reconnectAttempt;

@end

@implementation OCAPI

- (instancetype)initWithBaseURL:(NSString *)baseURL
                       username:(NSString *)username
                       password:(NSString *)password {
    self = [super init];
    if (self) {
        _baseURL = [baseURL copy];
        _username = [username copy] ?: @"";
        _password = [password copy] ?: @"";

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        // Без waitsForConnectivity: иначе система держит запрос вечно
        // и человек видит бесконечную загрузку вместо понятной ошибки.
        config.timeoutIntervalForRequest = 15;
        config.timeoutIntervalForResource = 30;
        config.waitsForConnectivity = NO;
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        _session = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    }
    return self;
}

- (void)dealloc {
    [self stopEventStream];
    [_session invalidateAndCancel];
}

// MARK: - Запросы

- (NSURL *)urlForPath:(NSString *)path {
    NSString *base = [self.baseURL stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    while ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    if (base.length == 0) return nil;
    return [NSURL URLWithString:[base stringByAppendingString:path]];
}

- (NSMutableURLRequest *)requestFor:(NSString *)method path:(NSString *)path body:(nullable id)body {
    NSURL *url = [self urlForPath:path];
    if (url == nil) return nil;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    request.timeoutInterval = 20;

    if (self.username.length || self.password.length) {
        NSString *pair = [NSString stringWithFormat:@"%@:%@", self.username, self.password];
        NSString *token = [[pair dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
        [request setValue:[@"Basic " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];
    }

    if (body) {
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    return request;
}

- (void)perform:(NSString *)method
           path:(NSString *)path
           body:(nullable id)body
     completion:(void (^)(id _Nullable json, NSError *_Nullable error))completion {
    NSMutableURLRequest *request = [self requestFor:method path:path body:body];
    if (request == nil) {
        completion(nil, OCError(OCAPIErrorCodeBadURL, @"Неверный адрес сервера."));
        return;
    }

    NSURLSessionDataTask *task =
        [self.session dataTaskWithRequest:request
                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, OCError(OCAPIErrorCodeTransport, OCTransportMessage(error)));
            return;
        }
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        if (status == 401 || status == 403) {
            completion(nil, OCError(OCAPIErrorCodeUnauthorized, @"Сервер не принял логин или пароль."));
            return;
        }
        if (status < 200 || status > 299) {
            NSString *message = [NSString stringWithFormat:@"Сервер ответил ошибкой %ld.", (long)status];
            completion(nil, OCError(OCAPIErrorCodeHTTP, message));
            return;
        }
        if (data.length == 0) {
            completion(nil, nil);
            return;
        }
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (json == nil) {
            completion(nil, OCError(OCAPIErrorCodeDecoding, @"Непонятный ответ сервера."));
            return;
        }
        completion(json, nil);
    }];
    [task resume];
}

/// Сервер заворачивает списки в `data`, но иногда отдаёт массив напрямую.
static NSArray *OCPayloadArray(id json) {
    if ([json isKindOfClass:NSArray.class]) return json;
    NSDictionary *dict = OCDict(json);
    if (dict) {
        NSArray *data = OCArray(dict[@"data"]);
        if (data) return data;
    }
    return nil;
}

// MARK: - Проверка связи

- (void)probeWithCompletion:(void (^)(NSString *_Nullable, NSError *_Nullable))completion {
    [self perform:@"GET" path:@"/api/info" body:nil completion:^(id json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSDictionary *dict = OCDict(json);
        NSString *version = OCString(dict[@"version"]);
        completion(version ?: @"", nil);
    }];
}

// MARK: - Сессии

- (void)fetchSessionsWithCompletion:(void (^)(NSArray<OCSession *> *_Nullable, NSError *_Nullable))completion {
    [self perform:@"GET" path:@"/api/session" body:nil completion:^(id json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSArray *raw = OCPayloadArray(json);
        if (raw == nil) {
            completion(nil, OCError(OCAPIErrorCodeDecoding, @"Список сессий не разобрать."));
            return;
        }
        NSMutableArray<OCSession *> *sessions = [NSMutableArray array];
        for (id item in raw) {
            OCSession *session = [OCSession sessionFrom:item];
            if (session) [sessions addObject:session];
        }
        [sessions sortUsingComparator:^NSComparisonResult(OCSession *a, OCSession *b) {
            return a.updatedAt > b.updatedAt ? NSOrderedAscending : NSOrderedDescending;
        }];
        completion(sessions, nil);
    }];
}

- (void)fetchMessagesForSession:(NSString *)sessionID
                     completion:(void (^)(NSArray<OCMessage *> *_Nullable, NSError *_Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/api/session/%@/message", sessionID];
    [self perform:@"GET" path:path body:nil completion:^(id json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSArray *raw = OCPayloadArray(json);
        if (raw == nil) {
            completion(@[], nil);
            return;
        }
        NSMutableArray<OCMessage *> *messages = [NSMutableArray array];
        for (id item in raw) {
            OCMessage *message = [OCMessage messageFrom:item];
            if (message.isVisible) [messages addObject:message];
        }
        // Сервер отдаёт свежие сверху. В чате нужен обратный порядок:
        // иначе ответ оказывается выше вопроса.
        [messages sortUsingComparator:^NSComparisonResult(OCMessage *a, OCMessage *b) {
            if (a.createdAt == b.createdAt) return NSOrderedSame;
            return a.createdAt < b.createdAt ? NSOrderedAscending : NSOrderedDescending;
        }];
        completion(messages, nil);
    }];
}

- (void)fetchPermissionsForSession:(NSString *)sessionID
                        completion:(void (^)(NSArray<OCPermission *> *_Nullable, NSError *_Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/api/session/%@/permission", sessionID];
    [self perform:@"GET" path:path body:nil completion:^(id json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSArray *raw = OCPayloadArray(json) ?: @[];
        NSMutableArray<OCPermission *> *permissions = [NSMutableArray array];
        for (id item in raw) {
            OCPermission *permission = [OCPermission permissionFrom:item];
            if (permission) [permissions addObject:permission];
        }
        completion(permissions, nil);
    }];
}

- (void)createSessionWithTitle:(NSString *)title
                    completion:(void (^)(OCSession *_Nullable, NSError *_Nullable))completion {
    NSDictionary *body = @{@"title": title ?: @"", @"location": [NSNull null]};
    [self perform:@"POST" path:@"/api/session" body:body completion:^(id json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSDictionary *dict = OCDict(json);
        NSDictionary *payload = OCDict(dict[@"data"]) ?: dict;
        OCSession *session = [OCSession sessionFrom:payload];
        if (session == nil) {
            completion(nil, OCError(OCAPIErrorCodeDecoding, @"Сервер не вернул сессию."));
            return;
        }
        completion(session, nil);
    }];
}

- (void)sendPrompt:(NSString *)text
         sessionID:(NSString *)sessionID
        completion:(void (^)(NSError *_Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/api/session/%@/prompt", sessionID];
    NSDictionary *body = @{@"text": text};
    [self perform:@"POST" path:path body:body completion:^(id json, NSError *error) {
        completion(error);
    }];
}

- (void)interruptSession:(NSString *)sessionID
              completion:(void (^)(NSError *_Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/api/session/%@/interrupt", sessionID];
    [self perform:@"POST" path:path body:@{} completion:^(id json, NSError *error) {
        completion(error);
    }];
}

- (void)replyToPermission:(NSString *)permissionID
                sessionID:(NSString *)sessionID
                 decision:(NSString *)decision
               completion:(void (^)(NSError *_Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/api/session/%@/permission/%@/reply", sessionID, permissionID];
    [self perform:@"POST" path:path body:@{@"decision": decision} completion:^(id json, NSError *error) {
        completion(error);
    }];
}

- (void)deleteSession:(NSString *)sessionID
           completion:(void (^)(NSError *_Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/api/session/%@", sessionID];
    [self perform:@"DELETE" path:path body:nil completion:^(id json, NSError *error) {
        completion(error);
    }];
}

// MARK: - Поток событий

- (void)startEventStream:(void (^)(NSDictionary *))onEvent {
    [self stopEventStream];
    self.streamHandler = onEvent;
    self.streaming = YES;
    self.reconnectAttempt = 0;
    [self connectStream];
}

- (void)stopEventStream {
    self.streaming = NO;
    [self.streamTask cancel];
    self.streamTask = nil;
    self.streamHandler = nil;
    self.streamBuffer = nil;
}

- (void)connectStream {
    if (!self.streaming) return;
    NSMutableURLRequest *request = [self requestFor:@"GET" path:@"/api/event" body:nil];
    if (request == nil) return;
    request.timeoutInterval = 3600;
    [request setValue:@"text/event-stream" forHTTPHeaderField:@"Accept"];

    self.streamBuffer = [NSMutableData data];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:self.session.configuration
                                                         delegate:self
                                                    delegateQueue:nil];
    self.streamTask = [session dataTaskWithRequest:request];
    [self.streamTask resume];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSInteger status = [(NSHTTPURLResponse *)response statusCode];
    if (status == 401 || status == 403) {
        completionHandler(NSURLSessionResponseCancel);
        [self scheduleReconnect];
        return;
    }
    self.reconnectAttempt = 0;
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    if (self.streamBuffer == nil) self.streamBuffer = [NSMutableData data];
    [self.streamBuffer appendData:data];

    // События разделены пустой строкой; разбираем всё, что уже пришло целиком.
    const char *bytes = self.streamBuffer.bytes;
    NSUInteger length = self.streamBuffer.length;
    NSUInteger consumed = 0;
    NSUInteger lineStart = 0;

    for (NSUInteger i = 0; i < length; i++) {
        if (bytes[i] != '\n') continue;

        NSUInteger lineLength = i - lineStart;
        if (lineLength > 0 && bytes[lineStart + lineLength - 1] == '\r') lineLength--;

        if (lineLength == 0) {
            // Пустая строка: конец одного события, всё до неё уже разобрано построчно.
            consumed = i + 1;
            lineStart = i + 1;
            continue;
        }

        if (lineLength > 5 && strncmp(bytes + lineStart, "data:", 5) == 0) {
            NSUInteger start = lineStart + 5;
            while (start < lineStart + lineLength && bytes[start] == ' ') start++;
            NSData *payload = [NSData dataWithBytes:bytes + start length:(lineStart + lineLength) - start];
            id json = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
            NSDictionary *event = OCDict(json);
            if (event && self.streamHandler) self.streamHandler(event);
        }
        lineStart = i + 1;
    }

    if (consumed > 0) {
        [self.streamBuffer replaceBytesInRange:NSMakeRange(0, consumed) withBytes:NULL length:0];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (!self.streaming) return;
    [self scheduleReconnect];
}

- (void)scheduleReconnect {
    if (!self.streaming) return;
    self.reconnectAttempt = MIN(self.reconnectAttempt + 1, 8);
    NSTimeInterval delay = MIN(0.7 * self.reconnectAttempt, 5.0);

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [weakSelf connectStream];
    });
}

@end
