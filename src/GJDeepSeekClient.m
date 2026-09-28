#import "GJDeepSeekClient.h"
#import "GJModels.h"
#import "GJPromptBuilder.h"
@interface GJDeepSeekClient () <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong) NSURLSessionDataTask *task;
@property(nonatomic, strong) NSMutableData *received;
@property(nonatomic, copy) void (^completion)(NSDictionary *, NSError *);
@property(nonatomic, strong) NSError *responseError;
@end
@implementation GJDeepSeekClient
- (void)analyzeMessages:(NSArray<NSDictionary *> *)messages APIKey:(NSString *)key model:(NSString *)model completion:(void (^)(NSDictionary *, NSError *))completion {
    [self cancel];
    if (!key.length || !model.length || !messages.count) { completion(nil, GJError(@"Key、模型或分析上下文缺失。")); return; }
    NSError *error = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:@{@"model":model, @"messages":messages,
        @"stream":@NO, @"max_tokens":@8000, @"response_format":@{@"type":@"json_object"}} options:0 error:&error];
    if (!body) { completion(nil, GJError(@"无法生成请求。")); return; }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.deepseek.com/chat/completions"]];
    request.HTTPMethod = @"POST"; request.HTTPBody = body;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.timeoutIntervalForRequest = 180; configuration.timeoutIntervalForResource = 240;
    configuration.URLCache = nil; configuration.HTTPCookieStorage = nil;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    self.completion = completion; self.received = [NSMutableData data]; self.responseError = nil;
    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:NSOperationQueue.mainQueue];
    self.task = [self.session dataTaskWithRequest:request]; [self.task resume];
}
- (void)cancel {
    self.completion = nil; [self.task cancel]; [self.session invalidateAndCancel];
    self.task = nil; self.session = nil; self.received = nil; self.responseError = nil;
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    // Never forward credentials or chat content to a redirect destination.
    completionHandler(nil);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if (session != self.session) { completionHandler(NSURLSessionResponseCancel); return; }
    NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
    if (status != 200) {
        NSString *hint = status == 400 ? @"请求参数或上下文超限，请减少聊天条数、精简记忆并检查模型名称" : status == 401 ? @"API Key 无效" : status == 402 ? @"账户余额不足" : status == 429 ? @"请求过于频繁，请稍后重试" : @"服务请求失败，请检查模型名称或稍后重试";
        self.responseError = GJError([NSString stringWithFormat:@"%@（HTTP %ld）", hint, (long)status]);
        completionHandler(NSURLSessionResponseCancel); return;
    }
    if (response.expectedContentLength > 262144) { self.responseError = GJError(@"服务响应过大，已停止接收。"); completionHandler(NSURLSessionResponseCancel); return; }
    completionHandler(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (session != self.session) return;
    if (self.received.length + data.length > 262144) { self.responseError = GJError(@"服务响应过大，已停止接收。"); [dataTask cancel]; return; }
    [self.received appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)networkError {
    if (session != self.session) return;
    NSError *error = self.responseError;
    if (!error && networkError) error = GJError(networkError.code == NSURLErrorTimedOut ? @"请求超时，请手动重试。" : @"网络请求失败或已取消，请检查网络后重试。");
    NSDictionary *result = nil;
    if (!error) {
        id root = [NSJSONSerialization JSONObjectWithData:self.received options:0 error:NULL];
        id choices = [root isKindOfClass:NSDictionary.class] ? root[@"choices"] : nil;
        id choice = [choices isKindOfClass:NSArray.class] && [choices count] ? choices[0] : nil;
        id message = [choice isKindOfClass:NSDictionary.class] ? choice[@"message"] : nil;
        id content = [message isKindOfClass:NSDictionary.class] ? message[@"content"] : nil;
        if (![content isKindOfClass:NSString.class] || ![choice[@"finish_reason"] isEqual:@"stop"]) error = GJError(@"AI 返回为空、被截断或格式异常，请重试。");
        else {
            id object = [NSJSONSerialization JSONObjectWithData:[content dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
            result = [GJPromptBuilder validatedAnalysis:object error:&error];
        }
    }
    void (^callback)(NSDictionary *, NSError *) = self.completion;
    self.completion = nil; self.task = nil; self.received = nil;
    [self.session finishTasksAndInvalidate]; self.session = nil;
    if (callback) callback(result, error);
}
@end
