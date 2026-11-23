#import <Foundation/Foundation.h>
#import "Models.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OCPhase) {
    OCPhaseConnecting,
    OCPhaseReady,
    OCPhaseUnauthorized,
    OCPhaseFailed,
};

/// Всё состояние приложения и вся работа с сервером.
///
/// Телефон не держит свою правду: он слушает тот же сервер, что и
/// компьютер. Поэтому сообщение с ноутбука появляется здесь само.
@interface OCChatStore : NSObject

@property (nonatomic, readonly) OCPhase phase;
@property (nonatomic, copy, readonly, nullable) NSString *phaseMessage;

@property (nonatomic, copy, readonly) NSArray<OCSession *> *sessions;
@property (nonatomic, copy, readonly) NSArray<OCMessage *> *messages;
@property (nonatomic, copy, readonly) NSArray<OCPermission *> *permissions;

@property (nonatomic, strong, readonly, nullable) OCSession *currentSession;
@property (nonatomic, copy, readonly) NSString *streamingText;
@property (nonatomic, copy, readonly) NSString *streamingReasoning;
@property (nonatomic, readonly) BOOL isWorking;

/// Список сессий или их состояние поменялись.
@property (nonatomic, copy, nullable) void (^onSessionsChanged)(void);
/// Переписка, стриминг или разрешения поменялись.
@property (nonatomic, copy, nullable) void (^onChatChanged)(void);
/// Фаза подключения поменялась.
@property (nonatomic, copy, nullable) void (^onPhaseChanged)(void);

- (void)connect;
- (void)disconnect;

- (void)reloadSessions;

- (void)openSession:(OCSession *)session;
- (void)closeSession;
- (void)startDraft;

/// Отправить текст в текущую сессию. Если текущей нет, создаст новую.
- (void)sendText:(NSString *)text;
- (void)stopGeneration;

- (void)replyToPermission:(OCPermission *)permission decision:(NSString *)decision;
- (void)deleteSession:(OCSession *)session;

/// После возврата из фона: переподключиться и обновить всё.
- (void)refresh;

@end

NS_ASSUME_NONNULL_END
