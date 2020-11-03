//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "ConversationViewItem.h"
#import "OWSMessageCell.h"
#import "OWSSystemMessageCell.h"
#import "Signal-Swift.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <SignalServiceKit/NSData+Image.h>
#import <SignalServiceKit/OWSContact.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>
#import <SignalServiceKit/TSInteraction.h>

NS_ASSUME_NONNULL_BEGIN

NSString *NSStringForOWSMessageCellType(OWSMessageCellType cellType)
{
    switch (cellType) {
        case OWSMessageCellType_TextOnlyMessage:
            return @"OWSMessageCellType_TextOnlyMessage";
        case OWSMessageCellType_Audio:
            return @"OWSMessageCellType_Audio";
        case OWSMessageCellType_GenericAttachment:
            return @"OWSMessageCellType_GenericAttachment";
        case OWSMessageCellType_Unknown:
            return @"OWSMessageCellType_Unknown";
        case OWSMessageCellType_ContactShare:
            return @"OWSMessageCellType_ContactShare";
        case OWSMessageCellType_MediaMessage:
            return @"OWSMessageCellType_MediaMessage";
        case OWSMessageCellType_OversizeTextDownloading:
            return @"OWSMessageCellType_OversizeTextDownloading";
        case OWSMessageCellType_StickerMessage:
            return @"OWSMessageCellType_StickerMessage";
        case OWSMessageCellType_ViewOnce:
            return @"OWSMessageCellType_ViewOnce";
    }
}

NSString *NSStringForViewOnceMessageState(ViewOnceMessageState cellType)
{
    switch (cellType) {
        case ViewOnceMessageState_Unknown:
            return @"ViewOnceMessageState_Unknown";
        case ViewOnceMessageState_IncomingExpired:
            return @"ViewOnceMessageState_IncomingExpired";
        case ViewOnceMessageState_IncomingDownloading:
            return @"ViewOnceMessageState_IncomingDownloading";
        case ViewOnceMessageState_IncomingFailed:
            return @"ViewOnceMessageState_IncomingFailed";
        case ViewOnceMessageState_IncomingAvailable:
            return @"ViewOnceMessageState_IncomingAvailable";
        case ViewOnceMessageState_IncomingInvalidContent:
            return @"ViewOnceMessageState_IncomingInvalidContent";
        case ViewOnceMessageState_OutgoingSending:
            return @"ViewOnceMessageState_OutgoingSending";
        case ViewOnceMessageState_OutgoingFailed:
            return @"ViewOnceMessageState_OutgoingFailed";
        case ViewOnceMessageState_OutgoingSentExpired:
            return @"ViewOnceMessageState_OutgoingSentExpired";
    }
}

#pragma mark -

@implementation ConversationMediaAlbumItem

- (instancetype)initWithAttachment:(TSAttachment *)attachment
                  attachmentStream:(nullable TSAttachmentStream *)attachmentStream
                           caption:(nullable NSString *)caption
                         mediaSize:(CGSize)mediaSize
{
    OWSAssertDebug(attachment);

    self = [super init];

    if (!self) {
        return self;
    }

    _attachment = attachment;
    _attachmentStream = attachmentStream;
    _caption = caption;
    _mediaSize = mediaSize;

    return self;
}

- (BOOL)isFailedDownload
{
    if (![self.attachment isKindOfClass:[TSAttachmentPointer class]]) {
        return NO;
    }
    TSAttachmentPointer *attachmentPointer = (TSAttachmentPointer *)self.attachment;
    return attachmentPointer.state == TSAttachmentPointerStateFailed;
}

- (BOOL)isPendingMessageRequest
{
    if (![self.attachment isKindOfClass:[TSAttachmentPointer class]]) {
        return NO;
    }
    TSAttachmentPointer *attachmentPointer = (TSAttachmentPointer *)self.attachment;
    return attachmentPointer.state == TSAttachmentPointerStatePendingMessageRequest;
}

@end

#pragma mark -

@interface ConversationInteractionViewItem ()

@property (nonatomic, nullable) NSValue *cachedCellSize;

#pragma mark - OWSAudioPlayerDelegate

@property (nonatomic) CGFloat audioProgressSeconds;
@property (nonatomic) CGFloat audioDurationSeconds;

#pragma mark - View State

@property (nonatomic) BOOL hasViewState;
@property (nonatomic) OWSMessageCellType messageCellType;
@property (nonatomic, nullable) DisplayableText *displayableBodyText;
@property (nonatomic, nullable) DisplayableText *displayableQuotedText;
@property (nonatomic, nullable) OWSQuotedReplyModel *quotedReply;
@property (nonatomic, nullable) StickerInfo *stickerInfo;
@property (nonatomic, nullable) TSAttachmentStream *stickerAttachment;
@property (nonatomic, nullable) StickerMetadata *stickerMetadata;
@property (nonatomic) BOOL isFailedSticker;
@property (nonatomic) ViewOnceMessageState viewOnceMessageState;
@property (nonatomic, nullable) TSAttachmentStream *attachmentStream;
@property (nonatomic, nullable) TSAttachmentPointer *attachmentPointer;
@property (nonatomic, nullable) ContactShareViewModel *contactShare;
@property (nonatomic, nullable) OWSLinkPreview *linkPreview;
@property (nonatomic, nullable) TSAttachment *linkPreviewAttachment;
@property (nonatomic, nullable) GroupInviteLinkViewModel *groupInviteLinkViewModel;
@property (nonatomic, nullable) NSArray<ConversationMediaAlbumItem *> *mediaAlbumItems;
@property (nonatomic, nullable) NSString *systemMessageText;
@property (nonatomic, nullable) NSArray<GroupUpdateCopyItem *> *systemMessageGroupUpdates;
@property (nonatomic, nullable) TSThread *incomingMessageAuthorThread;
@property (nonatomic, nullable) NSString *authorConversationColorName;
@property (nonatomic, nullable) ConversationStyle *conversationStyle;
@property (nonatomic, nullable) NSArray<NSString *> *mutualGroupNames;
@property (nonatomic, nullable) InteractionReactionState *reactionState;

@end

#pragma mark -

@implementation ConversationInteractionViewItem

@synthesize shouldShowSenderAvatar = _shouldShowSenderAvatar;
@synthesize didCellMediaFailToLoad = _didCellMediaFailToLoad;
@synthesize interaction = _interaction;
@synthesize isFirstInCluster = _isFirstInCluster;
@synthesize thread = _thread;
@synthesize isLastInCluster = _isLastInCluster;
@synthesize lastAudioMessageView = _lastAudioMessageView;
@synthesize senderName = _senderName;
@synthesize senderUsername = _senderUsername;
@synthesize senderProfileName = _senderProfileName;
@synthesize accessibilityAuthorName = _accessibilityAuthorName;
@synthesize shouldHideFooter = _shouldHideFooter;
@synthesize audioPlaybackState = _audioPlaybackState;
@synthesize needsUpdate = _needsUpdate;
@synthesize shouldCollapseSystemMessageAction = _shouldCollapseSystemMessageAction;
@synthesize isTruncatedTextVisible = _isTruncatedTextVisible;

- (instancetype)initWithInteraction:(TSInteraction *)interaction
                             thread:(TSThread *)thread
                        transaction:(SDSAnyReadTransaction *)transaction
                  conversationStyle:(ConversationStyle *)conversationStyle
{
    OWSAssertDebug(interaction);
    OWSAssertDebug(transaction);
    OWSAssertDebug(conversationStyle);

    self = [super init];

    if (!self) {
        return self;
    }

    _interaction = interaction;
    _thread = thread;
    _conversationStyle = conversationStyle;

    [self setAuthorConversationColorNameWithTransaction:transaction];
    [self setMutualGroupNamesWithTransaction:transaction];
    [self ensureReactionStateWithTransaction:transaction];

    [self ensureViewState:transaction];

    return self;
}

#pragma mark - Dependencies

- (SDSDatabaseStorage *)databaseStorage
{
    return SDSDatabaseStorage.shared;
}

+ (SDSDatabaseStorage *)databaseStorage
{
    return SDSDatabaseStorage.shared;
}

- (OWSContactsManager *)contactsManager
{
    return Environment.shared.contactsManager;
}

- (id<GroupsV2>)groupsV2
{
    return SSKEnvironment.shared.groupsV2;
}

#pragma mark -

- (void)replaceInteraction:(TSInteraction *)interaction transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(interaction);

    _interaction = interaction;

    self.hasViewState = NO;
    self.messageCellType = OWSMessageCellType_Unknown;
    self.displayableBodyText = nil;
    self.attachmentStream = nil;
    self.attachmentPointer = nil;
    self.mediaAlbumItems = nil;
    self.displayableQuotedText = nil;
    self.quotedReply = nil;
    self.stickerInfo = nil;
    self.stickerAttachment = nil;
    self.stickerMetadata = nil;
    self.isFailedSticker = NO;
    self.viewOnceMessageState = ViewOnceMessageState_Unknown;
    self.contactShare = nil;
    self.systemMessageText = nil;
    self.systemMessageGroupUpdates = nil;
    self.authorConversationColorName = nil;
    self.linkPreview = nil;
    self.linkPreviewAttachment = nil;
    self.groupInviteLinkViewModel = nil;
    self.senderName = nil;
    self.senderUsername = nil;
    self.senderProfileName = nil;
    self.accessibilityAuthorName = nil;

    [self setAuthorConversationColorNameWithTransaction:transaction];
    [self setMutualGroupNamesWithTransaction:transaction];
    [self ensureReactionStateWithTransaction:transaction];

    [self clearCachedLayoutState];

    [self ensureViewState:transaction];
}

- (void)setAuthorConversationColorNameWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(transaction);

    SignalServiceAddress *address;
    switch (self.interaction.interactionType) {
        case OWSInteractionType_ThreadDetails: {
            if ([self.thread isKindOfClass:[TSContactThread class]]) {
                address = ((TSContactThread *)self.thread).contactAddress;
            } else {
                address = nil;
            }
            break;
        }
        case OWSInteractionType_TypingIndicator: {
            OWSTypingIndicatorInteraction *typingIndicator = (OWSTypingIndicatorInteraction *)self.interaction;
            address = typingIndicator.address;
            break;
        }
        case OWSInteractionType_IncomingMessage: {
            TSIncomingMessage *incomingMessage = (TSIncomingMessage *)self.interaction;
            address = incomingMessage.authorAddress;
            break;
        }
        default:
            address = nil;
            break;
    }

    if (address != nil) {
        self.authorConversationColorName = [self.contactsManager conversationColorNameForAddress:address
                                                                                     transaction:transaction];
    }
}

- (void)setMutualGroupNamesWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(transaction);

    _mutualGroupNames = nil;

    if (self.interaction.interactionType != OWSInteractionType_ThreadDetails) {
        return;
    }

    if ([self.thread isKindOfClass:[TSContactThread class]]) {
        TSContactThread *contactThread = (TSContactThread *)self.thread;
        _mutualGroupNames = [[TSGroupThread groupThreadsWithAddress:contactThread.contactAddress
                                                        transaction:transaction] map:^(TSGroupThread *thread) {
            return thread.groupNameOrDefault;
        }];
    }
}

- (void)ensureReactionStateWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSCAssertDebug(transaction);

    self.reactionState = [[InteractionReactionState alloc] initWithInteraction:self.interaction
                                                                   transaction:transaction];
}

- (NSString *)itemId
{
    return self.interaction.uniqueId;
}

- (BOOL)isGroupThread
{
    return self.thread.isGroupThread;
}

- (BOOL)hasBodyText
{
    return _displayableBodyText != nil;
}

- (BOOL)hasQuotedText
{
    return _displayableQuotedText != nil;
}

- (BOOL)hasQuotedAttachment
{
    return self.quotedAttachmentMimetype.length > 0;
}

- (BOOL)isQuotedReply
{
    return self.hasQuotedAttachment || self.hasQuotedText;
}

- (BOOL)isSticker
{
    return self.stickerInfo != nil;
}

- (BOOL)hasPerConversationExpiration
{
    if (self.interaction.interactionType != OWSInteractionType_OutgoingMessage
        && self.interaction.interactionType != OWSInteractionType_IncomingMessage) {
        return NO;
    }

    TSMessage *message = (TSMessage *)self.interaction;
    return message.hasPerConversationExpiration;
}

- (BOOL)isViewOnceMessage
{
    if (self.interaction.interactionType != OWSInteractionType_OutgoingMessage
        && self.interaction.interactionType != OWSInteractionType_IncomingMessage) {
        return NO;
    }

    TSMessage *message = (TSMessage *)self.interaction;
    return message.isViewOnceMessage;
}

- (BOOL)canShowDate
{
    switch (self.interaction.interactionType) {
        case OWSInteractionType_Unknown:
        case OWSInteractionType_TypingIndicator:
        case OWSInteractionType_ThreadDetails:
        case OWSInteractionType_DateHeader:
            return NO;
        case OWSInteractionType_Info: {
            // Only show the date for non-synced thread messages;
            TSInfoMessage *infoMessage = (TSInfoMessage *)self.interaction;
            return infoMessage.messageType != TSInfoMessageSyncedThread;
        }
        case OWSInteractionType_UnreadIndicator:
        case OWSInteractionType_IncomingMessage:
        case OWSInteractionType_OutgoingMessage:
        case OWSInteractionType_Error:
        case OWSInteractionType_Call:
            return YES;
    }
}

- (void)setShouldShowSenderAvatar:(BOOL)shouldShowSenderAvatar
{
    if (_shouldShowSenderAvatar == shouldShowSenderAvatar) {
        return;
    }

    _shouldShowSenderAvatar = shouldShowSenderAvatar;

    [self clearCachedLayoutState];
}

- (void)setSenderName:(nullable NSAttributedString *)senderName
{
    if ([NSObject isNullableObject:senderName equalTo:_senderName]) {
        return;
    }

    _senderName = senderName;

    [self clearCachedLayoutState];
}

- (void)setAccessibilityAuthorName:(nullable NSString *)accessibilityAuthorName
{
    if ([NSObject isNullableObject:accessibilityAuthorName equalTo:_accessibilityAuthorName]) {
        return;
    }

    _accessibilityAuthorName = accessibilityAuthorName;

    [self clearCachedLayoutState];
}

- (void)setShouldHideFooter:(BOOL)shouldHideFooter
{
    if (_shouldHideFooter == shouldHideFooter) {
        return;
    }

    _shouldHideFooter = shouldHideFooter;

    [self clearCachedLayoutState];
}

- (void)setIsFirstInCluster:(BOOL)isFirstInCluster
{
    if (_isFirstInCluster == isFirstInCluster) {
        return;
    }

    _isFirstInCluster = isFirstInCluster;

    [self setNeedsUpdate];
}

- (void)setIsLastInCluster:(BOOL)isLastInCluster
{
    if (_isLastInCluster == isLastInCluster) {
        return;
    }

    _isLastInCluster = isLastInCluster;

    [self setNeedsUpdate];
}

- (void)setStickerInfo:(nullable StickerInfo *)stickerInfo
{
    if ([NSObject isNullableObject:_stickerInfo equalTo:stickerInfo]) {
        return;
    }

    _stickerInfo = stickerInfo;

    [self clearCachedLayoutState];
}

- (void)setStickerAttachment:(nullable TSAttachmentStream *)stickerAttachment
{
    BOOL didChange = ![NSObject isNullableObject:_stickerAttachment.uniqueId equalTo:stickerAttachment.uniqueId];

    _stickerAttachment = stickerAttachment;

    if (didChange) {
        [self clearCachedLayoutState];
    }
}

- (void)setStickerMetadata:(nullable StickerMetadata *)stickerMetadata
{
    BOOL didChange = ![NSObject isNullableObject:_stickerMetadata equalTo:stickerMetadata];

    _stickerMetadata = stickerMetadata;

    if (didChange) {
        [self clearCachedLayoutState];
    }
}

- (void)setIsFailedSticker:(BOOL)isFailedSticker
{
    if (_isFailedSticker == isFailedSticker) {
        return;
    }

    _isFailedSticker = isFailedSticker;

    [self clearCachedLayoutState];
}

- (void)setViewOnceMessageState:(ViewOnceMessageState)viewOnceMessageState
{
    if (_viewOnceMessageState == viewOnceMessageState) {
        return;
    }

    _viewOnceMessageState = viewOnceMessageState;

    [self clearCachedLayoutState];
}

- (void)setShouldCollapseSystemMessageAction:(BOOL)shouldCollapseSystemMessageAction
{
    if (_shouldCollapseSystemMessageAction == shouldCollapseSystemMessageAction) {
        return;
    }

    _shouldCollapseSystemMessageAction = shouldCollapseSystemMessageAction;

    [self clearCachedLayoutState];
}

- (void)setIsTruncatedTextVisible:(BOOL)isTruncatedTextVisible
{
    if (_isTruncatedTextVisible == isTruncatedTextVisible) {
        return;
    }

    _isTruncatedTextVisible = isTruncatedTextVisible;

    [self clearCachedLayoutState];
}

- (void)setGroupInviteLinkViewModel:(nullable GroupInviteLinkViewModel *)groupInviteLinkViewModel
{
    if ([NSObject isNullableObject:_groupInviteLinkViewModel equalTo:groupInviteLinkViewModel]) {
        return;
    }

    _groupInviteLinkViewModel = groupInviteLinkViewModel;

    [self clearCachedLayoutState];
}

- (void)clearCachedLayoutState
{
    self.cachedCellSize = nil;
    
    // Any change which requires relayout requires cell update.
    [self setNeedsUpdate];
}

- (BOOL)hasCachedLayoutState {
    return self.cachedCellSize != nil;
}

- (void)clearNeedsUpdate
{
    _needsUpdate = NO;
}

- (void)setNeedsUpdate
{
    _needsUpdate = YES;
}

- (CGSize)cellSize
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.conversationStyle);

    if (!self.cachedCellSize) {
        ConversationViewCell *_Nullable measurementCell = [self measurementCell];
        measurementCell.viewItem = self;
        measurementCell.conversationStyle = self.conversationStyle;
        CGSize cellSize = [measurementCell cellSize];
        self.cachedCellSize = [NSValue valueWithCGSize:cellSize];
        [measurementCell prepareForReuse];
    }
    return [self.cachedCellSize CGSizeValue];
}

- (nullable ConversationViewCell *)measurementCell
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.interaction);

    // For performance reasons, we cache one instance of each kind of
    // cell and uses these cells for measurement.
    static NSMutableDictionary<NSString *, ConversationViewCell *> *measurementCellCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        measurementCellCache = [NSMutableDictionary new];
    });

    NSString *cellCacheKey = self.cellReuseIdentifier;
    ConversationViewCell *_Nullable measurementCell = measurementCellCache[cellCacheKey];
    if (!measurementCell) {
        switch (self.interaction.interactionType) {
            case OWSInteractionType_Unknown:
                OWSFailDebug(@"Unknown interaction type.");
                return nil;
            case OWSInteractionType_IncomingMessage:
            case OWSInteractionType_OutgoingMessage:
                measurementCell = [OWSMessageCell new];
                break;
            case OWSInteractionType_Error:
            case OWSInteractionType_Info:
            case OWSInteractionType_Call:
                measurementCell = [OWSSystemMessageCell new];
                break;
            case OWSInteractionType_TypingIndicator:
                measurementCell = [OWSTypingIndicatorCell new];
                break;
            case OWSInteractionType_ThreadDetails:
                measurementCell = [OWSThreadDetailsCell new];
                break;
            case OWSInteractionType_UnreadIndicator:
                measurementCell = [OWSUnreadIndicatorCell new];
                break;
            case OWSInteractionType_DateHeader:
                measurementCell = [OWSDateHeaderCell new];
                break;
        }

        OWSAssertDebug(measurementCell);
        measurementCellCache[cellCacheKey] = measurementCell;
    }

    return measurementCell;
}

- (CGFloat)vSpacingWithPreviousLayoutItem:(id<ConversationViewItem>)previousLayoutItem
{
    OWSAssertDebug(previousLayoutItem);

    switch (self.interaction.interactionType) {
        case OWSInteractionType_DateHeader:
        case OWSInteractionType_UnreadIndicator:
            return ConversationStyle.defaultMessageSpacing;
        case OWSInteractionType_IncomingMessage:
            switch (previousLayoutItem.interaction.interactionType) {
                case OWSInteractionType_IncomingMessage: {
                    TSIncomingMessage *incomingMessage = (TSIncomingMessage *)self.interaction;
                    TSIncomingMessage *previousIncomingMessage = (TSIncomingMessage *)previousLayoutItem.interaction;
                    if ([incomingMessage.authorAddress isEqualToAddress:previousIncomingMessage.authorAddress]) {
                        return ConversationStyle.compactMessageSpacing;
                    }
                    return ConversationStyle.defaultMessageSpacing;
                }
                case OWSInteractionType_Call:
                case OWSInteractionType_Info:
                case OWSInteractionType_Error:
                    return ConversationStyle.systemMessageSpacing;
                default:
                    return ConversationStyle.defaultMessageSpacing;
            }
        case OWSInteractionType_OutgoingMessage:
            switch (previousLayoutItem.interaction.interactionType) {
                case OWSInteractionType_OutgoingMessage:
                    return ConversationStyle.compactMessageSpacing;
                case OWSInteractionType_Call:
                case OWSInteractionType_Info:
                case OWSInteractionType_Error:
                    return ConversationStyle.systemMessageSpacing;
                default:
                    return ConversationStyle.defaultMessageSpacing;
            }
        case OWSInteractionType_Call:
        case OWSInteractionType_Info:
        case OWSInteractionType_Error:
            if (previousLayoutItem.interaction.interactionType == self.interaction.interactionType) {
                switch (previousLayoutItem.interaction.interactionType) {
                    case OWSInteractionType_Error: {
                        TSErrorMessage *previousErrorMessage = (TSErrorMessage *)previousLayoutItem.interaction;
                        TSErrorMessage *errorMessage = (TSErrorMessage *)self.interaction;
                        if (errorMessage.errorType == TSErrorMessageNonBlockingIdentityChange
                            || previousErrorMessage.errorType != errorMessage.errorType) {
                            return ConversationStyle.defaultMessageSpacing;
                        }
                        return ConversationStyle.compactMessageSpacing;
                    }
                    case OWSInteractionType_Info: {
                        TSInfoMessage *previousInfoMessage = (TSInfoMessage *)previousLayoutItem.interaction;
                        TSInfoMessage *infoMessage = (TSInfoMessage *)self.interaction;
                        if (infoMessage.messageType == TSInfoMessageVerificationStateChange
                            || previousInfoMessage.messageType != infoMessage.messageType) {
                            return ConversationStyle.defaultMessageSpacing;
                        }
                        return ConversationStyle.compactMessageSpacing;
                    }
                    case OWSInteractionType_Call:
                        return ConversationStyle.compactMessageSpacing;
                    default:
                        break;
                }
            } else if (previousLayoutItem.interaction.interactionType == OWSInteractionType_OutgoingMessage
                || previousLayoutItem.interaction.interactionType == OWSInteractionType_IncomingMessage) {
                return ConversationStyle.systemMessageSpacing;
            } else {
                return ConversationStyle.defaultMessageSpacing;
            }
        default:
            return ConversationStyle.defaultMessageSpacing;
    }
}

- (nullable NSString *)cellReuseIdentifier
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.interaction);

    switch (self.interaction.interactionType) {
        case OWSInteractionType_Unknown:
            OWSFailDebug(@"Unknown interaction type.");
            return nil;
        case OWSInteractionType_IncomingMessage:
            return [OWSMessageCell cellReuseIdentifierForMessageCellType:self.messageCellType isOutgoingMessage:NO];
        case OWSInteractionType_OutgoingMessage:
            return [OWSMessageCell cellReuseIdentifierForMessageCellType:self.messageCellType isOutgoingMessage:YES];
        case OWSInteractionType_Error:
        case OWSInteractionType_Info:
        case OWSInteractionType_Call:
            return [OWSSystemMessageCell cellReuseIdentifier];

        case OWSInteractionType_TypingIndicator:
            return [OWSTypingIndicatorCell cellReuseIdentifier];
        case OWSInteractionType_ThreadDetails:
            return [OWSThreadDetailsCell cellReuseIdentifier];
        case OWSInteractionType_UnreadIndicator:
            return [OWSUnreadIndicatorCell cellReuseIdentifier];
        case OWSInteractionType_DateHeader:
            return [OWSDateHeaderCell cellReuseIdentifier];
    }
}

- (ConversationViewCell *)dequeueCellForCollectionView:(UICollectionView *)collectionView
                                             indexPath:(NSIndexPath *)indexPath
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(collectionView);
    OWSAssertDebug(indexPath);

    NSString *_Nullable cellReuseIdentifier = self.cellReuseIdentifier;
    if (!cellReuseIdentifier) {
        OWSFailDebug(@"Unknown cell type.");
        return nil;
    }

    return [collectionView dequeueReusableCellWithReuseIdentifier:cellReuseIdentifier forIndexPath:indexPath];
}

- (nullable TSAttachmentStream *)firstValidAlbumAttachment
{
    OWSAssertDebug(self.mediaAlbumItems.count > 0);

    // For now, use first valid attachment.
    TSAttachmentStream *_Nullable attachmentStream = nil;
    for (ConversationMediaAlbumItem *mediaAlbumItem in self.mediaAlbumItems) {
        if (mediaAlbumItem.attachmentStream && mediaAlbumItem.attachmentStream.isValidVisualMedia) {
            attachmentStream = mediaAlbumItem.attachmentStream;
            break;
        }
    }
    return attachmentStream;
}

#pragma mark - OWSAudioPlayerDelegate

- (AudioPlaybackState)audioPlaybackState
{
    return _audioPlaybackState;
}

- (void)setAudioPlaybackState:(AudioPlaybackState)audioPlaybackState
{
    _audioPlaybackState = audioPlaybackState;

    [self.lastAudioMessageView updateContents];
}

- (void)setAudioProgress:(CGFloat)progress duration:(CGFloat)duration
{
    OWSAssertIsOnMainThread();

    // We don't want to reset the progress slider when the playback stops,
    // only when we finish playing the recording. This lets the user pick
    // back up where they left off if they, for example, play another message.
    if (self.audioPlaybackState != AudioPlaybackState_Stopped) {
        self.audioProgressSeconds = progress;
    }

    [self.lastAudioMessageView updateContents];
}

- (void)audioPlayerDidFinish
{
    OWSAssertIsOnMainThread();

    if (self.audioPlaybackState == AudioPlaybackState_Stopped) {
        self.audioProgressSeconds = 0;
        [self.lastAudioMessageView updateContents];
    }
}

#pragma mark - Displayable Text

// TODO: Now that we're caching the displayable text on the view items,
//       I don't think we need this cache any more.
- (NSCache *)displayableTextCache
{
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSCache new];
        // Cache the results for up to 1,000 messages.
        cache.countLimit = 1000;
    });
    return cache;
}

- (DisplayableText *)displayableBodyTextForText:(NSString *)text
                                         ranges:(nullable MessageBodyRanges *)ranges
                                  interactionId:(NSString *)interactionId
                                    transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(text);
    OWSAssertDebug(interactionId.length > 0);
    OWSAssertDebug(transaction);

    NSString *displayableTextCacheKey = [@"body-" stringByAppendingString:interactionId];

    return [self
        displayableTextForCacheKey:displayableTextCacheKey
                  messageBodyBlock:^{
                      return [[MessageBody alloc] initWithText:text ranges:ranges ?: MessageBodyRanges.empty];
                  }
                      mentionStyle:[self.interaction isKindOfClass:[TSOutgoingMessage class]] ? MentionStyleOutgoing
                                                                                              : MentionStyleIncoming
                       transaction:transaction];
}

- (DisplayableText *)displayableBodyTextForOversizeTextAttachment:(TSAttachmentStream *)attachmentStream
                                                           ranges:(nullable MessageBodyRanges *)ranges
                                                    interactionId:(NSString *)interactionId
                                                      transaction:transaction
{
    OWSAssertDebug(attachmentStream);
    OWSAssertDebug(interactionId.length > 0);
    OWSAssertDebug(transaction);

    NSString *displayableTextCacheKey = [@"oversize-body-" stringByAppendingString:interactionId];

    return [self
        displayableTextForCacheKey:displayableTextCacheKey
                  messageBodyBlock:^{
                      NSData *textData = [NSData dataWithContentsOfURL:attachmentStream.originalMediaURL];
                      NSString *text = [[NSString alloc] initWithData:textData encoding:NSUTF8StringEncoding];
                      return [[MessageBody alloc] initWithText:text ranges:ranges ?: MessageBodyRanges.empty];
                  }
                      mentionStyle:[self.interaction isKindOfClass:[TSOutgoingMessage class]] ? MentionStyleOutgoing
                                                                                              : MentionStyleIncoming
                       transaction:transaction];
}

- (DisplayableText *)displayableQuotedTextForText:(NSString *)text
                                           ranges:(nullable MessageBodyRanges *)ranges
                                    interactionId:(NSString *)interactionId
                                      transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(text);
    OWSAssertDebug(interactionId.length > 0);
    OWSAssertDebug(transaction);

    NSString *displayableTextCacheKey = [@"quoted-" stringByAppendingString:interactionId];

    return [self displayableTextForCacheKey:displayableTextCacheKey
                           messageBodyBlock:^{
                               return [[MessageBody alloc] initWithText:text ranges:ranges ?: MessageBodyRanges.empty];
                           }
                               mentionStyle:MentionStyleQuotedReply
                                transaction:transaction];
}

- (DisplayableText *)displayableCaptionForText:(NSString *)text
                                  attachmentId:(NSString *)attachmentId
                                   transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(text);
    OWSAssertDebug(attachmentId.length > 0);
    OWSAssertDebug(transaction);

    NSString *displayableTextCacheKey = [@"attachment-caption-" stringByAppendingString:attachmentId];

    return [self displayableTextForCacheKey:displayableTextCacheKey
                           messageBodyBlock:^{
                               return [[MessageBody alloc] initWithText:text ranges:MessageBodyRanges.empty];
                           }
                               mentionStyle:MentionStyleIncoming
                                transaction:transaction];
}

- (DisplayableText *)displayableTextForCacheKey:(NSString *)displayableTextCacheKey
                               messageBodyBlock:(MessageBody * (^_Nonnull)(void))messageBodyBlock
                                   mentionStyle:(MentionStyle)mentionStyle
                                    transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(displayableTextCacheKey.length > 0);

    DisplayableText *_Nullable displayableText = [[self displayableTextCache] objectForKey:displayableTextCacheKey];
    if (!displayableText) {
        MessageBody *messageBody = messageBodyBlock();
        displayableText = [DisplayableText displayableTextWithMessageBody:messageBody
                                                             mentionStyle:mentionStyle
                                                              transaction:transaction];
        [[self displayableTextCache] setObject:displayableText forKey:displayableTextCacheKey];
    }
    return displayableText;
}

#pragma mark - View State

- (void)ensureViewState:(SDSAnyReadTransaction *)transaction
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(transaction);
    OWSAssertDebug(!self.hasViewState);

    switch (self.interaction.interactionType) {
        case OWSInteractionType_Unknown:
        case OWSInteractionType_ThreadDetails:
        case OWSInteractionType_TypingIndicator:
        case OWSInteractionType_UnreadIndicator:
        case OWSInteractionType_DateHeader:
            return;
        case OWSInteractionType_Info: {
            TSInfoMessage *infoMessage = (TSInfoMessage *)self.interaction;
            if (infoMessage.messageType == TSInfoMessageTypeGroupUpdate) {
                NSArray<GroupUpdateCopyItem *> *_Nullable groupUpdates =
                    [infoMessage groupUpdateItemsWithTransaction:transaction];
                if (groupUpdates.count > 0) {
                    self.systemMessageGroupUpdates = groupUpdates;
                    return;
                }
            }
        }
        case OWSInteractionType_Error:
        case OWSInteractionType_Call:
            self.systemMessageText = [self systemMessageTextWithTransaction:transaction];
            OWSAssertDebug(self.systemMessageText.length > 0);
            return;
        case OWSInteractionType_IncomingMessage:
        case OWSInteractionType_OutgoingMessage:
            break;
        default:
            OWSFailDebug(@"Unknown interaction type.");
            return;
    }

    OWSAssertDebug([self.interaction isKindOfClass:[TSOutgoingMessage class]] ||
        [self.interaction isKindOfClass:[TSIncomingMessage class]]);

    self.hasViewState = YES;

    TSMessage *message = (TSMessage *)self.interaction;

    if (message.isViewOnceMessage) {
        [self configureViewOnceMessage:message transaction:transaction];
        return;
    }

    if (message.contactShare) {
        self.contactShare =
            [[ContactShareViewModel alloc] initWithContactShareRecord:message.contactShare transaction:transaction];
        self.messageCellType = OWSMessageCellType_ContactShare;
        return;
    }

    // Check for stickers _before_ media or quoted reply handling;
    // stickers should not have quoted replies and should never
    // have media.
    if (message.messageSticker) {
        self.stickerInfo = message.messageSticker.info;
        TSAttachment *_Nullable stickerAttachment =
            [TSAttachment anyFetchWithUniqueId:message.messageSticker.attachmentId transaction:transaction];
        OWSAssertDebug(stickerAttachment);
        if ([stickerAttachment isKindOfClass:[TSAttachmentStream class]]) {
            TSAttachmentStream *stickerAttachmentStream = (TSAttachmentStream *)stickerAttachment;
            CGSize mediaSize = [stickerAttachmentStream imageSize];
            if (stickerAttachmentStream.isValidImage && mediaSize.width > 0 && mediaSize.height > 0) {
                StickerType stickerType =
                    [StickerManager stickerTypeForContentType:stickerAttachmentStream.contentType];
                NSURL *stickerDataUrl = [NSURL fileURLWithPath:stickerAttachmentStream.originalFilePath];
                self.stickerMetadata = [[StickerMetadata alloc] initWithStickerInfo:message.messageSticker.info
                                                                        stickerType:stickerType
                                                                     stickerDataUrl:stickerDataUrl
                                                                        emojiString:message.messageSticker.emoji];
                self.stickerAttachment = stickerAttachmentStream;
            }
        } else if ([stickerAttachment isKindOfClass:[TSAttachmentPointer class]]) {
            TSAttachmentPointer *stickerAttachmentPointer = (TSAttachmentPointer *)stickerAttachment;
            self.isFailedSticker = stickerAttachmentPointer.state == TSAttachmentPointerStateFailed;
        }
        // Exit early; stickers shouldn't have body text or other attachments.
        self.messageCellType = OWSMessageCellType_StickerMessage;
        return;
    }

    // Check for quoted replies _before_ media album handling,
    // since that logic may exit early.
    if (message.quotedMessage) {
        self.quotedReply =
            [OWSQuotedReplyModel quotedReplyWithQuotedMessage:message.quotedMessage transaction:transaction];

        if (self.quotedReply.body.length > 0) {
            self.displayableQuotedText = [self displayableQuotedTextForText:self.quotedReply.body
                                                                     ranges:self.quotedReply.bodyRanges
                                                              interactionId:message.uniqueId
                                                                transaction:transaction];
        }
    }

    TSAttachment *_Nullable oversizeTextAttachment =
        [message oversizeTextAttachmentWithTransaction:transaction.unwrapGrdbRead];
    if ([oversizeTextAttachment isKindOfClass:[TSAttachmentStream class]]) {
        TSAttachmentStream *oversizeTextAttachmentStream = (TSAttachmentStream *)oversizeTextAttachment;
        self.displayableBodyText = [self displayableBodyTextForOversizeTextAttachment:oversizeTextAttachmentStream
                                                                               ranges:message.bodyRanges
                                                                        interactionId:message.uniqueId
                                                                          transaction:transaction];
    } else if ([oversizeTextAttachment isKindOfClass:[TSAttachmentPointer class]]) {
        TSAttachmentPointer *oversizeTextAttachmentPointer = (TSAttachmentPointer *)oversizeTextAttachment;
        // TODO: Handle backup restore.
        self.messageCellType = OWSMessageCellType_OversizeTextDownloading;
        self.attachmentPointer = (TSAttachmentPointer *)oversizeTextAttachmentPointer;
        return;
    } else if (message.body.length > 0) {
        self.displayableBodyText = [self displayableBodyTextForText:message.body
                                                             ranges:message.bodyRanges
                                                      interactionId:message.uniqueId
                                                        transaction:transaction];
    }

    NSArray<TSAttachment *> *mediaAttachments = [message mediaAttachmentsWithTransaction:transaction.unwrapGrdbRead];
    NSArray<ConversationMediaAlbumItem *> *mediaAlbumItems = [self albumItemsForMediaAttachments:mediaAttachments
                                                                                     transaction:transaction];
    if (mediaAlbumItems.count > 0) {
        if (mediaAlbumItems.count == 1) {
            ConversationMediaAlbumItem *mediaAlbumItem = mediaAlbumItems.firstObject;
            if (mediaAlbumItem.attachmentStream && !mediaAlbumItem.attachmentStream.isValidVisualMedia) {
                OWSLogWarn(@"Treating invalid media as generic attachment.");
                self.messageCellType = OWSMessageCellType_GenericAttachment;
                return;
            }
        }

        self.mediaAlbumItems = mediaAlbumItems;
        self.messageCellType = OWSMessageCellType_MediaMessage;
        return;
    }

    // Only media galleries should have more than one attachment.
    OWSAssertDebug(mediaAttachments.count <= 1);

    TSAttachment *_Nullable mediaAttachment = mediaAttachments.firstObject;
    if (mediaAttachment) {
        if ([mediaAttachment isKindOfClass:[TSAttachmentStream class]]) {
            self.attachmentStream = (TSAttachmentStream *)mediaAttachment;
            if ([self.attachmentStream isAudio]) {
                CGFloat audioDurationSeconds = [self.attachmentStream audioDurationSeconds];
                if (audioDurationSeconds > 0) {
                    self.audioDurationSeconds = audioDurationSeconds;
                    self.messageCellType = OWSMessageCellType_Audio;
                } else {
                    self.messageCellType = OWSMessageCellType_GenericAttachment;
                }
            } else if (self.messageCellType == OWSMessageCellType_Unknown) {
                self.messageCellType = OWSMessageCellType_GenericAttachment;
            }
        } else if ([mediaAttachment isKindOfClass:[TSAttachmentPointer class]]) {
            if ([mediaAttachment isAudio]) {
                self.audioDurationSeconds = 0;
                self.messageCellType = OWSMessageCellType_Audio;
            } else {
                self.messageCellType = OWSMessageCellType_GenericAttachment;
            }
            self.attachmentPointer = (TSAttachmentPointer *)mediaAttachment;
        } else {
            OWSFailDebug(@"Unknown attachment type");
        }
    }

    if (self.hasBodyText) {
        if (self.messageCellType == OWSMessageCellType_Unknown) {
            OWSAssertDebug(message.attachmentIds.count == 0
                || (message.attachmentIds.count == 1 &&
                    [message oversizeTextAttachmentWithTransaction:transaction.unwrapGrdbRead] != nil));
            self.messageCellType = OWSMessageCellType_TextOnlyMessage;
        }
        OWSAssertDebug(self.displayableBodyText);
    }

    if (self.hasBodyText && message.linkPreview) {
        NSURL *_Nullable url = [NSURL URLWithString:message.linkPreview.urlString];
        GroupInviteLinkInfo *_Nullable groupInviteLinkInfo = [GroupManager parseGroupInviteLink:url];
        if (groupInviteLinkInfo != nil) {
            self.groupInviteLinkViewModel = [self configureGroupInviteLink:url
                                                                   message:message
                                                       groupInviteLinkInfo:groupInviteLinkInfo];
            if (!self.groupInviteLinkViewModel.isExpired) {
                self.linkPreview = message.linkPreview;
            }
        } else {
            self.linkPreview = message.linkPreview;

            if (message.linkPreview.imageAttachmentId.length > 0) {
                TSAttachment *_Nullable linkPreviewAttachment =
                    [TSAttachment anyFetchWithUniqueId:message.linkPreview.imageAttachmentId transaction:transaction];
                if (!linkPreviewAttachment) {
                    OWSFailDebug(@"Could not load link preview image attachment.");
                } else if (!linkPreviewAttachment.isImage) {
                    OWSFailDebug(@"Link preview attachment isn't an image.");
                } else if ([linkPreviewAttachment isKindOfClass:[TSAttachmentStream class]]) {
                    TSAttachmentStream *attachmentStream = (TSAttachmentStream *)linkPreviewAttachment;
                    if (!attachmentStream.isValidImage) {
                        OWSFailDebug(@"Link preview image attachment isn't valid.");
                    } else {
                        self.linkPreviewAttachment = linkPreviewAttachment;
                    }
                } else {
                    self.linkPreviewAttachment = linkPreviewAttachment;
                }
            }
        }
    }

    if (self.messageCellType == OWSMessageCellType_Unknown) {
        // Messages of unknown type (including messages with missing attachments)
        // are rendered like empty text messages, but without any interactivity.
        OWSLogWarn(@"Treating unknown message as empty text message: %@ %llu", message.class, message.timestamp);
        self.messageCellType = OWSMessageCellType_TextOnlyMessage;
        self.displayableBodyText = DisplayableText.empty;
    }
}

- (void)configureViewOnceMessage:(TSMessage *)message transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(message != nil);
    OWSAssertDebug(transaction != nil);
    OWSAssertDebug(message.isViewOnceMessage);

    if (self.interaction.interactionType == OWSInteractionType_OutgoingMessage) {
        if (message.isViewOnceComplete) {
            self.messageCellType = OWSMessageCellType_ViewOnce;
            self.viewOnceMessageState = ViewOnceMessageState_OutgoingSentExpired;
            return;
        }

        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)message;
        switch (outgoingMessage.messageState) {
            case TSOutgoingMessageStateSending:
                self.viewOnceMessageState = ViewOnceMessageState_OutgoingSending;
                break;
            case TSOutgoingMessageStateFailed:
                self.viewOnceMessageState = ViewOnceMessageState_OutgoingFailed;
                break;
            default:
                self.viewOnceMessageState = ViewOnceMessageState_OutgoingSentExpired;
                break;
        }
        self.messageCellType = OWSMessageCellType_ViewOnce;
        return;
    }
    if (message.isViewOnceComplete) {
        self.messageCellType = OWSMessageCellType_ViewOnce;
        self.viewOnceMessageState = ViewOnceMessageState_IncomingExpired;
        return;
    }
    if (message.attachmentIds.count > 1 || message.body.length > 0) {
        // Refuse to render incoming "view once" messages if they
        // have more than one attachment or any body text.
        self.messageCellType = OWSMessageCellType_ViewOnce;
        self.viewOnceMessageState = ViewOnceMessageState_IncomingInvalidContent;
        return;
    }
    NSArray<TSAttachment *> *mediaAttachments = [message mediaAttachmentsWithTransaction:transaction.unwrapGrdbRead];
    // TODO: We currently only support single attachments for
    //       view-once messages.
    TSAttachment *_Nullable mediaAttachment = mediaAttachments.firstObject;
    if ([mediaAttachment isKindOfClass:[TSAttachmentPointer class]]) {
        self.messageCellType = OWSMessageCellType_ViewOnce;
        self.attachmentPointer = (TSAttachmentPointer *)mediaAttachment;
        self.viewOnceMessageState = (self.attachmentPointer.state == TSAttachmentPointerStateFailed
                ? ViewOnceMessageState_IncomingFailed
                : ViewOnceMessageState_IncomingDownloading);
        return;
    } else if ([mediaAttachment isKindOfClass:[TSAttachmentStream class]]) {
        TSAttachmentStream *attachmentStream = (TSAttachmentStream *)mediaAttachment;
        if (attachmentStream.isValidVisualMedia
            && (attachmentStream.isImage || attachmentStream.isAnimated || attachmentStream.isVideo)) {
            self.messageCellType = OWSMessageCellType_ViewOnce;
            self.viewOnceMessageState = ViewOnceMessageState_IncomingAvailable;
            self.attachmentStream = attachmentStream;
        } else {
            self.messageCellType = OWSMessageCellType_ViewOnce;
            self.viewOnceMessageState = ViewOnceMessageState_IncomingInvalidContent;
        }
        return;
    }

    OWSFailDebug(@"Invalid media for view-once message.");
    self.messageCellType = OWSMessageCellType_ViewOnce;
    self.viewOnceMessageState = ViewOnceMessageState_IncomingInvalidContent;
}

- (NSArray<ConversationMediaAlbumItem *> *)albumItemsForMediaAttachments:(NSArray<TSAttachment *> *)attachments
                                                             transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertIsOnMainThread();

    NSMutableArray<ConversationMediaAlbumItem *> *mediaAlbumItems = [NSMutableArray new];
    for (TSAttachment *attachment in attachments) {
        if (!attachment.isVisualMedia) {
            // Well behaving clients should not send a mix of visual media (like JPG) and non-visual media (like PDF's)
            // Since we're not coped to handle a mix of media, return @[]
            OWSAssertDebug(mediaAlbumItems.count == 0);
            return @[];
        }


        NSString *_Nullable caption = (attachment.caption ? [self displayableCaptionForText:attachment.caption
                                                                               attachmentId:attachment.uniqueId
                                                                                transaction:transaction]
                                                                .displayAttributedText.string
                                                          : nil);

        if (![attachment isKindOfClass:[TSAttachmentStream class]]) {
            TSAttachmentPointer *attachmentPointer = (TSAttachmentPointer *)attachment;
            CGSize mediaSize = CGSizeZero;
            if (attachmentPointer.mediaSize.width > 0 && attachmentPointer.mediaSize.height > 0) {
                mediaSize = attachmentPointer.mediaSize;
            }
            [mediaAlbumItems addObject:[[ConversationMediaAlbumItem alloc] initWithAttachment:attachment
                                                                             attachmentStream:nil
                                                                                      caption:caption
                                                                                    mediaSize:mediaSize]];
            continue;
        }
        TSAttachmentStream *attachmentStream = (TSAttachmentStream *)attachment;
        if (![attachmentStream isValidVisualMedia]) {
            OWSLogWarn(@"Filtering invalid media.");
            [mediaAlbumItems addObject:[[ConversationMediaAlbumItem alloc] initWithAttachment:attachment
                                                                             attachmentStream:nil
                                                                                      caption:caption
                                                                                    mediaSize:CGSizeZero]];
            continue;
        }
        CGSize mediaSize = [attachmentStream imageSize];
        if (mediaSize.width <= 0 || mediaSize.height <= 0) {
            OWSLogWarn(@"Filtering media with invalid size.");
            [mediaAlbumItems addObject:[[ConversationMediaAlbumItem alloc] initWithAttachment:attachment
                                                                             attachmentStream:nil
                                                                                      caption:caption
                                                                                    mediaSize:CGSizeZero]];
            continue;
        }

        ConversationMediaAlbumItem *mediaAlbumItem =
            [[ConversationMediaAlbumItem alloc] initWithAttachment:attachment
                                                  attachmentStream:attachmentStream
                                                           caption:caption
                                                         mediaSize:mediaSize];
        [mediaAlbumItems addObject:mediaAlbumItem];
    }
    return mediaAlbumItems;
}

- (NSString *)systemMessageTextWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(transaction);

    switch (self.interaction.interactionType) {
        case OWSInteractionType_Error: {
            TSErrorMessage *errorMessage = (TSErrorMessage *)self.interaction;
            return [errorMessage previewTextWithTransaction:transaction];
        }
        case OWSInteractionType_Info: {
            TSInfoMessage *infoMessage = (TSInfoMessage *)self.interaction;
            if ([infoMessage isKindOfClass:[OWSVerificationStateChangeMessage class]]) {
                OWSVerificationStateChangeMessage *verificationMessage
                    = (OWSVerificationStateChangeMessage *)infoMessage;
                BOOL isVerified = verificationMessage.verificationState == OWSVerificationStateVerified;
                NSString *displayName =
                    [self.contactsManager displayNameForAddress:verificationMessage.recipientAddress];
                NSString *titleFormat = (isVerified
                        ? (verificationMessage.isLocalChange
                                  ? NSLocalizedString(@"VERIFICATION_STATE_CHANGE_FORMAT_VERIFIED_LOCAL",
                                        @"Format for info message indicating that the verification state was verified "
                                        @"on "
                                        @"this device. Embeds {{user's name or phone number}}.")
                                  : NSLocalizedString(@"VERIFICATION_STATE_CHANGE_FORMAT_VERIFIED_OTHER_DEVICE",
                                        @"Format for info message indicating that the verification state was verified "
                                        @"on "
                                        @"another device. Embeds {{user's name or phone number}}."))
                        : (verificationMessage.isLocalChange
                                  ? NSLocalizedString(@"VERIFICATION_STATE_CHANGE_FORMAT_NOT_VERIFIED_LOCAL",
                                        @"Format for info message indicating that the verification state was "
                                        @"unverified on "
                                        @"this device. Embeds {{user's name or phone number}}.")
                                  : NSLocalizedString(@"VERIFICATION_STATE_CHANGE_FORMAT_NOT_VERIFIED_OTHER_DEVICE",
                                        @"Format for info message indicating that the verification state was "
                                        @"unverified on "
                                        @"another device. Embeds {{user's name or phone number}}.")));
                return [NSString stringWithFormat:titleFormat, displayName];
            } else {
                return [infoMessage systemMessageTextWithTransaction:transaction];
            }
        }
        case OWSInteractionType_Call: {
            TSCall *call = (TSCall *)self.interaction;
            return [call previewTextWithTransaction:transaction];
        }
        default:
            OWSFailDebug(@"not a system message.");
            return nil;
    }
}

- (nullable NSString *)quotedAttachmentMimetype
{
    return self.quotedReply.contentType;
}

- (nullable SignalServiceAddress *)quotedAuthorAddress
{
    return self.quotedReply.authorAddress;
}

- (OWSMessageCellType)messageCellType
{
    OWSAssertIsOnMainThread();

    return _messageCellType;
}

- (nullable DisplayableText *)displayableBodyText
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.hasViewState);

    OWSAssertDebug(_displayableBodyText);
    OWSAssertDebug(_displayableBodyText.displayAttributedText);
    OWSAssertDebug(_displayableBodyText.fullAttributedText);

    return _displayableBodyText;
}

- (nullable TSAttachmentStream *)attachmentStream
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.hasViewState);

    return _attachmentStream;
}

- (nullable TSAttachmentPointer *)attachmentPointer
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.hasViewState);

    return _attachmentPointer;
}

- (nullable DisplayableText *)displayableQuotedText
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.hasViewState);

    OWSAssertDebug(_displayableQuotedText);
    OWSAssertDebug(_displayableQuotedText.displayAttributedText);
    OWSAssertDebug(_displayableQuotedText.fullAttributedText);

    return _displayableQuotedText;
}

- (void)copyTextAction
{
    if (self.attachmentPointer != nil) {
        OWSFailDebug(@"Can't copy not-yet-downloaded attachment");
        return;
    }

    switch (self.messageCellType) {
        case OWSMessageCellType_TextOnlyMessage:
        case OWSMessageCellType_Audio:
        case OWSMessageCellType_MediaMessage:
        case OWSMessageCellType_GenericAttachment: {
            OWSAssertDebug(self.displayableBodyText);
            [MentionTextView copyAttributedStringToPasteboard:self.displayableBodyText.fullAttributedText];
            break;
        }
        case OWSMessageCellType_Unknown:
        case OWSMessageCellType_StickerMessage: {
            OWSFailDebug(@"No text to copy");
            break;
        }
        case OWSMessageCellType_ContactShare: {
            // TODO: Implement copy contact.
            OWSFailDebug(@"Not implemented yet");
            break;
        }
        case OWSMessageCellType_OversizeTextDownloading:
            OWSFailDebug(@"Can't copy not-yet-downloaded attachment");
            return;
        case OWSMessageCellType_ViewOnce:
            OWSFailDebug(@"Can't copy view once message");
            return;
    }
}

- (void)shareMediaAction:(nullable id)sender
{
    if (self.attachmentPointer != nil) {
        OWSFailDebug(@"Can't share not-yet-downloaded attachment");
        return;
    }

    switch (self.messageCellType) {
        case OWSMessageCellType_Unknown:
        case OWSMessageCellType_TextOnlyMessage:
        case OWSMessageCellType_ContactShare: {
            OWSFailDebug(@"No media to share");
            break;
        }
        case OWSMessageCellType_Audio:
        case OWSMessageCellType_GenericAttachment: {
            [AttachmentSharing showShareUIForAttachment:self.attachmentStream sender:sender];
            break;
        }
        case OWSMessageCellType_MediaMessage: {
            NSMutableArray<TSAttachmentStream *> *downloadedAttachments = [NSMutableArray new];
            for (ConversationMediaAlbumItem *item in self.mediaAlbumItems) {
                if (item.attachmentStream) {
                    [downloadedAttachments addObject:item.attachmentStream];
                }
            }

            if (downloadedAttachments.count == 0) {
                OWSFailDebug(@"No attachments downloaded to share.");
                break;
            }

            [AttachmentSharing showShareUIForAttachments:downloadedAttachments sender:sender];
            break;
        }
        case OWSMessageCellType_OversizeTextDownloading:
            OWSFailDebug(@"Can't share not-yet-downloaded attachment");
            return;
        case OWSMessageCellType_StickerMessage:
            OWSFailDebug(@"Can't share stickers.");
            return;
        case OWSMessageCellType_ViewOnce:
            OWSFailDebug(@"Can't share view once messages");
            return;
    }
}

- (void)copyAttachmentToPasteboard:(TSAttachmentStream *)attachment
{
    OWSAssertDebug(attachment);

    NSString *utiType = [MIMETypeUtil utiTypeForMIMEType:attachment.contentType];
    if (!utiType) {
        OWSFailDebug(@"Unknown MIME type: %@", attachment.contentType);
        utiType = (NSString *)kUTTypeGIF;
    }
    NSData *_Nullable data = [NSData dataWithContentsOfURL:[attachment originalMediaURL]];
    if (!data) {
        OWSFailDebug(@"Could not load attachment data");
        return;
    }
    [UIPasteboard.generalPasteboard setData:data forPasteboardType:utiType];
}

- (BOOL)canShareMedia
{
    if (self.attachmentPointer != nil) {
        // The attachment is still downloading.
        return NO;
    }

    switch (self.messageCellType) {
        case OWSMessageCellType_Unknown:
        case OWSMessageCellType_TextOnlyMessage:
        case OWSMessageCellType_ContactShare:
            return NO;
        case OWSMessageCellType_Audio:
        case OWSMessageCellType_GenericAttachment:
            return self.attachmentStream != nil;
        case OWSMessageCellType_MediaMessage: {
            for (ConversationMediaAlbumItem *mediaAlbumItem in self.mediaAlbumItems) {
                if (!mediaAlbumItem.attachmentStream) {
                    continue;
                }
                if (!mediaAlbumItem.attachmentStream.isValidVisualMedia) {
                    continue;
                }
                if (mediaAlbumItem.attachmentStream.isImage || mediaAlbumItem.attachmentStream.isAnimated) {
                    return YES;
                }
                if (mediaAlbumItem.attachmentStream.isVideo) {
                    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(
                            mediaAlbumItem.attachmentStream.originalFilePath)) {
                        return YES;
                    }
                }
            }
            return NO;
        }
        case OWSMessageCellType_OversizeTextDownloading:
        case OWSMessageCellType_StickerMessage:
        case OWSMessageCellType_ViewOnce:
            return NO;
    }
}

- (BOOL)canForwardMessage
{
    switch (self.messageCellType) {
        case OWSMessageCellType_Unknown:
            return NO;
        case OWSMessageCellType_TextOnlyMessage:
            return YES;
        case OWSMessageCellType_ContactShare:
            return YES;
        case OWSMessageCellType_Audio:
        case OWSMessageCellType_GenericAttachment:
            return self.attachmentStream != nil;
        case OWSMessageCellType_MediaMessage:
            return [self canShareMedia];
        case OWSMessageCellType_OversizeTextDownloading:
            return NO;
        case OWSMessageCellType_StickerMessage:
            return YES;
        case OWSMessageCellType_ViewOnce:
            return NO;
    }
}

- (void)deleteAction
{
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [self.interaction anyRemoveWithTransaction:transaction];
    });
}

- (BOOL)hasBodyTextActionContent
{
    return self.hasBodyText && self.displayableBodyText.fullAttributedText.length > 0;
}

- (BOOL)hasMediaActionContent
{
    if (self.attachmentPointer != nil) {
        // The attachment is still downloading.
        return NO;
    }

    switch (self.messageCellType) {
        case OWSMessageCellType_Unknown:
        case OWSMessageCellType_TextOnlyMessage:
        case OWSMessageCellType_ContactShare:
            return NO;
        case OWSMessageCellType_Audio:
        case OWSMessageCellType_GenericAttachment:
            return self.attachmentStream != nil;
        case OWSMessageCellType_MediaMessage:
            return self.firstValidAlbumAttachment != nil;
        case OWSMessageCellType_OversizeTextDownloading:
            return NO;
        case OWSMessageCellType_StickerMessage:
            return self.stickerAttachment != nil;
        case OWSMessageCellType_ViewOnce:
            return NO;
    }
}

- (BOOL)mediaAlbumHasFailedAttachment
{
    OWSAssertDebug(self.messageCellType == OWSMessageCellType_MediaMessage);
    OWSAssertDebug(self.mediaAlbumItems.count > 0);

    for (ConversationMediaAlbumItem *mediaAlbumItem in self.mediaAlbumItems) {
        if (mediaAlbumItem.isFailedDownload) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)mediaAlbumHasPendingMessageRequestAttachment
{
    OWSAssertDebug(self.messageCellType == OWSMessageCellType_MediaMessage);
    OWSAssertDebug(self.mediaAlbumItems.count > 0);

    for (ConversationMediaAlbumItem *mediaAlbumItem in self.mediaAlbumItems) {
        if (mediaAlbumItem.isPendingMessageRequest) {
            return YES;
        }
    }
    return NO;
}

@end

NS_ASSUME_NONNULL_END
