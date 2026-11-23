#import <Foundation/Foundation.h>
#import "Models.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OCAPIErrorCode) {
    OCAPIErrorCodeBadURL = 1,
    OCAPIErrorCodeUnauthorized,
    OCAPIErrorCodeHTTP,
    OCAPIErrorCodeTransport,
    OCAPIErrorCodeDecoding,
};

extern NSString *const OCAPIErrorDomain;

@interface OCAPI : NSObject

@property (nonatomic, copy, nullable) NSString *baseURL;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;

- (instancetype)initWithBaseURL:(NSString *)baseURL
                       username:(NSString *)username
                       password:(NSString *)password;

/// Короткая проверка: отвечает ли сервер и принимает ли пароль.
/// Возвращает версию сервера.
- (void)probeWithCompletion:(void (^)(NSString *_Nullable version, NSError *_Nullable error))completion;

- (void)fetchSessionsWithCompletion:(void (^)(NSArray<OCSession *> *_Nullable sessions,
                                              NSError *_Nullable error))completion;

- (void)fetchMessagesForSession:(NSString *)sessionID
                     completion:(void (^)(NSArray<OCMessage *> *_Nullable messages,
                                          NSError *_Nullable error))completion;

- (void)fetchPermissionsForSession:(NSString *)sessionID
                        completion:(void (^)(NSArray<OCPermission *> *_Nullable permissions,
                                             NSError *_Nullable error))completion;

- (void)createSessionWithTitle:(NSString *)title
                    completion:(void (^)(OCSession *_Nullable session, NSError *_Nullable error))completion;

- (void)sendPrompt:(NSString *)text
         sessionID:(NSString *)sessionID
        completion:(void (^)(NSError *_Nullable error))completion;

- (void)interruptSession:(NSString *)sessionID
              completion:(void (^)(NSError *_Nullable error))completion;

- (void)replyToPermission:(NSString *)permissionID
                sessionID:(NSString *)sessionID
                 decision:(NSString *)decision
               completion:(void (^)(NSError *_Nullable error))completion;

- (void)deleteSession:(NSString *)sessionID
           completion:(void (^)(NSError *_Nullable error))completion;

/// Живой поток событий. Каждое событие приходит как словарь с ключами
/// `type` и `data`. Поток переподключается сам, пока его не отменят.
- (void)startEventStream:(void (^)(NSDictionary *event))onEvent;
- (void)stopEventStream;

@end

NS_ASSUME_NONNULL_END
