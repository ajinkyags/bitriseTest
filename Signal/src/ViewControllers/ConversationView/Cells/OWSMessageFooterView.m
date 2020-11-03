//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "OWSMessageFooterView.h"
#import "DateUtil.h"
#import "OWSLabel.h"
#import "OWSMessageTimerView.h"
#import "Signal-Swift.h"
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSMessageFooterView ()

@property (nonatomic) UILabel *timestampLabel;
@property (nonatomic) UIImageView *statusIndicatorImageView;
@property (nonatomic) OWSMessageTimerView *messageTimerView;
@property (nonatomic) UIStackView *contentStack;
@property (nonatomic) UIView *leadingSpacer;
@property (nonatomic) UIView *trailingSpacer;

@end

@implementation OWSMessageFooterView

// `[UIView init]` invokes `[self initWithFrame:...]`.
- (instancetype)init
{
    if (self = [super initWithFrame:CGRectZero]) {
        [self commonInit];
    }

    return self;
}

- (void)commonInit
{
    // Ensure only called once.
    OWSAssertDebug(!self.timestampLabel);

    self.timestampLabel = [OWSLabel new];
    self.timestampLabel.textAlignment = self.textAlignmentUnnatural;
    self.messageTimerView = [OWSMessageTimerView new];
    self.statusIndicatorImageView = [UIImageView new];

    UIStackView *contentStack = [[UIStackView alloc]
        initWithArrangedSubviews:@[ self.timestampLabel, self.messageTimerView, self.statusIndicatorImageView ]];
    self.contentStack = contentStack;
    contentStack.axis = UILayoutConstraintAxisHorizontal;
    contentStack.alignment = UIStackViewAlignmentCenter;
    contentStack.spacing = self.hSpacing;

    self.leadingSpacer = [UIView hStretchingSpacer];
    self.trailingSpacer = [UIView hStretchingSpacer];

    [self addArrangedSubview:self.leadingSpacer];
    [self addArrangedSubview:self.contentStack];
    [self addArrangedSubview:self.trailingSpacer];

    self.userInteractionEnabled = NO;
}

- (void)configureFonts
{
    self.timestampLabel.font = UIFont.ows_dynamicTypeCaption1Font;
}

- (CGFloat)hSpacing
{
    return 4;
}

- (CGFloat)maxImageWidth
{
    return 18.f;
}

- (CGFloat)imageHeight
{
    return 12.f;
}

#pragma mark - Load

- (void)configureWithConversationViewItem:(id<ConversationViewItem>)viewItem
                        conversationStyle:(ConversationStyle *)conversationStyle
                               isIncoming:(BOOL)isIncoming
                        isOverlayingMedia:(BOOL)isOverlayingMedia
                          isOutsideBubble:(BOOL)isOutsideBubble
{
    OWSAssertDebug(viewItem);
    OWSAssertDebug(conversationStyle);

    self.leadingSpacer.hidden = isIncoming;
    self.trailingSpacer.hidden = !isIncoming;

    [self configureLabelsWithConversationViewItem:viewItem];

    UIColor *textColor;
    if (isOverlayingMedia) {
        textColor = [UIColor whiteColor];
    } else if (isOutsideBubble) {
        textColor = Theme.secondaryTextAndIconColor;
    } else {
        textColor = [conversationStyle bubbleSecondaryTextColorWithIsIncoming:isIncoming];
    }
    self.timestampLabel.textColor = textColor;

    if (viewItem.hasPerConversationExpiration) {
        TSMessage *message = (TSMessage *)viewItem.interaction;
        uint64_t expirationTimestamp = message.expiresAt;
        uint32_t expiresInSeconds = message.expiresInSeconds;
        [self.messageTimerView configureWithExpirationTimestamp:expirationTimestamp
                                         initialDurationSeconds:expiresInSeconds
                                                      tintColor:textColor];
        self.messageTimerView.hidden = NO;
    } else {
        self.messageTimerView.hidden = YES;
    }

    NSString *_Nullable accessibilityLabel;
    if (viewItem.interaction.interactionType == OWSInteractionType_OutgoingMessage) {
        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;

        UIImage *_Nullable statusIndicatorImage = nil;
        MessageReceiptStatus messageStatus =
            [MessageRecipientStatusUtils recipientStatusWithOutgoingMessage:outgoingMessage];
        accessibilityLabel = [MessageRecipientStatusUtils receiptMessageWithOutgoingMessage:outgoingMessage];

        BOOL shouldHideStatusIndicator = NO;

        switch (messageStatus) {
            case MessageReceiptStatusUploading:
            case MessageReceiptStatusSending:
                statusIndicatorImage = [UIImage imageNamed:@"message_status_sending"];
                [self animateSpinningIcon];
                break;
            case MessageReceiptStatusSent:
            case MessageReceiptStatusSkipped:
                statusIndicatorImage = [UIImage imageNamed:@"message_status_sent"];
                shouldHideStatusIndicator = outgoingMessage.wasRemotelyDeleted;
                break;
            case MessageReceiptStatusDelivered:
                statusIndicatorImage = [UIImage imageNamed:@"message_status_delivered"];
                shouldHideStatusIndicator = outgoingMessage.wasRemotelyDeleted;
                break;
            case MessageReceiptStatusRead:
                statusIndicatorImage = [UIImage imageNamed:@"message_status_read"];
                shouldHideStatusIndicator = outgoingMessage.wasRemotelyDeleted;
                break;
            case MessageReceiptStatusFailed:
                // No status indicator icon.
                break;
        }

        if (statusIndicatorImage == nil || shouldHideStatusIndicator) {
            [self hideStatusIndicator];
        } else {
            [self showStatusIndicatorWithIcon:statusIndicatorImage textColor:textColor];
        }
    } else {
        [self hideStatusIndicator];
    }
    self.accessibilityLabel = accessibilityLabel;
}

- (void)showStatusIndicatorWithIcon:(UIImage *)icon textColor:(UIColor *)textColor
{
    OWSAssertDebug(icon.size.width <= self.maxImageWidth);
    self.statusIndicatorImageView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.statusIndicatorImageView.tintColor = textColor;
    self.statusIndicatorImageView.hidden = NO;
}

- (void)hideStatusIndicator
{
    self.statusIndicatorImageView.hidden = YES;
}

- (void)animateSpinningIcon
{
    CABasicAnimation *animation;
    animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    animation.toValue = @(M_PI * 2.0);
    const CGFloat kPeriodSeconds = 1.f;
    animation.duration = kPeriodSeconds;
    animation.cumulative = YES;
    animation.repeatCount = HUGE_VALF;

    [self.statusIndicatorImageView.layer addAnimation:animation forKey:@"animation"];
}

- (BOOL)wasSentToAnyRecipient:(id<ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);

    if (viewItem.interaction.interactionType != OWSInteractionType_OutgoingMessage) {
        return NO;
    }

    TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
    return outgoingMessage.wasSentToAnyRecipient;
}

- (BOOL)isFailedOutgoingMessage:(id<ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);

    if (viewItem.interaction.interactionType != OWSInteractionType_OutgoingMessage) {
        return NO;
    }

    TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
    MessageReceiptStatus messageStatus =
        [MessageRecipientStatusUtils recipientStatusWithOutgoingMessage:outgoingMessage];
    return messageStatus == MessageReceiptStatusFailed;
}

- (void)configureLabelsWithConversationViewItem:(id<ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);

    [self configureFonts];

    NSString *timestampLabelText;
    if ([self isFailedOutgoingMessage:viewItem]) {
        timestampLabelText = [self wasSentToAnyRecipient:viewItem]
            ? NSLocalizedString(
                @"MESSAGE_STATUS_PARTIALLY_SENT", @"Label indicating that a message was only sent to some recipients.")
            : NSLocalizedString(@"MESSAGE_STATUS_SEND_FAILED", @"Label indicating that a message failed to send.");
    } else {
        timestampLabelText = [DateUtil formatMessageTimestamp:viewItem.interaction.timestamp];
    }

    self.timestampLabel.text = timestampLabelText;
}

- (CGSize)measureWithConversationViewItem:(id<ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);

    [self configureLabelsWithConversationViewItem:viewItem];

    CGSize result = CGSizeZero;
    result.height = MAX(self.timestampLabel.font.lineHeight, self.imageHeight);

    // Measure the actual current width, to be safe.
    CGFloat timestampLabelWidth = [self.timestampLabel sizeThatFits:CGSizeZero].width;

    result.width = timestampLabelWidth;
    if (viewItem.interaction.interactionType == OWSInteractionType_OutgoingMessage) {
        if (![self isFailedOutgoingMessage:viewItem]) {
            result.width += self.maxImageWidth;
        }
    }

    if (viewItem.hasPerConversationExpiration) {
        result.width += [OWSMessageTimerView measureSize].width;
    }

    result.width += MAX(0, (self.contentStack.arrangedSubviews.count - 1) * self.contentStack.spacing);

    return CGSizeCeil(result);
}

- (nullable NSString *)messageStatusTextForConversationViewItem:(id<ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);
    if (viewItem.interaction.interactionType != OWSInteractionType_OutgoingMessage) {
        return nil;
    }

    TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
    NSString *statusMessage = [MessageRecipientStatusUtils receiptMessageWithOutgoingMessage:outgoingMessage];
    return statusMessage;
}

- (void)prepareForReuse
{
    [self.statusIndicatorImageView.layer removeAllAnimations];

    [self.messageTimerView prepareForReuse];
}

@end

NS_ASSUME_NONNULL_END
