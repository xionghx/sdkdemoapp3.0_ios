//
//  EMChatDemoHelper.m
//  ChatDemo-UI3.0
//
//  Created by EaseMob on 16/10/9.
//  Copyright © 2016年 easemob. All rights reserved.
//

#import "EMChatDemoHelper.h"
#import "EMApplyManager.h"
#import <UserNotifications/UserNotifications.h>

static EMChatDemoHelper *helper = nil;

@implementation EMChatDemoHelper

+ (instancetype)shareHelper
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        helper = [[EMChatDemoHelper alloc] init];
    });
    return helper;
}

- (void)dealloc
{
    [[EMClient sharedClient] removeDelegate:self];
    [[EMClient sharedClient].groupManager removeDelegate:self];
    [[EMClient sharedClient].contactManager removeDelegate:self];
}

- (id)init
{
    self = [super init];
    if (self) {
        [self initHelper];
    }
    return self;
}

- (void)initHelper
{
    [[EMClient sharedClient] addDelegate:self delegateQueue:nil];
    [[EMClient sharedClient].groupManager addDelegate:self delegateQueue:nil];
    [[EMClient sharedClient].contactManager addDelegate:self delegateQueue:nil];
}


#pragma mark - public

- (void)setupUntreatedApplyCount
{
    NSInteger unreadCount = [[EMApplyManager defaultManager] unHandleApplysCount];
    if (_contactsVC) {
        if (unreadCount > 0) {
            _contactsVC.tabBarItem.badgeValue = [NSString stringWithFormat:@"%i",(int)unreadCount];
        }else{
            _contactsVC.tabBarItem.badgeValue = nil;
        }
    }
}

#pragma mark - EMClientDelegate

- (void)autoLoginDidCompleteWithError:(EMError *)aError {
    if (!aError) {
        [_contactsVC reloadGroupNotifications];
        [_contactsVC reloadContactRequests];
        [_contactsVC reloadContacts];
    }
}

#pragma mark - EMContactManagerDelegate

- (void)friendRequestDidApproveByUser:(NSString *)aUsername {
    NSString *msgstr = [NSString stringWithFormat:NSLocalizedString(@"message.friendapply.agree", @"%@ agreed to add friends to apply"), aUsername];
    [self showAlertWithMessage:msgstr];
}

- (void)friendRequestDidDeclineByUser:(NSString *)aUsername {
    NSString *msgstr = [NSString stringWithFormat:NSLocalizedString(@"message.friendapply.refuse", @"%@ refuse to add friends to apply"), aUsername];
    [self showAlertWithMessage:msgstr];
}

- (void)friendshipDidRemoveByUser:(NSString *)aUsername {
    NSString *msg = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"common.delete", @"Delete"), aUsername];
    [_mainVC showAlertWithMessage:msg];
    if (_contactsVC) {
        [_contactsVC reloadContacts];
    }
}

- (void)friendshipDidAddByUser:(NSString *)aUsername {
    if (_contactsVC) {
        [_contactsVC reloadContacts];
    }
}

- (void)friendRequestDidReceiveFromUser:(NSString *)aUsername message:(NSString *)aMessage {
    if (!aUsername) {
        return;
    }
    
    if (!aMessage) {
        aMessage = [NSString stringWithFormat:NSLocalizedString(@"contact.somebodyAddWithName", @"%@ add you as a friend"), aUsername];
    }
    
    if (![[EMApplyManager defaultManager] isExistingRequest:aUsername applyStyle:EMApplyStyle_contact])
    {
        EMApplyModel *model = [[EMApplyModel alloc] init];
        model.applyHyphenateId = aUsername;
        model.applyNickName = aUsername;
        model.reason = aMessage;
        model.style = EMApplyStyle_contact;
        [[EMApplyManager defaultManager] addApplyRequest:model];
    }
    
    if (self.mainVC && helper) {
        [helper setupUntreatedApplyCount];
#if !TARGET_IPHONE_SIMULATOR
        
        BOOL isAppActivity = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
        if (!isAppActivity) {
            if (NSClassFromString(@"UNUserNotificationCenter")) {
                UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.01 repeats:NO];
                UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
                content.sound = [UNNotificationSound defaultSound];
                content.body =[NSString stringWithFormat:NSLocalizedString(@"contact.somebodyAddWithName", @"%@ add you as a friend"), aUsername];
                UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate] * 1000] stringValue] content:content trigger:trigger];
                [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
            }
            else {
                UILocalNotification *notification = [[UILocalNotification alloc] init];
                notification.fireDate = [NSDate date];
                notification.alertBody = [NSString stringWithFormat:NSLocalizedString(@"contact.somebodyAddWithName", @"%@ add you as a friend"), aUsername];
                notification.alertAction = NSLocalizedString(@"common.open", @"Open");
                notification.timeZone = [NSTimeZone defaultTimeZone];
            }
        }
#endif
    }
    [_contactsVC reloadContactRequests];
}

#pragma mark - EMGroupManagerDelegate

- (void)didLeaveGroup:(EMGroup *)aGroup
               reason:(EMGroupLeaveReason)aReason {
    NSString *msgstr = nil;
    if (aReason == EMGroupLeaveReasonBeRemoved) {
        msgstr = [NSString stringWithFormat:@"Your are kicked out from group: %@ [%@]", aGroup.subject, aGroup.groupId];
    } else if (aReason == EMGroupLeaveReasonDestroyed) {
        msgstr = [NSString stringWithFormat:@"Group: %@ [%@] is destroyed", aGroup.subject, aGroup.groupId];
    }
    
    if (msgstr.length > 0) {
        [self showAlertWithMessage:msgstr];
    }
}

- (void)joinGroupRequestDidReceive:(EMGroup *)aGroup
                              user:(NSString *)aUsername
                            reason:(NSString *)aReason {
    if (!aGroup || !aUsername) {
        return;
    }
    
    if (!aReason || aReason.length == 0) {
        aReason = [NSString stringWithFormat:NSLocalizedString(@"group.applyJoin", @"%@ apply to join groups\'%@\'"), aUsername, aGroup.subject];
    }
    else{
        aReason = [NSString stringWithFormat:NSLocalizedString(@"group.applyJoinWithName", @"%@ apply to join groups\'%@\'：%@"), aUsername, aGroup.subject, aReason];
    }
    
    if (![[EMApplyManager defaultManager] isExistingRequest:aUsername applyStyle:EMApplyStyle_joinGroup])
    {
        EMApplyModel *model = [[EMApplyModel alloc] init];
        model.applyHyphenateId = aUsername;
        model.applyNickName = aUsername;
        model.groupId = aGroup.groupId;
        model.groupSubject = aGroup.subject;
        model.groupMemberCount = aGroup.membersCount;
        model.reason = aReason;
        model.style = EMApplyStyle_joinGroup;
        [[EMApplyManager defaultManager] addApplyRequest:model];
    }
    
    if (self.mainVC && helper) {
        [helper setupUntreatedApplyCount];
#if !TARGET_IPHONE_SIMULATOR
#endif
    }
    
    if (_contactsVC) {
        [_contactsVC reloadGroupNotifications];
    }
}

- (void)didJoinGroup:(EMGroup *)aGroup
             inviter:(NSString *)aInviter
             message:(NSString *)aMessage
{
    NSString *msgstr = [NSString stringWithFormat:NSLocalizedString(@"group.invite", @"%@ invite you to group: %@ [%@]"), aInviter, aGroup.subject, aGroup.groupId];
    [self showAlertWithMessage:msgstr];
}

- (void)joinGroupRequestDidDecline:(NSString *)aGroupId
                            reason:(NSString *)aReason
{
    if (!aReason || aReason.length == 0) {
        aReason = [NSString stringWithFormat:NSLocalizedString(@"group.beRefusedToJoin", @"be refused to join the group\'%@\'"), aGroupId];
    }
    [self showAlertWithMessage:aReason];
}

- (void)joinGroupRequestDidApprove:(EMGroup *)aGroup {
    NSString *msgstr = [NSString stringWithFormat:NSLocalizedString(@"group.agreedAndJoined", @"agreed to join the group of \'%@\'"), aGroup.subject];
    [self showAlertWithMessage:msgstr];
}

- (void)groupInvitationDidReceive:(NSString *)aGroupId
                          inviter:(NSString *)aInviter
                          message:(NSString *)aMessage
{
    if (!aGroupId || !aInviter) {
        return;
    }
    
    if (![[EMApplyManager defaultManager] isExistingRequest:aInviter applyStyle:EMApplyStyle_groupInvitation])
    {
        EMApplyModel *model = [[EMApplyModel alloc] init];
        model.groupId = aGroupId;
        model.applyHyphenateId = aInviter;
        model.applyNickName = aInviter;
        model.reason = aMessage;
        model.style = EMApplyStyle_groupInvitation;
        [[EMApplyManager defaultManager] addApplyRequest:model];
    }
    
    if (self.mainVC && helper) {
        [helper setupUntreatedApplyCount];
#if !TARGET_IPHONE_SIMULATOR
#endif
    }
    
    if (self.contactsVC) {
        [self.contactsVC reloadGroupNotifications];
    }
}

@end
