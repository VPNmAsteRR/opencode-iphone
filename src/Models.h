#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Разбор ответов сервера терпимый: любое недостающее поле просто nil,
// а не падение декодера. Сервер меняется между версиями.

NSString *_Nullable OCString(id _Nullable value);
NSDictionary *_Nullable OCDict(id _Nullable value);
NSArray *_Nullable OCArray(id _Nullable value);
double OCNumber(id _Nullable value);

@interface OCSession : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *agent;
@property (nonatomic, copy, nullable) NSString *directory;
@property (nonatomic, copy, nullable) NSString *modelID;
@property (nonatomic, copy, nullable) NSString *providerID;
@property (nonatomic, assign) NSTimeInterval updatedAt;
@property (nonatomic, assign) NSTimeInterval createdAt;
/// Локальная заготовка: ещё не существует на сервере.
@property (nonatomic, assign) BOOL isDraft;

+ (nullable instancetype)sessionFrom:(id)json;
- (NSString *)displayTitle;
- (NSString *)projectName;

@end

@interface OCPart : NSObject

@property (nonatomic, copy) NSString *type;      // text | reasoning | tool
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, copy, nullable) NSString *identifier;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) NSString *status;   // running | completed | error
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *summary;

@property (nonatomic, readonly) BOOL isText;
@property (nonatomic, readonly) BOOL isReasoning;
@property (nonatomic, readonly) BOOL isTool;
@property (nonatomic, readonly) BOOL isFailed;
@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) NSString *toolTitle;

+ (nullable instancetype)partFrom:(id)json;

@end

@interface OCMessage : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *type;      // user | assistant
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, strong) NSArray<OCPart *> *parts;
@property (nonatomic, assign) NSTimeInterval createdAt;
@property (nonatomic, assign) BOOL completed;

@property (nonatomic, readonly) BOOL isUser;
@property (nonatomic, readonly) BOOL isAssistant;
@property (nonatomic, readonly) BOOL isVisible;
@property (nonatomic, readonly) NSString *userText;
@property (nonatomic, readonly) NSString *assistantText;

+ (nullable instancetype)messageFrom:(id)json;

@end

@interface OCPermission : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy, nullable) NSString *sessionID;
@property (nonatomic, copy, nullable) NSString *action;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, strong) NSArray<NSString *> *resources;

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly, nullable) NSString *resourceText;

+ (nullable instancetype)permissionFrom:(id)json;

@end

NS_ASSUME_NONNULL_END
