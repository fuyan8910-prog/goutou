#import "GJAnalysisViewController.h"
#import "GJWeChatAdapter.h"
#import "GJDeepSeekClient.h"
#import "GJPromptBuilder.h"
#import "GJMemoryStore.h"
#import "GJPreferences.h"
#import "GJSettingsViewController.h"
#import "GJUI.h"
@interface GJAnalysisViewController ()
@property(nonatomic, weak) UIViewController *source;
@property(nonatomic, strong) GJChatContext *context;
@property(nonatomic, strong) GJDeepSeekClient *client;
@property(nonatomic, copy) NSArray<NSDictionary *> *payload;
@property(nonatomic, copy) NSDictionary *memory;
@property(nonatomic, copy) NSDictionary *result;
@property(nonatomic, copy) NSString *status;
@property(nonatomic, copy) NSString *model;
@property(nonatomic) BOOL refreshAfterSettings;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL includedMemory;
@property(nonatomic) NSUInteger memoryGeneration;
@property(nonatomic) NSInteger mode; // 0: daily, 1: recent memory update, 2: deep
@property(nonatomic, copy) NSString *focus;
@property(nonatomic, copy) NSDictionary *cachedRequest;
@property(nonatomic, copy) NSDictionary *cachedResult;
@end
@implementation GJAnalysisViewController
- (instancetype)initWithSourceController:(UIViewController *)controller {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) { _source = controller; _client = [GJDeepSeekClient new]; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"军师";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"设置" style:UIBarButtonItemStylePlain target:self action:@selector(settings)];
    self.tableView.rowHeight = UITableViewAutomaticDimension; self.tableView.estimatedRowHeight = 90;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.status || self.refreshAfterSettings) { self.refreshAfterSettings = NO; [self refresh]; }
}
- (void)dealloc { [_client cancel]; }
- (void)close { [self.client cancel]; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)settings {
    if (self.busy) return;
    self.refreshAfterSettings = YES;
    [self.navigationController pushViewController:[[GJSettingsViewController alloc] initWithContext:self.context] animated:YES];
}
- (void)refresh {
    if (self.busy) return;
    self.result = nil; self.payload = nil; self.memory = nil;
    self.model = GJPreferences.model;
    NSError *error = nil;
    self.context = [[GJWeChatAdapter new] contextFromController:self.source limit:(self.mode == 2 ? GJPreferences.messageCount : 20) error:&error];
    self.includedMemory = GJPreferences.memoryEnabled;
    self.memoryGeneration = GJMemoryStore.shared.generation;
    if (self.context && self.includedMemory && !error) self.memory = [GJMemoryStore.shared memoryForContext:self.context error:&error];
    if (self.context && !error) {
        self.payload = [GJPromptBuilder messagesForContext:self.context memory:self.memory mode:self.mode focus:self.focus];
        self.status = [NSString stringWithFormat:@"%@\n%@\n已读取 %lu 条。%@\n长期记忆：%@。内容尚未发送。", self.context.displayName, self.context.identityNote ?: @"", (unsigned long)self.context.messages.count, self.context.sourceNote, self.includedMemory ? @"开启" : @"关闭"];
    } else self.status = error.localizedDescription ?: @"无法读取聊天。";
    if (self.payload) {
        if (self.mode == 0) self.status = [self.status stringByAppendingString:@"\n省量模式完整携带累计摘要和明确记住的信息；关系、人物、事件分别最多600/600/800字，完整记忆仍保留本机。先查看发送预览。"];
        BOOL hasMemory = NO;
        for (NSString *value in self.memory.allValues) if (value.length) { hasMemory = YES; break; }
        self.status = [self.status stringByAppendingFormat:@"\n模式：%@。%@", [self modeName], hasMemory ? @"已载入此联系人保存的记忆，无需重读500条。" : @"本次没有载入已保存的记忆；请检查记忆开关，旧版分析需曾手动保存。"];
    }
    [self.tableView reloadData];
}
- (NSString *)modeName { return @[@"日常回复（最近20条）", @"最近对话更新记忆（20条＋旧记忆）", @"深入分析（使用设置条数，最多500条）"][self.mode]; }
- (NSDictionary *)requestIdentity {
    return @{@"account":self.context.accountID ?: @"", @"contact":self.context.contactID ?: @"",
             @"generation":@(self.memoryGeneration), @"model":self.model ?: @"", @"mode":@(self.mode), @"payload":self.payload ?: @[]};
}
- (void)chooseMode {
    if (self.busy) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择模式" message:@"日常回复不改写记忆。更新记忆只整合旧记忆和最近20条，不保证涵盖两次分析间的全部新消息；需要补足历史时使用深入分析。" preferredStyle:UIAlertControllerStyleAlert];
    NSArray *names = @[@"日常回复", @"最近对话更新记忆", @"深入分析"];
    for (NSInteger i = 0; i < 3; i++) {
        [alert addAction:[UIAlertAction actionWithTitle:names[i] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { self.mode = i; [self refresh]; }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)editFocus {
    if (self.busy) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"本次只回复什么？" message:@"可填一句话或话题，最多300字；留空按最新对话判断。只用于本次，不写入长期记忆。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = self.focus; }];
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *value = weakAlert.textFields.firstObject.text ?: @"";
        if (value.length > 300) { GJNotice(self, @"请将回复话题控制在300字以内。"); return; }
        self.focus = value; [self refresh];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.result ? (self.mode == 0 ? 3 : 4) : 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 8;
    if (section == 1) return 6;
    if (section == 2) return [self.result[@"replies"] count];
    return 2;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"当前上下文与请求状态", @"AI 分析（推测不代表事实）", @"候选回复 · 点击仅复制", @"更新后的累计摘要"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 0 ? @"只在点击并确认分析后，将预览中的聊天与精简记忆发送到 DeepSeek。不会自动发送微信消息。预览内容可能包含敏感信息，请自行确认。" : nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.numberOfLines = 0; cell.detailTextLabel.numberOfLines = 0;
    NSInteger row = path.row;
    if (path.section == 0) {
        cell.textLabel.text = @[self.status ?: @"读取中", @"查看实际发送内容", self.busy ? @"取消请求" : @"发送到 DeepSeek 并分析", @"重新读取上下文", @"本机适配诊断（仅结构信息）", [@"切换模式：" stringByAppendingString:[self modeName]], [@"指定回复话题：" stringByAppendingString:self.focus.length ? self.focus : @"自动判断最新话题"], @"重新生成（再次使用API）"][row];
        if (row > 0) cell.textLabel.textColor = UIColor.systemBlueColor;
    } else if (path.section == 1) {
        cell.textLabel.text = @[@"本次回复针对", @"关系 / 状态", @"对方可能的意图", @"当前局面", @"沟通风险", @"沟通策略"][row];
        cell.detailTextLabel.text = self.result[@[@"reply_target", @"relationship", @"intent", @"situation", @"risks", @"strategy"][row]];
    } else if (path.section == 2) {
        NSDictionary *reply = self.result[@"replies"][row]; cell.textLabel.text = reply[@"style"]; cell.detailTextLabel.text = reply[@"text"];
        cell.textLabel.textColor = UIColor.systemBlueColor;
    } else {
        cell.textLabel.text = row == 0 ? self.result[@"memory_summary"] : @"确认用此累计摘要更新联系人记忆";
        if (row == 1) cell.textLabel.textColor = UIColor.systemBlueColor;
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.section == 0) {
        if (path.row == 1 && self.payload) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"model":self.model, @"messages":self.payload} options:NSJSONWritingPrettyPrinted error:NULL];
            GJShowText(self, @"实际发送内容（不含 Key）", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        }
        if (path.row == 2) { if (self.busy) { [self.client cancel]; self.busy = NO; self.status = @"请求已取消。已传出的内容无法撤回。"; self.navigationItem.rightBarButtonItem.enabled = YES; [tableView reloadData]; } else [self confirmAnalysis]; }
        if (path.row == 3) [self refresh];
        if (path.row == 5) [self chooseMode];
        if (path.row == 6) [self editFocus];
        if (path.row == 7 && !self.busy) { self.cachedRequest = nil; self.cachedResult = nil; [self confirmAnalysis]; }
        if (path.row == 4) GJShowText(self, @"本机适配诊断", [[GJWeChatAdapter new] diagnosticsForController:self.source]);
    } else if (path.section == 2) {
        NSString *reply = self.result[@"replies"][path.row][@"text"];
        [UIPasteboard.generalPasteboard setItems:@[@{@"public.utf8-plain-text":reply}]
                                        options:@{UIPasteboardOptionLocalOnly:@YES, UIPasteboardOptionExpirationDate:[NSDate dateWithTimeIntervalSinceNow:300]}];
        GJNotice(self, @"已复制，仅本机有效 5 分钟。请返回微信自行粘贴并发送。");
    } else if (path.section == 3 && path.row == 1) [self saveSummary];
}
- (void)confirmAnalysis {
    if (self.mode == 1 && !self.includedMemory) { GJNotice(self, @"请先启用长期记忆，再使用最近对话更新记忆。"); return; }
    if (!self.payload) { GJNotice(self, @"没有可安全分析的上下文，请重新读取或检查设置。"); return; }
    if (self.memoryGeneration != GJMemoryStore.shared.generation || self.includedMemory != GJPreferences.memoryEnabled) {
        [self refresh]; GJNotice(self, @"记忆设置已变更，已刷新预览，请重新确认。"); return;
    }
    if ([[self requestIdentity] isEqual:self.cachedRequest] && self.cachedResult) {
        self.result = self.cachedResult; self.status = @"已复用本面板相同上下文的结果，未调用API。需要不同建议可点重新生成。"; [self.tableView reloadData]; return;
    }
    NSError *error = nil; NSString *key = [GJPreferences APIKey:&error];
    if (!key.length) { GJNotice(self, error.localizedDescription ?: @"请先在设置中保存 DeepSeek API Key。"); return; }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"发送上下文到 DeepSeek？" message:[NSString stringWithFormat:@"联系人：%@\n%lu 条已加载消息%@。请先查看实际发送内容。AI 对意图的判断只是推测。", self.context.displayName, (unsigned long)self.context.messages.count, self.includedMemory ? @"及该联系人的精简长期记忆" : @"，不含长期记忆"] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确认分析" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self startWithKey:key]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)startWithKey:(NSString *)key {
    if (self.busy) return;
    self.busy = YES; self.result = nil; self.status = @"正在请求 DeepSeek…可点击取消请求。";
    self.navigationItem.rightBarButtonItem.enabled = NO; [self.tableView reloadData];
    __weak typeof(self) weakSelf = self;
    [self.client analyzeMessages:self.payload APIKey:key model:self.model updatesMemory:(self.mode != 0) completion:^(NSDictionary *result, NSError *error) {
        typeof(self) strongSelf = weakSelf; if (!strongSelf) return;
        strongSelf.busy = NO; strongSelf.result = result;
        if (result) { strongSelf.cachedRequest = [strongSelf requestIdentity]; strongSelf.cachedResult = result; }
        strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
        strongSelf.status = error ? error.localizedDescription : (strongSelf.mode == 0 ? @"日常回复完成。请核对回复话题，候选只复制；原有记忆未改写。" : @"分析完成。请核对回复话题与累计摘要；摘要尚未保存。");
        [strongSelf.tableView reloadData];
    }];
}
- (void)saveSummary {
    if (self.mode == 0 || ![self.result[@"memory_summary"] length]) return;
    if (!GJPreferences.memoryEnabled || !self.includedMemory) { GJNotice(self, @"本次分析未启用长期记忆，请开启后重新分析。"); return; }
    if (self.memoryGeneration != GJMemoryStore.shared.generation) { GJNotice(self, @"记忆已修改或清除，旧分析不会写回。请重新分析。"); return; }
    NSError *error = nil;
    NSMutableDictionary *memory = [[GJMemoryStore.shared memoryForContext:self.context error:&error] mutableCopy];
    if (!memory) { GJNotice(self, error.localizedDescription); return; }
    memory[@"summary"] = self.result[@"memory_summary"];
    BOOL ok = [GJMemoryStore.shared saveMemory:memory context:self.context error:&error];
    GJNotice(self, ok ? @"累计摘要已保存，下次分析会携带；其他四项记忆保持不变，AI 推测需自行核实。" : error.localizedDescription);
}
@end
