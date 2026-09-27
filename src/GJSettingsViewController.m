#import "GJSettingsViewController.h"
#import "GJPreferences.h"
#import "GJMemoryStore.h"
#import "GJModels.h"
#import "GJUI.h"
@interface GJSettingsViewController ()
@property(nonatomic, strong) GJChatContext *context;
@end
@implementation GJSettingsViewController
- (instancetype)initWithContext:(GJChatContext *)context {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) _context = context;
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"狗头军师设置"; self.tableView.rowHeight = UITableViewAutomaticDimension; self.tableView.estimatedRowHeight = 64; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 3 : section == 1 ? 3 : 5; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @[@"DeepSeek 与上下文", @"本地记忆", @"当前联系人记忆（每项最多 1000 字）"][section]; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"API Key 仅保存到设备钥匙串；留空保存可删除。模型名称以你的 DeepSeek 账户可用模型为准。聊天条数 5～50，受当前页面加载情况与文本预算限制。";
    if (section == 1) return @"长期记忆默认关闭。关闭后不读取、不上传、不写入，已有文件仍保留，可另行清除。文件按微信账号及联系人隔离，启用系统文件保护并排除备份。";
    return self.context ? [NSString stringWithFormat:@"联系人：%@。手动编辑的内容只在本机保存；启用记忆后会随下次分析发送。AI 摘要必须手动保存。", self.context.displayName] : @"尚未识别联系人，无法编辑或清除此联系人记忆。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.numberOfLines = 0; cell.detailTextLabel.numberOfLines = 0;
    NSInteger row = indexPath.row;
    if (indexPath.section == 0) {
        cell.textLabel.text = @[@"设置 / 删除 API Key", @"最近聊天条数", @"DeepSeek 模型"][row];
        if (row == 1) cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)GJPreferences.messageCount];
        if (row == 2) cell.detailTextLabel.text = GJPreferences.model;
    } else if (indexPath.section == 1) {
        cell.textLabel.text = @[@"启用长期记忆", @"清除此联系人记忆", @"清除全部记忆"][row];
        if (row == 0) { UISwitch *toggle = [UISwitch new]; toggle.on = GJPreferences.memoryEnabled; [toggle addTarget:self action:@selector(toggleMemory:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView = toggle; }
        else cell.textLabel.textColor = UIColor.systemRedColor;
    } else {
        cell.textLabel.text = @[@"关系摘要", @"重要人物信息", @"重要事件", @"明确要求记住的信息", @"最近分析摘要"][row];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}
- (void)toggleMemory:(UISwitch *)sender {
    [GJPreferences.defaults setBool:sender.on forKey:@"memoryEnabled"];
    [[GJMemoryStore shared] invalidatePendingWrites];
    [self.tableView reloadData];
}
- (void)editTitle:(NSString *)title value:(NSString *)value secure:(BOOL)secure save:(void (^)(NSString *))save {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:secure ? @"留空保存会删除 Key。不会显示已保存的 Key。" : nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.secureTextEntry = secure; field.text = value; field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *text = weakAlert.textFields.firstObject.text ?: @"";
        save([text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]);
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger row = indexPath.row;
    if (indexPath.section == 0) {
        if (row == 0) [self editTitle:@"DeepSeek API Key" value:@"" secure:YES save:^(NSString *value) {
            if (value.length > 512 || [value rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) { GJNotice(self, @"Key 格式无效。"); return; }
            NSError *error = nil; BOOL ok = [GJPreferences saveAPIKey:value error:&error];
            GJNotice(self, ok ? (value.length ? @"已保存到钥匙串。" : @"已删除 Key。") : error.localizedDescription);
        }];
        if (row == 1) [self editTitle:@"最近聊天条数（5～50）" value:[NSString stringWithFormat:@"%ld", (long)GJPreferences.messageCount] secure:NO save:^(NSString *value) {
            NSScanner *scanner = [NSScanner scannerWithString:value]; NSInteger count = 0;
            if (![scanner scanInteger:&count] || !scanner.isAtEnd || count < 5 || count > 50) { GJNotice(self, @"请输入 5～50 的整数。"); return; }
            [GJPreferences.defaults setInteger:count forKey:@"messageCount"];
        }];
        if (row == 2) [self editTitle:@"DeepSeek 模型名称" value:GJPreferences.model secure:NO save:^(NSString *value) {
            NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."];
            if (!value.length || value.length > 80 || [value rangeOfCharacterFromSet:allowed.invertedSet].location != NSNotFound) { GJNotice(self, @"模型名称无效。"); return; }
            [GJPreferences.defaults setObject:value forKey:@"model"];
        }];
    } else if (indexPath.section == 1 && row > 0) {
        if (row == 1 && !self.context) { GJNotice(self, @"未识别当前联系人。"); return; }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:row == 1 ? @"清除此联系人记忆？" : @"清除所有账号的全部记忆？" message:@"此操作不可撤销，不删除微信聊天。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"清除" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            NSError *error = nil;
            BOOL ok = row == 1 ? [[GJMemoryStore shared] clearContext:self.context error:&error] : [[GJMemoryStore shared] clearAll:&error];
            GJNotice(self, ok ? @"记忆已清除。" : error.localizedDescription);
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else if (indexPath.section == 2) {
        if (!self.context || !GJPreferences.memoryEnabled) { GJNotice(self, @"请识别联系人并启用长期记忆后编辑。"); return; }
        NSError *error = nil; NSDictionary *memory = [[GJMemoryStore shared] memoryForContext:self.context error:&error];
        if (!memory) { GJNotice(self, error.localizedDescription); return; }
        NSString *key = @[@"relationship", @"people", @"events", @"explicit", @"summary"][row];
        [self editTitle:@[@"关系摘要", @"重要人物信息", @"重要事件", @"明确记住的信息", @"最近分析摘要"][row] value:memory[key] ?: @"" secure:NO save:^(NSString *value) {
            if (value.length > 1000) { GJNotice(self, @"最多保存 1000 字，请精简后重试。"); return; }
            NSMutableDictionary *updated = [memory mutableCopy]; updated[key] = value;
            NSError *saveError = nil;
            [[GJMemoryStore shared] invalidatePendingWrites];
            BOOL ok = [[GJMemoryStore shared] saveMemory:updated context:self.context error:&saveError];
            GJNotice(self, ok ? @"已保存到本机。" : saveError.localizedDescription);
        }];
    }
}
@end
