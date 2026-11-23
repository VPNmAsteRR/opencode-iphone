#import "Models.h"

NSString *OCString(id value) {
    return [value isKindOfClass:NSString.class] ? value : nil;
}

NSDictionary *OCDict(id value) {
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

NSArray *OCArray(id value) {
    return [value isKindOfClass:NSArray.class] ? value : nil;
}

double OCNumber(id value) {
    if ([value isKindOfClass:NSNumber.class]) return [value doubleValue];
    if ([value isKindOfClass:NSString.class]) return [(NSString *)value doubleValue];
    return 0;
}

// MARK: - Сессия

@implementation OCSession

+ (instancetype)sessionFrom:(id)json {
    NSDictionary *dict = OCDict(json);
    NSString *identifier = OCString(dict[@"id"]);
    if (identifier.length == 0) return nil;

    OCSession *session = [OCSession new];
    session.identifier = identifier;

    NSString *title = OCString(dict[@"title"]);
    session.title = title.length ? title : @"";

    session.agent = OCString(dict[@"agent"]);

    NSDictionary *model = OCDict(dict[@"model"]);
    session.modelID = OCString(model[@"id"]);
    session.providerID = OCString(model[@"providerID"]);

    NSDictionary *location = OCDict(dict[@"location"]);
    session.directory = OCString(location[@"directory"]);

    NSDictionary *time = OCDict(dict[@"time"]);
    session.createdAt = OCNumber(time[@"created"]) / 1000.0;
    session.updatedAt = OCNumber(time[@"updated"]) / 1000.0;
    if (session.updatedAt <= 0) session.updatedAt = session.createdAt;

    return session;
}

- (NSString *)displayTitle {
    NSString *trimmed = [self.title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.length ? trimmed : @"Без названия";
}

- (NSString *)projectName {
    if (self.directory.length == 0) return @"Проект";
    return self.directory.lastPathComponent.length ? self.directory.lastPathComponent : self.directory;
}

@end

// MARK: - Часть сообщения

@implementation OCPart

+ (instancetype)partFrom:(id)json {
    NSDictionary *dict = OCDict(json);
    NSString *type = OCString(dict[@"type"]);
    if (type.length == 0) return nil;

    OCPart *part = [OCPart new];
    part.type = type;
    part.text = OCString(dict[@"text"]);
    part.identifier = OCString(dict[@"id"]);
    part.name = OCString(dict[@"name"]);

    NSDictionary *state = OCDict(dict[@"state"]);
    if (state) {
        part.status = OCString(state[@"status"]);
        part.title = OCString(state[@"title"]);
        part.summary = [self summaryFromInput:OCDict(state[@"input"])];
    }
    return part;
}

+ (NSString *)summaryFromInput:(NSDictionary *)input {
    if (input == nil) return nil;
    for (NSString *key in @[@"command", @"path", @"filePath", @"pattern", @"query", @"url", @"description"]) {
        NSString *value = OCString(input[key]);
        if (value.length) {
            return value.length > 120 ? [[value substringToIndex:120] stringByAppendingString:@"…"] : value;
        }
    }
    return nil;
}

- (BOOL)isText { return [self.type isEqualToString:@"text"]; }
- (BOOL)isReasoning { return [self.type isEqualToString:@"reasoning"]; }
- (BOOL)isTool { return [self.type isEqualToString:@"tool"]; }
- (BOOL)isFailed { return [self.status isEqualToString:@"error"] || [self.status isEqualToString:@"failed"]; }
- (BOOL)isRunning { return [self.status isEqualToString:@"running"] || [self.status isEqualToString:@"pending"]; }

- (NSString *)toolTitle {
    if (self.title.length) return self.title;
    NSString *name = self.name ?: @"";
    if ([name isEqualToString:@"bash"] || [name isEqualToString:@"shell"]) return @"Команда";
    if ([name isEqualToString:@"read"]) return @"Чтение";
    if ([name isEqualToString:@"write"]) return @"Запись";
    if ([name isEqualToString:@"edit"]) return @"Правка";
    if ([name isEqualToString:@"glob"]) return @"Поиск файлов";
    if ([name isEqualToString:@"grep"]) return @"Поиск по тексту";
    if ([name isEqualToString:@"list"]) return @"Список файлов";
    if ([name isEqualToString:@"webfetch"]) return @"Загрузка страницы";
    if ([name isEqualToString:@"websearch"]) return @"Поиск в интернете";
    if ([name isEqualToString:@"task"]) return @"Задача";
    if (name.length) return name.capitalizedString;
    return @"Инструмент";
}

@end

// MARK: - Сообщение

@implementation OCMessage

+ (instancetype)messageFrom:(id)json {
    NSDictionary *dict = OCDict(json);
    NSString *identifier = OCString(dict[@"id"]);
    if (identifier.length == 0) return nil;

    OCMessage *message = [OCMessage new];
    message.identifier = identifier;
    message.type = OCString(dict[@"type"]) ?: @"";

    NSDictionary *metadata = OCDict(dict[@"metadata"]);
    NSString *display = OCString(metadata[@"displayText"]);
    NSString *text = OCString(dict[@"text"]);
    message.text = display.length ? display : text;

    NSMutableArray<OCPart *> *parts = [NSMutableArray array];
    for (id raw in OCArray(dict[@"content"])) {
        OCPart *part = [OCPart partFrom:raw];
        if (part) [parts addObject:part];
    }
    message.parts = parts;

    NSDictionary *time = OCDict(dict[@"time"]);
    message.createdAt = OCNumber(time[@"created"]) / 1000.0;
    message.completed = time[@"completed"] != nil;
    return message;
}

- (BOOL)isUser { return [self.type isEqualToString:@"user"]; }
- (BOOL)isAssistant { return [self.type isEqualToString:@"assistant"]; }
- (BOOL)isVisible { return self.isUser || self.isAssistant; }

- (NSString *)userText {
    if (self.text.length) return self.text;
    NSMutableArray *chunks = [NSMutableArray array];
    for (OCPart *part in self.parts) {
        if (part.isText && part.text.length) [chunks addObject:part.text];
    }
    return [chunks componentsJoinedByString:@"\n\n"];
}

- (NSString *)assistantText {
    NSMutableArray *chunks = [NSMutableArray array];
    for (OCPart *part in self.parts) {
        if (part.isText && part.text.length) [chunks addObject:part.text];
    }
    if (chunks.count == 0 && self.text.length) return self.text;
    return [chunks componentsJoinedByString:@"\n\n"];
}

@end

// MARK: - Разрешение

@implementation OCPermission

+ (instancetype)permissionFrom:(id)json {
    NSDictionary *dict = OCDict(json);
    NSString *identifier = OCString(dict[@"id"]);
    if (identifier.length == 0) return nil;

    OCPermission *permission = [OCPermission new];
    permission.identifier = identifier;
    permission.sessionID = OCString(dict[@"sessionID"]);
    permission.action = OCString(dict[@"action"]);
    permission.message = OCString(dict[@"message"]) ?: OCString(dict[@"description"]);

    NSArray *list = OCArray(dict[@"resources"]);
    if (list) {
        NSMutableArray *strings = [NSMutableArray array];
        for (id item in list) {
            NSString *value = OCString(item);
            if (value.length) [strings addObject:value];
        }
        permission.resources = strings;
    } else {
        NSString *single = OCString(dict[@"resource"]);
        permission.resources = single.length ? @[single] : @[];
    }
    return permission;
}

- (NSString *)title {
    NSString *value = self.message.length ? self.message : self.action;
    if (value.length == 0) return @"Запрос доступа";
    return value;
}

- (NSString *)resourceText {
    if (self.resources.count == 0) return nil;
    return [self.resources componentsJoinedByString:@"\n"];
}

@end
