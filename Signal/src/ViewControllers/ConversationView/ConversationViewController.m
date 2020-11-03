//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "ConversationViewController.h"
#import "AppDelegate.h"
#import "BlockListUIUtils.h"
#import "BlockListViewController.h"
#import "ContactsViewHelper.h"
#import "ConversationCollectionView.h"
#import "ConversationInputToolbar.h"
#import "ConversationScrollButton.h"
#import "ConversationViewCell.h"
#import "ConversationViewItem.h"
#import "ConversationViewLayout.h"
#import "ConversationViewModel.h"
#import "DateUtil.h"
#import "DebugUITableViewController.h"
#import "FingerprintViewController.h"
#import "OWSAudioPlayer.h"
#import "OWSDisappearingMessagesJob.h"
#import "OWSMath.h"
#import "OWSMessageCell.h"
#import "OWSMessageStickerView.h"
#import "OWSMessageViewOnceView.h"
#import "OWSSystemMessageCell.h"
#import "Signal-Swift.h"
#import "TSAttachmentPointer.h"
#import "TSCall.h"
#import "TSContactThread.h"
#import "TSErrorMessage.h"
#import "TSGroupThread.h"
#import "TSIncomingMessage.h"
#import "TSInfoMessage.h"
#import "TSInvalidIdentityKeyErrorMessage.h"
#import "UIFont+OWS.h"
#import "UIViewController+Permissions.h"
#import "ViewControllerUtils.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <ContactsUI/CNContactViewController.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <Photos/Photos.h>
#import <PromiseKit/AnyPromise.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <SignalCoreKit/Threading.h>
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/OWSContactsManager.h>
#import <SignalMessaging/OWSNavigationController.h>
#import <SignalMessaging/SignalMessaging-Swift.h>
#import <SignalMessaging/ThreadUtil.h>
#import <SignalMessaging/UIUtil.h>
#import <SignalMessaging/UIViewController+OWS.h>
#import <SignalServiceKit/Contact.h>
#import <SignalServiceKit/MessageSender.h>
#import <SignalServiceKit/MimeTypeUtil.h>
#import <SignalServiceKit/NSTimer+OWS.h>
#import <SignalServiceKit/OWSAddToContactsOfferMessage.h>
#import <SignalServiceKit/OWSAddToProfileWhitelistOfferMessage.h>
#import <SignalServiceKit/OWSAttachmentDownloads.h>
#import <SignalServiceKit/OWSBlockingManager.h>
#import <SignalServiceKit/OWSDisappearingMessagesConfiguration.h>
#import <SignalServiceKit/OWSFormat.h>
#import <SignalServiceKit/OWSIdentityManager.h>
#import <SignalServiceKit/OWSMessageManager.h>
#import <SignalServiceKit/OWSMessageUtils.h>
#import <SignalServiceKit/OWSReadReceiptManager.h>
#import <SignalServiceKit/OWSVerificationStateChangeMessage.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>
#import <SignalServiceKit/TSAccountManager.h>
#import <SignalServiceKit/TSGroupModel.h>
#import <SignalServiceKit/TSInvalidIdentityKeyReceivingErrorMessage.h>
#import <SignalServiceKit/TSNetworkManager.h>
#import <SignalServiceKit/TSOutgoingDeleteMessage.h>
#import <SignalServiceKit/TSQuotedMessage.h>

@import SafariServices;

NS_ASSUME_NONNULL_BEGIN

static const CGFloat kToastInset = 10;

typedef enum : NSUInteger {
    kMediaTypePicture,
    kMediaTypeVideo,
} kMediaTypes;

typedef enum : NSUInteger {
    kScrollContinuityBottom = 0,
    kScrollContinuityTop,
} ScrollContinuity;

#pragma mark -

@interface ConversationViewController () <AttachmentApprovalViewControllerDelegate,
    ContactShareApprovalViewControllerDelegate,
    AVAudioPlayerDelegate,
    CNContactViewControllerDelegate,
    ContactsPickerDelegate,
    ContactShareViewHelperDelegate,
    ConversationSettingsViewDelegate,
    ConversationHeaderViewDelegate,
    ConversationViewLayoutDelegate,
    ConversationViewCellDelegate,
    ConversationInputTextViewDelegate,
    ConversationSearchControllerDelegate,
    ContactsViewHelperObserver,
    LongTextViewDelegate,
    MessageDetailViewDelegate,
    OWSMessageBubbleViewDelegate,
    OWSMessageStickerViewDelegate,
    OWSMessageViewOnceViewDelegate,
    UICollectionViewDelegate,
    UICollectionViewDataSource,
    UIDocumentMenuDelegate,
    UIDocumentPickerDelegate,
    SendMediaNavDelegate,
    UINavigationControllerDelegate,
    UITextViewDelegate,
    ConversationCollectionViewDelegate,
    ConversationInputToolbarDelegate,
    ConversationViewModelDelegate,
    LocationPickerDelegate,
    InputAccessoryViewPlaceholderDelegate>

@property (nonatomic, readonly) ConversationViewModel *conversationViewModel;

@property (nonatomic, readonly) OWSAudioActivity *recordVoiceNoteAudioActivity;

@property (nonatomic, readonly) UIView *bottomBar;
@property (nonatomic, nullable) NSLayoutConstraint *bottomBarBottomConstraint;
@property (nonatomic, readonly) InputAccessoryViewPlaceholder *inputAccessoryPlaceholder;
@property (nonatomic) BOOL isDismissingInteractively;

@property (nonatomic, readonly) ConversationInputToolbar *inputToolbar;
@property (nonatomic, readonly) ConversationCollectionView *collectionView;
@property (nonatomic, readonly) ConversationViewLayout *layout;
@property (nonatomic, readonly) ConversationStyle *conversationStyle;

@property (nonatomic, nullable) AVAudioRecorder *audioRecorder;
@property (nonatomic, nullable) OWSAudioPlayer *audioAttachmentPlayer;
@property (nonatomic, nullable) NSUUID *voiceMessageUUID;

@property (nonatomic, nullable) NSTimer *readTimer;
@property (nonatomic) BOOL isMarkingAsRead;
@property (nonatomic) NSCache *cellMediaCache;
@property (nonatomic) ConversationHeaderView *headerView;
@property (nonatomic, nullable) UIView *bannerView;

@property (nonatomic) ConversationViewAction actionOnOpen;

@property (nonatomic, getter=isInPreviewPlatter) BOOL inPreviewPlatter;

@property (nonatomic) BOOL userHasScrolled;
@property (nonatomic, nullable) NSDate *lastMessageSentDate;

@property (nonatomic, readonly) BOOL showLoadOlderHeader;
@property (nonatomic, readonly) BOOL showLoadNewerHeader;
@property (nonatomic) uint64_t lastSortIdMarkedRead;

@property (nonatomic) BOOL isUserScrolling;
@property (nonatomic) BOOL isWaitingForDeceleration;
@property (nonatomic, nullable) ConversationScrollState *scrollStateBeforeLoadingMore;

@property (nonatomic) ConversationScrollButton *scrollDownButton;
@property (nonatomic) BOOL isHidingScrollDownButton;
@property (nonatomic) ConversationScrollButton *scrollToNextMentionButton;
@property (nonatomic) BOOL isHidingScrollToNextMentionButton;

@property (nonatomic) BOOL isViewCompletelyAppeared;
@property (nonatomic) BOOL isViewVisible;
@property (nonatomic) BOOL shouldAnimateKeyboardChanges;
@property (nonatomic) BOOL viewHasEverAppeared;
@property (nonatomic) BOOL hasViewWillAppearOccurred;
@property (nonatomic) NSUInteger unreadMessageCount;
@property (nonatomic, nullable) NSArray<TSMessage *> *unreadMentionMessages;
@property (nonatomic, nullable) NSNumber *viewHorizonTimestamp;
@property (nonatomic) ContactShareViewHelper *contactShareViewHelper;
@property (nonatomic) NSTimer *reloadTimer;
@property (nonatomic, nullable) NSDate *lastReloadDate;

@property (nonatomic, nullable) NSNumber *lastKnownDistanceFromBottom;
@property (nonatomic) ScrollContinuity scrollContinuity;
@property (nonatomic) ScrollContinuity scrollContinuityWhenBackgrounded;
@property (nonatomic, nullable) NSTimer *scrollUpdateTimer;

@property (nonatomic, readonly) ConversationSearchController *searchController;
@property (nonatomic, nullable) NSString *lastSearchedText;

@property (nonatomic, nullable) UIView *requestView;

@property (nonatomic) UITapGestureRecognizer *tapGestureRecognizer;

@property (nonatomic, nullable) MessageActionsViewController *messageActionsViewController;
@property (nonatomic) CGFloat messageActionsExtraContentInsetPadding;
@property (nonatomic) CGPoint messageActionsOriginalContentOffset;
@property (nonatomic) CGFloat messageActionsOriginalFocusY;

@property (nonatomic, nullable, weak) ReactionsDetailSheet *reactionsDetailSheet;
@property (nonatomic) ConversationUIMode uiMode;
@property (nonatomic) MessageActionsToolbar *selectionToolbar;
@property (nonatomic, readonly) SelectionHighlightView *selectionHighlightView;
@property (nonatomic) NSDictionary<NSString *, id<ConversationViewItem>> *selectedItems;

@property (nonatomic) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;

@property (nonatomic) DebouncedEvent *otherUsersProfileDidChangeEvent;

@end

#pragma mark -

@implementation ConversationViewController

- (instancetype)initWithThreadViewModel:(ThreadViewModel *)threadViewModel
                                 action:(ConversationViewAction)action
                         focusMessageId:(nullable NSString *)focusMessageId
{
    self = [super init];

    // If we're not scrolling to a specific message AND we don't have
    // any unread messages, try and focus on the last visible interaction
    if (focusMessageId == nil && !threadViewModel.hasUnreadMessages) {
        focusMessageId = threadViewModel.lastVisibleInteraction.uniqueId;
    }

    [self.contactsViewHelper addObserver:self];
    _contactShareViewHelper = [[ContactShareViewHelper alloc] initWithContactsManager:self.contactsManager];
    _contactShareViewHelper.delegate = self;

    NSString *audioActivityDescription = [NSString stringWithFormat:@"%@ voice note", self.logTag];
    _recordVoiceNoteAudioActivity = [[OWSAudioActivity alloc] initWithAudioDescription:audioActivityDescription behavior:OWSAudioBehavior_PlayAndRecord];

    self.scrollContinuity = kScrollContinuityBottom;

    _inputAccessoryPlaceholder = [InputAccessoryViewPlaceholder new];
    self.inputAccessoryPlaceholder.delegate = self;

    _threadViewModel = threadViewModel;

    self.actionOnOpen = action;
    _cellMediaCache = [NSCache new];
    // Cache the cell media for ~24 cells.
    self.cellMediaCache.countLimit = 24;
    _conversationStyle = [[ConversationStyle alloc] initWithThread:self.thread];

    _selectedItems = @{};

    _conversationViewModel = [[ConversationViewModel alloc] initWithThread:self.thread
                                                      focusMessageIdOnOpen:focusMessageId
                                                                  delegate:self];

    _searchController = [[ConversationSearchController alloc] initWithThread:self.thread];
    _searchController.delegate = self;

    // because the search bar view is hosted in the navigation bar, it's not in the CVC's responder
    // chain, and thus won't inherit our inputAccessoryView, so we manually set it here.
    OWSAssertDebug(self.inputAccessoryPlaceholder != nil);
    _searchController.uiSearchController.searchBar.inputAccessoryView = self.inputAccessoryPlaceholder;

    self.reloadTimer = [NSTimer weakTimerWithTimeInterval:1.f
                                                   target:self
                                                 selector:@selector(reloadTimerDidFire)
                                                 userInfo:nil
                                                  repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.reloadTimer forMode:NSRunLoopCommonModes];

    [self updateV2GroupIfNecessary];

    _longPressGestureRecognizer = [UILongPressGestureRecognizer new];
    _panGestureRecognizer = [UIPanGestureRecognizer new];

    __weak ConversationViewController *weakSelf = self;
    _otherUsersProfileDidChangeEvent =
        [[DebouncedEvent alloc] initWithMaxFrequencySeconds:1.0
                                                    onQueue:dispatch_get_main_queue()
                                                notifyBlock:^{
                                                    // Reload all cells if this is a group conversation,
                                                    // since we may need to update the sender names on the messages.
                                                    [weakSelf resetContentAndLayoutWithSneakyTransaction];
                                                }];
    return self;
}

#pragma mark -

- (void)addNotificationListeners
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(blockListDidChange:)
                                                 name:kNSNotificationName_BlockListDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowManagerCallDidChange:)
                                                 name:OWSWindowManagerCallDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(identityStateDidChange:)
                                                 name:kNSNotificationNameIdentityStateDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:OWSApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:OWSApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:OWSApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:OWSApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cancelReadTimer)
                                                 name:OWSApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(otherUsersProfileDidChange:)
                                                 name:kNSNotificationNameOtherUsersProfileDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(profileWhitelistDidChange:)
                                                 name:kNSNotificationNameProfileWhitelistDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeDidChange:)
                                                 name:ThemeDidChangeNotification
                                               object:nil];
}

- (BOOL)isGroupConversation
{
    OWSAssertDebug(self.thread);

    return self.thread.isGroupThread;
}

- (TSThread *)thread {
    OWSAssertDebug(self.threadViewModel);
    return self.threadViewModel.threadRecord;
}

- (OWSDisappearingMessagesConfiguration *)disappearingMessagesConfiguration
{
    OWSAssertDebug(self.threadViewModel);
    return self.threadViewModel.disappearingMessagesConfiguration;
}

- (void)otherUsersProfileDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    SignalServiceAddress *address = notification.userInfo[kNSNotificationKey_ProfileAddress];
    OWSAssertDebug(address.isValid);
    if (address.isValid && [self.thread.recipientAddresses containsObject:address]) {
        if ([self.thread isKindOfClass:[TSContactThread class]]) {
            // update title with profile name
            [self updateNavigationTitle];
        }

        // Reload all cells if this is a group conversation,
        // since we may need to update the sender names on the messages.
        // Use a DebounceEvent to de-bounce.
        if (self.isGroupConversation) {
            [self.otherUsersProfileDidChangeEvent requestNotify];
        }
    }
}

- (void)profileWhitelistDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    // If profile whitelist just changed, we may want to hide a profile whitelist offer.
    SignalServiceAddress *_Nullable address = notification.userInfo[kNSNotificationKey_ProfileAddress];
    NSData *_Nullable groupId = notification.userInfo[kNSNotificationKey_ProfileGroupId];
    if (address.isValid && [self.thread.recipientAddresses containsObject:address]) {
        [self ensureBannerState];
        [self showMessageRequestDialogIfRequired];
    } else if (groupId.length > 0 && self.thread.isGroupThread) {
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        if ([groupThread.groupModel.groupId isEqualToData:groupId]) {
            [self ensureBannerState];
            [self showMessageRequestDialogIfRequired];
        }
    }
}

- (void)blockListDidChange:(id)notification
{
    OWSAssertIsOnMainThread();

    [self ensureBannerState];
}

- (void)identityStateDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    [self updateNavigationBarSubtitleLabel];
    [self ensureBannerState];
}

- (void)themeDidChange:(NSNotification *)notification
{
    [self applyTheme];
}

- (void)setInPreviewPlatter:(BOOL)inPreviewPlatter
{
    if (_inPreviewPlatter != inPreviewPlatter) {
        _inPreviewPlatter = inPreviewPlatter;
        [self configureScrollDownButtons];
    }
}

- (void)peekSetup
{
    [self setInPreviewPlatter:YES];
    self.actionOnOpen = ConversationViewActionNone;
}

- (void)popped
{
    [self setInPreviewPlatter:NO];
    [self updateInputVisibility];
}

- (void)updateV2GroupIfNecessary
{
    if (!self.thread.isGroupV2Thread) {
        return;
    }
    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    // Try to update the v2 group to latest from the service.
    // This will help keep us in sync if we've missed any group updates, etc.
    [self.groupV2UpdatesObjc tryToRefreshV2GroupUpToCurrentRevisionAfterMessageProcessingWithThrottling:groupThread];
}

- (void)dealloc
{
    [self.reloadTimer invalidate];
    [self.scrollUpdateTimer invalidate];
}

- (void)reloadTimerDidFire
{
    OWSAssertIsOnMainThread();

    if (self.isUserScrolling || !self.isViewCompletelyAppeared || !self.isViewVisible
        || !CurrentAppContext().isAppForegroundAndActive || !self.viewHasEverAppeared
        || self.isPresentingMessageActions) {
        return;
    }

    NSDate *now = [NSDate new];
    if (self.lastReloadDate) {
        NSTimeInterval timeSinceLastReload = [now timeIntervalSinceDate:self.lastReloadDate];
        const NSTimeInterval kReloadFrequency = 60.f;
        if (timeSinceLastReload < kReloadFrequency) {
            return;
        }
    }

    OWSLogVerbose(@"reloading conversation view contents.");
    [self resetContentAndLayoutWithSneakyTransaction];
}

- (BOOL)userLeftGroup
{
    if (![self.thread isKindOfClass:[TSGroupThread class]]) {
        return NO;
    }

    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    return !groupThread.isLocalUserFullMember;
}

- (BOOL)isLocalUserRequestingMember
{
    if ([self.thread isKindOfClass:[TSGroupThread class]]) {
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        return groupThread.isLocalUserRequestingMember;
    } else {
        return NO;
    }
}

- (void)updateInputVisibility
{
    if ([self isInPreviewPlatter]) {
        self.inputToolbar.hidden = YES;
        [self dismissKeyBoard];
        return;
    }

    if (self.userLeftGroup) {
        self.inputToolbar.hidden = YES; // user has requested they leave the group. further sends disallowed
        [self dismissKeyBoard];
    } else {
        self.inputToolbar.hidden = NO;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self createContents];

    [self createGestureRecognizers];

    [self registerCellClasses];

    [self createConversationScrollButtons];
    [self createHeaderViews];

    [self updateLeftBarItem];

    [self addNotificationListeners];
    [self applyTheme];
    [self.conversationViewModel viewDidLoad];
}

- (void)createContents
{
    OWSAssertDebug(self.conversationStyle);

    _layout = [[ConversationViewLayout alloc] initWithConversationStyle:self.conversationStyle];
    self.conversationStyle.viewWidth = floor(self.view.width);

    self.layout.delegate = self;
    // We use the root view bounds as the initial frame for the collection
    // view so that its contents can be laid out immediately.
    //
    // TODO: To avoid relayout, it'd be better to take into account safeAreaInsets,
    //       but they're not yet set when this method is called.
    _collectionView = [[ConversationCollectionView alloc] initWithFrame:self.view.bounds
                                                   collectionViewLayout:self.layout];
    self.collectionView.layoutDelegate = self;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.showsVerticalScrollIndicator = YES;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.collectionView.allowsMultipleSelection = YES;

    // To minimize time to initial apearance, we initially disable prefetching, but then
    // re-enable it once the view has appeared.
    self.collectionView.prefetchingEnabled = NO;

    [self.view addSubview:self.collectionView];
    [self.collectionView autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [self.collectionView autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    [self.collectionView autoPinEdgeToSuperviewSafeArea:ALEdgeLeading];
    [self.collectionView autoPinEdgeToSuperviewSafeArea:ALEdgeTrailing];

    [self.collectionView applyScrollViewInsetsFix];
    SET_SUBVIEW_ACCESSIBILITY_IDENTIFIER(self, _collectionView);

    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyBoard)];
    [self.collectionView addGestureRecognizer:self.tapGestureRecognizer];

    _bottomBar = [UIView containerView];
    [self.view addSubview:self.bottomBar];
    self.bottomBarBottomConstraint = [self.bottomBar autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    [self.bottomBar autoPinWidthToSuperview];

    _selectionToolbar = [self buildSelectionToolbar];
    _selectionHighlightView = [SelectionHighlightView new];
    self.selectionHighlightView.userInteractionEnabled = NO;
    [self.collectionView addSubview:self.selectionHighlightView];

    // Selection Highlight View Layout:
    //
    // We want the highlight view to have the same frame as the collectionView
    // but [selectionHighlightView autoPinEdgesToSuperviewEdges] undesirably
    // affects the size of the collection view. To witness this, you can longpress
    // on an item and see the collectionView offsets change. Pinning to just the
    // top left and the same height/width achieves the desired results without
    // the negative side effects.
    [self.selectionHighlightView autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [self.selectionHighlightView autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [self.selectionHighlightView autoMatchDimension:ALDimensionWidth
                                        toDimension:ALDimensionWidth
                                             ofView:self.collectionView];
    [self.selectionHighlightView autoMatchDimension:ALDimensionHeight
                                        toDimension:ALDimensionHeight
                                             ofView:self.collectionView];

    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        [self updateShowLoadMoreHeadersWithTransaction:transaction];
    }];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)becomeFirstResponder
{
    BOOL result = [super becomeFirstResponder];

    // If we become the first responder, it means that the
    // input toolbar is not the first responder. As such,
    // we should clear out the desired keyboard since an
    // interactive dismissal may have just occured and we
    // need to update the UI to reflect that fact. We don't
    // actually ever want to be the first responder, so resign
    // immediately. We just want to know when the responder
    // state of our children changed and that information is
    // conveniently bubbled up the responder chain.
    if (result) {
        [self resignFirstResponder];
        [self.inputToolbar clearDesiredKeyboard];
    }

    return result;
}

- (nullable UIView *)inputAccessoryView
{
    return self.inputAccessoryPlaceholder;
}

- (nullable NSString *)textInputContextIdentifier
{
    return self.thread.uniqueId;
}

- (void)registerCellClasses
{
    [self.collectionView registerClass:[OWSSystemMessageCell class]
            forCellWithReuseIdentifier:[OWSSystemMessageCell cellReuseIdentifier]];
    [self.collectionView registerClass:[OWSTypingIndicatorCell class]
            forCellWithReuseIdentifier:[OWSTypingIndicatorCell cellReuseIdentifier]];
    [self.collectionView registerClass:[OWSThreadDetailsCell class]
            forCellWithReuseIdentifier:[OWSThreadDetailsCell cellReuseIdentifier]];
    [self.collectionView registerClass:[OWSUnreadIndicatorCell class]
            forCellWithReuseIdentifier:[OWSUnreadIndicatorCell cellReuseIdentifier]];
    [self.collectionView registerClass:[OWSDateHeaderCell class]
            forCellWithReuseIdentifier:[OWSDateHeaderCell cellReuseIdentifier]];
    [self.collectionView registerClass:LoadMoreMessagesView.class
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:LoadMoreMessagesView.reuseIdentifier];
    [self.collectionView registerClass:LoadMoreMessagesView.class
            forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                   withReuseIdentifier:LoadMoreMessagesView.reuseIdentifier];

    for (NSString *cellReuseIdentifier in OWSMessageCell.allCellReuseIdentifiers) {
        [self.collectionView registerClass:[OWSMessageCell class] forCellWithReuseIdentifier:cellReuseIdentifier];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self startReadTimer];
    [self updateCellsVisible];

    // If we were scrolled to the bottom, do our best to scroll any new
    // messages onto the screen.
    if (self.scrollContinuityWhenBackgrounded == kScrollContinuityBottom) {
        NSIndexPath *indexPathOfUnreadMessagesIndicator = [self indexPathOfUnreadMessagesIndicator];
        if (indexPathOfUnreadMessagesIndicator != nil) {
            [self scrollToInteractionWithIndexPath:indexPathOfUnreadMessagesIndicator
                                onScreenPercentage:1
                                          position:ScrollToTop
                                          animated:YES];
        }
    }
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    self.scrollContinuityWhenBackgrounded = self.scrollContinuity;
    [self updateCellsVisible];
    [self.cellMediaCache removeAllObjects];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [self cancelVoiceMemo];
    self.isUserScrolling = NO;
    self.isWaitingForDeceleration = NO;
    [self saveDraft];
    [self markVisibleMessagesAsRead];
    [self.cellMediaCache removeAllObjects];
    [self cancelReadTimer];
    [self dismissPresentedViewControllerIfNecessary];
    [self saveLastVisibleSortIdAndOnScreenPercentage];

    [self dismissKeyBoard];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self startReadTimer];
}

- (void)dismissPresentedViewControllerIfNecessary
{
    UIViewController *_Nullable presentedViewController = self.presentedViewController;
    if (!presentedViewController) {
        OWSLogDebug(@"presentedViewController was nil");
        return;
    }

    if ([presentedViewController isKindOfClass:[ActionSheetController class]] ||
        [presentedViewController isKindOfClass:[UIAlertController class]]) {
        OWSLogDebug(@"dismissing presentedViewController: %@", presentedViewController);
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    OWSLogDebug(@"viewWillAppear");

    [self ensureBannerState];

    [super viewWillAppear:animated];

    // We need to recheck on every appearance, since the user may have left the group in the settings VC,
    // or on another device.
    [self updateInputVisibility];

    self.isViewVisible = YES;
    self.hasViewWillAppearOccurred = YES;

    // We should have already requested contact access at this point, so this should be a no-op
    // unless it ever becomes possible to load this VC without going via the ConversationListViewController.
    [self.contactsManager requestSystemContactsOnce];

    [self updateBarButtonItems];
    [self updateNavigationTitle];

    [self resetContentAndLayoutWithSneakyTransaction];

    // One-time work performed the first time we enter the view.
    if (!self.viewHasEverAppeared) {
        [self loadDraftInCompose];
        [self scrollToDefaultPositionAnimated:NO];
    }

    if (!self.viewHasEverAppeared) {
        [BenchManager
            completeEventWithEventId:[NSString stringWithFormat:@"presenting-conversation-%@", self.thread.uniqueId]];
    }
    [self reloadBottomBar];
    [self updateInputToolbarLayout];

    // There are cases where we don't have a navigation controller, such as if we got here through 3d touch.
    // Make sure we only register the gesture interaction if it actually exists. This helps the swipe back
    // gesture work reliably without conflict with scrolling.
    if (self.navigationController) {
        [self.collectionView.panGestureRecognizer
            requireGestureRecognizerToFail:self.navigationController.interactivePopGestureRecognizer];
    }

    [self showMessageRequestDialogIfRequired];
}

- (void)resetContentAndLayoutWithSneakyTransaction
{
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        [self resetContentAndLayoutWithTransaction:transaction];
    }];
}

- (void)resetContentAndLayoutWithTransaction:(SDSAnyReadTransaction *)transaction
{
    self.scrollContinuity = kScrollContinuityBottom;
    // Avoid layout corrupt issues and out-of-date message subtitles.
    self.lastReloadDate = [NSDate new];
    [self.conversationViewModel viewDidResetContentAndLayoutWithTransaction:transaction];
    [self reloadData];

    if (self.viewHasEverAppeared) {
        // Try to update the lastKnownDistanceFromBottom; the content size may have changed.
        [self updateLastKnownDistanceFromBottom];
    }

    if (self.isShowingSelectionUI) {
        [self maintainSelectionAfterMappingChange];
        [self updateSelectionHighlight];
    }
}

- (void)setUserHasScrolled:(BOOL)userHasScrolled
{
    _userHasScrolled = userHasScrolled;

    [self ensureBannerState];
}

// Returns a collection of the group members who are "no longer verified".
- (NSArray<SignalServiceAddress *> *)noLongerVerifiedAddresses
{
    NSMutableArray<SignalServiceAddress *> *result = [NSMutableArray new];
    for (SignalServiceAddress *address in self.thread.recipientAddresses) {
        if ([[OWSIdentityManager shared] verificationStateForAddress:address] == OWSVerificationStateNoLongerVerified) {
            [result addObject:address];
        }
    }
    return [result copy];
}

- (void)ensureBannerState
{
    // This method should be called rarely, so it's simplest to discard and
    // rebuild the indicator view every time.
    [self.bannerView removeFromSuperview];
    self.bannerView = nil;

    if (self.userHasScrolled) {
        return;
    }

    NSMutableArray<UIView *> *banners = [NSMutableArray new];

    NSArray<SignalServiceAddress *> *noLongerVerifiedAddresses = [self noLongerVerifiedAddresses];

    if (noLongerVerifiedAddresses.count > 0) {
        NSString *message;
        if (noLongerVerifiedAddresses.count > 1) {
            message = NSLocalizedString(@"MESSAGES_VIEW_N_MEMBERS_NO_LONGER_VERIFIED",
                @"Indicates that more than one member of this group conversation is no longer verified.");
        } else {
            SignalServiceAddress *address = [noLongerVerifiedAddresses firstObject];
            NSString *displayName = [self.contactsManager displayNameForAddress:address];
            NSString *format
                = (self.isGroupConversation ? NSLocalizedString(@"MESSAGES_VIEW_1_MEMBER_NO_LONGER_VERIFIED_FORMAT",
                       @"Indicates that one member of this group conversation is no longer "
                       @"verified. Embeds {{user's name or phone number}}.")
                                            : NSLocalizedString(@"MESSAGES_VIEW_CONTACT_NO_LONGER_VERIFIED_FORMAT",
                                                @"Indicates that this 1:1 conversation is no longer verified. Embeds "
                                                @"{{user's name or phone number}}."));
            message = [NSString stringWithFormat:format, displayName];
        }

        [banners addObject:[self createBannerWithTitle:message
                                           bannerColor:UIColor.ows_accentRedColor
                                           tapSelector:@selector(noLongerVerifiedBannerViewWasTapped:)]];
    }

    NSString *blockStateMessage = nil;
    if (self.isGroupConversation) {
        int blockedGroupMemberCount = [self blockedGroupMemberCount];
        if (blockedGroupMemberCount == 1) {
            blockStateMessage = NSLocalizedString(@"MESSAGES_VIEW_GROUP_1_MEMBER_BLOCKED",
                @"Indicates that a single member of this group has been blocked.");
        } else if (blockedGroupMemberCount > 1) {
            blockStateMessage =
                [NSString stringWithFormat:NSLocalizedString(@"MESSAGES_VIEW_GROUP_N_MEMBERS_BLOCKED_FORMAT",
                                               @"Indicates that some members of this group has been blocked. Embeds "
                                               @"{{the number of blocked users in this group}}."),
                          [OWSFormat formatInt:blockedGroupMemberCount]];
        }
    }

    if (blockStateMessage) {
        [banners addObject:[self createBannerWithTitle:blockStateMessage
                                           bannerColor:UIColor.ows_accentRedColor
                                           tapSelector:@selector(blockBannerViewWasTapped:)]];
    }

    NSUInteger pendingMemberRequestCount = self.pendingMemberRequestCount;
    if (pendingMemberRequestCount > 0 && self.canApprovePendingMemberRequests) {
        [banners addObject:[self createPendingJoinReuqestBannerWithCount:pendingMemberRequestCount]];
    }

    if (banners.count < 1) {
        return;
    }

    UIStackView *bannerView = [[UIStackView alloc] initWithArrangedSubviews:banners];
    bannerView.axis = UILayoutConstraintAxisVertical;
    bannerView.alignment = UIStackViewAlignmentFill;
    [self.view addSubview:bannerView];
    [bannerView autoPinToTopLayoutGuideOfViewController:self withInset:0];
    [bannerView autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [bannerView autoPinEdgeToSuperviewEdge:ALEdgeTrailing];

    UIView *bannerShadow = [UIView new];
    bannerShadow.backgroundColor = Theme.backgroundColor;
    // Use a shadow to "pop" the indicator above the other views.
    bannerShadow.layer.shadowColor = [UIColor blackColor].CGColor;
    bannerShadow.layer.shadowOffset = CGSizeMake(0, 4);
    bannerShadow.layer.shadowRadius = 4.f;
    bannerShadow.layer.shadowOpacity = 0.15f;
    [bannerShadow addRedBorder];
    [bannerView addSubview:bannerShadow];
    [bannerShadow autoPinEdgesToSuperviewEdges];
    [bannerView sendSubviewToBack:bannerShadow];

    [self.view layoutSubviews];

    self.bannerView = bannerView;
}

- (NSUInteger)pendingMemberRequestCount
{
    if ([self.thread isKindOfClass:[TSGroupThread class]]) {
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        return groupThread.groupMembership.requestingMembers.count;
    } else {
        return 0;
    }
}

- (BOOL)canApprovePendingMemberRequests
{
    if ([self.thread isKindOfClass:[TSGroupThread class]]) {
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        return groupThread.isLocalUserFullMemberAndAdministrator;
    } else {
        return NO;
    }
}

- (UIView *)createBannerWithTitle:(NSString *)title bannerColor:(UIColor *)bannerColor tapSelector:(SEL)tapSelector
{
    OWSAssertDebug(title.length > 0);
    OWSAssertDebug(bannerColor);

    UIView *bannerView = [UIView containerView];
    bannerView.backgroundColor = bannerColor;

    UILabel *label = [self buildBannerLabel:title];
    label.textAlignment = NSTextAlignmentCenter;

    UIImage *closeIcon = [UIImage imageNamed:@"banner_close"];
    UIImageView *closeButton = [[UIImageView alloc] initWithImage:closeIcon];
    [bannerView addSubview:closeButton];
    const CGFloat kBannerCloseButtonPadding = 8.f;
    [closeButton autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:kBannerCloseButtonPadding];
    [closeButton autoPinTrailingToSuperviewMarginWithInset:kBannerCloseButtonPadding];
    [closeButton autoSetDimension:ALDimensionWidth toSize:closeIcon.size.width];
    [closeButton autoSetDimension:ALDimensionHeight toSize:closeIcon.size.height];

    [bannerView addSubview:label];
    [label autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:5];
    [label autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:5];
    const CGFloat kBannerHPadding = 15.f;
    [label autoPinLeadingToSuperviewMarginWithInset:kBannerHPadding];
    const CGFloat kBannerHSpacing = 10.f;
    [closeButton autoPinLeadingToTrailingEdgeOfView:label offset:kBannerHSpacing];

    [bannerView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:tapSelector]];
    bannerView.accessibilityIdentifier = ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"banner_close");

    return bannerView;
}

- (UILabel *)buildBannerLabel:(NSString *)title
{
    UILabel *label = [UILabel new];
    label.font = [UIFont ows_dynamicTypeSubheadlineClampedFont].ows_semibold;
    label.text = title;
    label.textColor = [UIColor whiteColor];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    return label;
}

- (UIView *)createPendingJoinReuqestBannerWithCount:(NSUInteger)pendingMemberRequestCount
{
    OWSAssertDebug(pendingMemberRequestCount > 0);

    NSString *format = NSLocalizedString(@"PENDING_GROUP_MEMBERS_REQUEST_BANNER_FORMAT",
        @"Format for banner indicating that there are pending member requests to join the group. Embeds {{ the number "
        @"of pending member requests }}.");
    NSString *title = [NSString stringWithFormat:format, [OWSFormat formatUInt:pendingMemberRequestCount]];
    UILabel *label = [self buildBannerLabel:title];
    label.font = [UIFont ows_dynamicTypeSubheadlineClampedFont];

    __weak ConversationViewController *weakSelf = self;
    OWSButton *dismissButton = [[OWSButton alloc] initWithTitle:CommonStrings.dismissButton
                                                          block:^{ [weakSelf hidePendingMemberRequests]; }];
    dismissButton.titleLabel.font = [UIFont ows_dynamicTypeSubheadlineClampedFont].ows_semibold;
    NSString *viewRequestsLabel = NSLocalizedString(@"PENDING_GROUP_MEMBERS_REQUEST_BANNER_VIEW_REQUESTS",
        @"Label for the 'view requests' button in the pending member requests banner.");
    OWSButton *viewRequestsButton = [[OWSButton alloc] initWithTitle:viewRequestsLabel
                                                               block:^{ [weakSelf viewMemberRequests]; }];
    viewRequestsButton.titleLabel.font = [UIFont ows_dynamicTypeSubheadlineClampedFont].ows_semibold;

    UIStackView *buttonRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        [UIView hStretchingSpacer],
        dismissButton,
        viewRequestsButton,
    ]];
    buttonRow.axis = UILayoutConstraintAxisHorizontal;
    buttonRow.spacing = 24;

    UIStackView *bannerView = [[UIStackView alloc] initWithArrangedSubviews:@[
        label,
        buttonRow,
    ]];
    bannerView.axis = UILayoutConstraintAxisVertical;
    bannerView.alignment = UIStackViewAlignmentFill;
    bannerView.spacing = 10;
    bannerView.layoutMargins = UIEdgeInsetsMake(14, 16, 14, 16);
    [bannerView setLayoutMarginsRelativeArrangement:YES];
    [bannerView addBackgroundViewWithBackgroundColor:UIColor.ows_accentBlueColor];
    bannerView.accessibilityIdentifier = ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"pending_group_request_banner");

    return bannerView;
}

- (void)hidePendingMemberRequests
{
}

- (void)viewMemberRequests
{
    [self showConversationSettingsAndShowMemberRequests];
}

- (void)blockBannerViewWasTapped:(UIGestureRecognizer *)sender
{
    if (sender.state != UIGestureRecognizerStateRecognized) {
        return;
    }

    if ([self isBlockedConversation]) {
        // If this a blocked conversation, offer to unblock.
        [self showUnblockConversationUI:nil];
    } else if (self.isGroupConversation) {
        // If this a group conversation with at least one blocked member,
        // Show the block list view.
        int blockedGroupMemberCount = [self blockedGroupMemberCount];
        if (blockedGroupMemberCount > 0) {
            BlockListViewController *vc = [[BlockListViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
    }
}

- (void)noLongerVerifiedBannerViewWasTapped:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        NSArray<SignalServiceAddress *> *noLongerVerifiedAddresses = [self noLongerVerifiedAddresses];
        if (noLongerVerifiedAddresses.count < 1) {
            return;
        }
        BOOL hasMultiple = noLongerVerifiedAddresses.count > 1;

        ActionSheetController *actionSheet = [[ActionSheetController alloc] initWithTitle:nil message:nil];

        __weak ConversationViewController *weakSelf = self;
        ActionSheetAction *verifyAction = [[ActionSheetAction alloc]
            initWithTitle:(hasMultiple ? NSLocalizedString(@"VERIFY_PRIVACY_MULTIPLE",
                               @"Label for button or row which allows users to verify the safety "
                               @"numbers of multiple users.")
                                       : NSLocalizedString(@"VERIFY_PRIVACY",
                                           @"Label for button or row which allows users to verify the safety "
                                           @"number of another user."))
                    style:ActionSheetActionStyleDefault
                  handler:^(ActionSheetAction *action) {
                      [weakSelf showNoLongerVerifiedUI];
                  }];
        [actionSheet addAction:verifyAction];

        ActionSheetAction *dismissAction =
            [[ActionSheetAction alloc] initWithTitle:CommonStrings.dismissButton
                             accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"dismiss")
                                               style:ActionSheetActionStyleCancel
                                             handler:^(ActionSheetAction *action) {
                                                 [weakSelf resetVerificationStateToDefault];
                                             }];
        [actionSheet addAction:dismissAction];

        [self dismissKeyBoard];
        [self presentActionSheet:actionSheet];
    }
}

- (void)resetVerificationStateToDefault
{
    OWSAssertIsOnMainThread();

    NSArray<SignalServiceAddress *> *noLongerVerifiedAddresses = [self noLongerVerifiedAddresses];
    for (SignalServiceAddress *address in noLongerVerifiedAddresses) {
        OWSAssertDebug(address.isValid);

        OWSRecipientIdentity *_Nullable recipientIdentity =
            [[OWSIdentityManager shared] recipientIdentityForAddress:address];
        OWSAssertDebug(recipientIdentity);

        NSData *identityKey = recipientIdentity.identityKey;
        OWSAssertDebug(identityKey.length > 0);
        if (identityKey.length < 1) {
            continue;
        }

        [OWSIdentityManager.shared setVerificationState:OWSVerificationStateDefault
                                            identityKey:identityKey
                                                address:address
                                  isUserInitiatedChange:YES];
    }
}

- (void)showUnblockConversationUI:(nullable BlockActionCompletionBlock)completionBlock
{
    self.userHasScrolled = NO;

    // To avoid "noisy" animations (hiding the keyboard before showing
    // the action sheet, re-showing it after), hide the keyboard before
    // showing the "unblock" action sheet.
    //
    // Unblocking is a rare interaction, so it's okay to leave the keyboard
    // hidden.
    [self dismissKeyBoard];

    [BlockListUIUtils showUnblockThreadActionSheet:self.thread
                                fromViewController:self
                                   completionBlock:completionBlock];
}

- (BOOL)isBlockedConversation
{
    return [self.blockingManager isThreadBlocked:self.thread];
}

- (int)blockedGroupMemberCount
{
    OWSAssertDebug(self.isGroupConversation);
    OWSAssertDebug([self.thread isKindOfClass:[TSGroupThread class]]);

    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    int blockedMemberCount = 0;
    for (SignalServiceAddress *address in groupThread.groupModel.groupMembers) {
        if ([self.blockingManager isAddressBlocked:address]) {
            blockedMemberCount++;
        }
    }
    return blockedMemberCount;
}

- (void)startReadTimer
{
    [self.readTimer invalidate];
    self.readTimer = [NSTimer weakTimerWithTimeInterval:0.1f
                                                 target:self
                                               selector:@selector(readTimerDidFire)
                                               userInfo:nil
                                                repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.readTimer forMode:NSRunLoopCommonModes];
}

- (void)readTimerDidFire
{
    [self markVisibleMessagesAsRead];
}

- (void)cancelReadTimer
{
    [self.readTimer invalidate];
    self.readTimer = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // We don't present incoming message notifications for the presented
    // conversation. But there's a narrow window *while* the conversationVC
    // is being presented where a message notification for the not-quite-yet
    // presented conversation can be shown. If that happens, dismiss it as soon
    // as we enter the conversation.
    [self.notificationPresenter cancelNotificationsWithThreadId:self.thread.uniqueId];

    // recover status bar when returning from PhotoPicker, which is dark (uses light status bar)
    [self setNeedsStatusBarAppearanceUpdate];

    [self.bulkProfileFetch fetchProfilesWithThread:self.thread];
    [self markVisibleMessagesAsRead];
    [self startReadTimer];
    [self updateNavigationBarSubtitleLabel];
    [self autoLoadMoreIfNecessary];

    if (!self.viewHasEverAppeared) {
        // To minimize time to initial apearance, we initially disable prefetching, but then
        // re-enable it once the view has appeared.
        self.collectionView.prefetchingEnabled = YES;
    }

    self.conversationViewModel.focusMessageIdOnOpen = nil;

    self.isViewCompletelyAppeared = YES;
    self.viewHasEverAppeared = YES;
    self.shouldAnimateKeyboardChanges = YES;

    switch (self.actionOnOpen) {
        case ConversationViewActionNone:
            break;
        case ConversationViewActionCompose:
            // Don't pop the keyboard if we have a pending message request, since
            // the user can't currently send a message until acting on this
            if (!self.requestView) {
                [self popKeyBoard];
            }

            // When we programmatically pop the keyboard here,
            // the scroll position gets into a weird state and
            // content is hidden behind the keyboard so we restore
            // it to the default position.
            [self scrollToDefaultPositionAnimated:YES];
            break;
        case ConversationViewActionAudioCall:
            [self startIndividualAudioCall];
            break;
        case ConversationViewActionVideoCall:
            [self startIndividualVideoCall];
            break;
    }

    // Clear the "on open" state after the view has been presented.
    self.actionOnOpen = ConversationViewActionNone;

    [self updateInputToolbarLayout];
    [self configureScrollDownButtons];
    [self.inputToolbar viewDidAppear];
}

// `viewWillDisappear` is called whenever the view *starts* to disappear,
// but, as is the case with the "pan left for message details view" gesture,
// this can be canceled. As such, we shouldn't tear down anything expensive
// until `viewDidDisappear`.
- (void)viewWillDisappear:(BOOL)animated
{
    OWSLogDebug(@"");

    [super viewWillDisappear:animated];

    self.isViewCompletelyAppeared = NO;

    [self dismissMessageActionsAnimated:NO];
    [self dismissReactionsDetailSheetAnimated:NO];
}

- (void)viewDidDisappear:(BOOL)animated
{
    OWSLogDebug(@"");

    [super viewDidDisappear:animated];
    self.userHasScrolled = NO;
    self.isViewVisible = NO;
    self.shouldAnimateKeyboardChanges = NO;

    [self.audioAttachmentPlayer stop];
    self.audioAttachmentPlayer = nil;

    [self cancelReadTimer];
    [self saveDraft];
    [self markVisibleMessagesAsRead];
    [self cancelVoiceMemo];
    [self.cellMediaCache removeAllObjects];
    [self.inputToolbar clearDesiredKeyboard];

    self.isUserScrolling = NO;
    self.isWaitingForDeceleration = NO;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    // We resize the inputToolbar whenever it's text is modified, including when setting saved draft-text.
    // However it's possible this draft-text is set before the inputToolbar (an inputAccessoryView) is mounted
    // in the view hierarchy. Since it's not in the view hierarchy, it hasn't been laid out and has no width,
    // which is used to determine height.
    // So here we unsure the proper height once we know everything's been layed out.
    [self.inputToolbar ensureTextViewHeight];
}

#pragma mark - Initiliazers

- (void)updateNavigationTitle
{
    NSString *_Nullable name;
    NSAttributedString *_Nullable attributedName;
    UIImage *_Nullable icon;
    if ([self.thread isKindOfClass:[TSContactThread class]]) {
        TSContactThread *thread = (TSContactThread *)self.thread;

        OWSAssertDebug(thread.contactAddress);

        if (thread.isNoteToSelf) {
            name = MessageStrings.noteToSelf;
        } else {
            name = [self.contactsManager displayNameForAddress:thread.contactAddress];
        }

        // If the user is in the system contacts, show a badge
        if ([self.contactsManager hasSignalAccountForAddress:thread.contactAddress]) {
            icon =
                [[UIImage imageNamed:@"contact-outline-16"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    } else if ([self.thread isKindOfClass:TSGroupThread.class]) {
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        name = groupThread.groupNameOrDefault;
    } else {
        OWSFailDebug(@"failure: unexpected thread: %@", self.thread);
    }
    self.title = nil;

    self.headerView.titleIcon = icon;

    if (name && !attributedName) {
        attributedName =
            [[NSAttributedString alloc] initWithString:name
                                            attributes:@{ NSForegroundColorAttributeName : Theme.primaryTextColor }];
    }

    if ([attributedName isEqual:self.headerView.attributedTitle]) {
        return;
    }

    self.headerView.attributedTitle = attributedName;
}

- (void)createHeaderViews
{
    ConversationHeaderView *headerView = [[ConversationHeaderView alloc] initWithThread:self.thread];
    headerView.accessibilityLabel = NSLocalizedString(@"CONVERSATION_SETTINGS", "title for conversation settings screen");
    self.headerView = headerView;
    SET_SUBVIEW_ACCESSIBILITY_IDENTIFIER(self, headerView);

    headerView.delegate = self;
    self.navigationItem.titleView = headerView;

#ifdef USE_DEBUG_UI
    [headerView addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
                                         initWithTarget:self
                                                 action:@selector(navigationTitleLongPressed:)]];
#endif


    [self updateNavigationBarSubtitleLabel];
}

- (CGFloat)unreadCountViewDiameter
{
    return 16;
}

- (void)updateLeftBarItem
{
    // No left button when the view is not collapsed, there's nowhere to go.
    if (!self.conversationSplitViewController.isCollapsed) {
        self.navigationItem.leftBarButtonItem = nil;
        return;
    }

    // Otherwise, show the back button.

    // We use the default back button from conversation list, which animates nicely with interactive transitions
    // like the interactive pop gesture and the "slide left" for info.
    self.navigationItem.leftBarButtonItem = nil;
}

- (void)windowManagerCallDidChange:(NSNotification *)notification
{
    [self updateBarButtonItems];
}

- (void)updateBarButtonItems
{
    // Don't include "Back" text on view controllers pushed above us, just use the arrow.
    [self.navigationItem setBackBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:@""
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:nil
                                                                              action:nil]];

    self.navigationItem.hidesBackButton = NO;
    self.navigationItem.leftBarButtonItem = nil;

    switch (self.uiMode) {
        case ConversationUIMode_Search: {
            if (self.userLeftGroup) {
                self.navigationItem.rightBarButtonItems = @[];
                return;
            }
            if (@available(iOS 13.0, *)) {
                OWSAssertDebug(self.navigationItem.searchController != nil);
            } else {
                self.navigationItem.rightBarButtonItems = @[];
                self.navigationItem.leftBarButtonItem = nil;
                self.navigationItem.hidesBackButton = YES;
            }
            return;
        }
        case ConversationUIMode_Selection: {
            self.navigationItem.rightBarButtonItems = @[ self.cancelSelectionBarButtonItem ];
            self.navigationItem.leftBarButtonItem = self.deleteAllBarButtonItem;
            self.navigationItem.hidesBackButton = YES;
            return;
        }
        case ConversationUIMode_Normal: {
            if (self.userLeftGroup) {
                self.navigationItem.rightBarButtonItems = @[];
                return;
            }
            NSMutableArray<UIBarButtonItem *> *barButtons = [NSMutableArray new];
            if ([self canCall]) {
                if (self.isGroupConversation) {
                    // TODO: Show different state if the group call is started.
                    UIBarButtonItem *videoCallButton =
                        [[UIBarButtonItem alloc] initWithImage:[Theme iconImage:ThemeIconVideoCall]
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(showGroupCallLobby)];
                    videoCallButton.enabled = !OWSWindowManager.shared.hasCall;
                    videoCallButton.accessibilityLabel
                        = NSLocalizedString(@"VIDEO_CALL_LABEL", "Accessibility label for placing a video call");
                    [barButtons addObject:videoCallButton];
                } else {
                    UIBarButtonItem *audioCallButton =
                        [[UIBarButtonItem alloc] initWithImage:[Theme iconImage:ThemeIconAudioCall]
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(startIndividualAudioCall)];
                    audioCallButton.enabled = !OWSWindowManager.shared.hasCall;
                    audioCallButton.accessibilityLabel
                        = NSLocalizedString(@"AUDIO_CALL_LABEL", "Accessibility label for placing an audio call");
                    [barButtons addObject:audioCallButton];

                    UIBarButtonItem *videoCallButton =
                        [[UIBarButtonItem alloc] initWithImage:[Theme iconImage:ThemeIconVideoCall]
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(startIndividualVideoCall)];
                    videoCallButton.enabled = !OWSWindowManager.shared.hasCall;
                    videoCallButton.accessibilityLabel
                        = NSLocalizedString(@"VIDEO_CALL_LABEL", "Accessibility label for placing a video call");
                    [barButtons addObject:videoCallButton];
                }
            }

            self.navigationItem.rightBarButtonItems = [barButtons copy];
            return;
        }
    }
}

- (void)updateNavigationBarSubtitleLabel
{
    BOOL hasCompactHeader = self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact;
    if (hasCompactHeader) {
        self.headerView.attributedSubtitle = nil;
        return;
    }

    NSMutableAttributedString *subtitleText = [NSMutableAttributedString new];
    UIFont *subtitleFont = self.headerView.subtitleFont;
    NSDictionary *attributes = @{
        NSFontAttributeName : subtitleFont,
        NSForegroundColorAttributeName : [Theme.navbarTitleColor colorWithAlphaComponent:(CGFloat)0.9],
    };
    NSString *hairSpace = @"\u200a";
    NSString *thinSpace = @"\u2009";
    NSString *iconSpacer = UIDevice.currentDevice.isNarrowerThanIPhone6 ? hairSpace : thinSpace;
    NSString *betweenItemSpacer = UIDevice.currentDevice.isNarrowerThanIPhone6 ? @" " : @"  ";

    BOOL isMuted = self.thread.isMuted;
    BOOL hasTimer = self.disappearingMessagesConfiguration.isEnabled;
    BOOL isVerified = self.thread.recipientAddresses.count > 0;
    for (SignalServiceAddress *address in self.thread.recipientAddresses) {
        if ([[OWSIdentityManager shared] verificationStateForAddress:address] != OWSVerificationStateVerified) {
            isVerified = NO;
            break;
        }
    }

    if (isMuted) {
        [subtitleText appendTemplatedImageNamed:@"bell-disabled-outline-24" font:subtitleFont];
        if (!isVerified) {
            [subtitleText append:iconSpacer attributes:attributes];
            [subtitleText append:NSLocalizedString(@"MUTED_BADGE", @"Badge indicating that the user is muted.")
                      attributes:attributes];
        }
    }

    if (hasTimer) {
        if (isMuted) {
            [subtitleText append:betweenItemSpacer attributes:attributes];
        }

        [subtitleText appendTemplatedImageNamed:@"timer-outline-16" font:subtitleFont];
        [subtitleText append:iconSpacer attributes:attributes];
        [subtitleText append:[NSString formatDurationSeconds:self.disappearingMessagesConfiguration.durationSeconds
                                              useShortFormat:YES]
                  attributes:attributes];
    }

    if (isVerified) {
        if (hasTimer || isMuted) {
            [subtitleText append:betweenItemSpacer attributes:attributes];
        }

        [subtitleText appendTemplatedImageNamed:@"check-12" font:subtitleFont];
        [subtitleText append:iconSpacer attributes:attributes];
        [subtitleText append:NSLocalizedString(
                                 @"PRIVACY_IDENTITY_IS_VERIFIED_BADGE", @"Badge indicating that the user is verified.")
                  attributes:attributes];
    }

    self.headerView.attributedSubtitle = subtitleText;
}


#pragma mark - Identity

/**
 * Shows confirmation dialog if at least one of the recipient id's is not confirmed.
 *
 * returns YES if an alert was shown
 *          NO if there were no unconfirmed identities
 */
- (BOOL)showSafetyNumberConfirmationIfNecessaryWithConfirmationText:(NSString *)confirmationText
                                                         completion:(void (^)(BOOL didConfirmIdentity))completionHandler
{
    return [SafetyNumberConfirmationSheet presentIfNecessaryWithAddresses:self.thread.recipientAddresses
                                                         confirmationText:confirmationText
                                                               completion:completionHandler];
}

- (void)showFingerprintWithAddress:(SignalServiceAddress *)address
{
    // Ensure keyboard isn't hiding the "safety numbers changed" interaction when we
    // return from FingerprintViewController.
    [self dismissKeyBoard];

    [FingerprintViewController presentFromViewController:self address:address];
}

#pragma mark - Calls

- (void)showGroupCallLobby
{
    if (!self.isGroupConversation) {
        OWSFailDebug(@"Tried to present group call for non-group thread.");
        return;
    }

    if (!self.canCall) {
        OWSFailDebug(@"Tried to initiate a call but thread is not callable.");
        return;
    }

    // We initiated a call, so if there was a pending message request we should accept it.
    [ThreadUtil addThreadToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction:self.thread];

    [GroupCallViewController presentLobbyForThread:(TSGroupThread *)self.thread];
}

- (void)startIndividualAudioCall
{
    [self individualCallWithVideo:NO];
}

- (void)startIndividualVideoCall
{
    [self individualCallWithVideo:YES];
}

- (void)individualCallWithVideo:(BOOL)isVideo
{
    if (![self.thread isKindOfClass:[TSContactThread class]]) {
        OWSFailDebug(@"unexpected thread: %@", self.thread);
        return;
    }
    TSContactThread *contactThread = (TSContactThread *)self.thread;

    if (![self canCall]) {
        OWSLogWarn(@"Tried to initiate a call but thread is not callable.");
        return;
    }

    __weak ConversationViewController *weakSelf = self;
    if ([self isBlockedConversation]) {
        [self showUnblockConversationUI:^(BOOL isBlocked) {
            if (!isBlocked) {
                [weakSelf individualCallWithVideo:isVideo];
            }
        }];
        return;
    }

    BOOL didShowSNAlert =
        [self showSafetyNumberConfirmationIfNecessaryWithConfirmationText:[CallStrings confirmAndCallButtonTitle]
                                                               completion:^(BOOL didConfirmIdentity) {
                                                                   if (didConfirmIdentity) {
                                                                       [weakSelf individualCallWithVideo:isVideo];
                                                                   }
                                                               }];
    if (didShowSNAlert) {
        return;
    }

    // We initiated a call, so if there was a pending message request we should accept it.
    [ThreadUtil addThreadToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction:self.thread];

    [self.outboundIndividualCallInitiator initiateCallWithAddress:contactThread.contactAddress isVideo:isVideo];
}

- (BOOL)canCall
{
    if (!self.thread.isLocalUserFullMemberOfThread) {
        return NO;
    }

    if (![self.thread isKindOfClass:[TSContactThread class]]) {
        return SSKFeatureFlags.groupCalling && self.thread.isGroupV2Thread;
    }

    TSContactThread *contactThread = (TSContactThread *)self.thread;
    if (contactThread.isNoteToSelf) {
        return NO;
    }

    if (self.threadViewModel.hasPendingMessageRequest) {
        return NO;
    }

    return YES;
}

#pragma mark - Dynamic Text

/**
 Called whenever the user manually changes the dynamic type options inside Settings.

 @param notification NSNotification with the dynamic type change information.
 */
- (void)didChangePreferredContentSize:(NSNotification *)notification
{
    OWSLogInfo(@"didChangePreferredContentSize");

    [self resetForSizeOrOrientationChange];

    [self.inputToolbar updateFontSizes];
}

#pragma mark - Actions

- (void)showNoLongerVerifiedUI
{
    NSArray<SignalServiceAddress *> *noLongerVerifiedAddresses = [self noLongerVerifiedAddresses];
    if (noLongerVerifiedAddresses.count > 1) {
        [self showConversationSettingsAndShowVerification];
    } else if (noLongerVerifiedAddresses.count == 1) {
        // Pick one in an arbitrary but deterministic manner.
        SignalServiceAddress *address = noLongerVerifiedAddresses.lastObject;
        [self showFingerprintWithAddress:address];
    }
}

- (void)showConversationSettings
{
    [self showConversationSettingsWithMode:ConversationSettingsPresentationModeDefault];
}

- (void)showConversationSettingsAndShowAllMedia
{
    [self showConversationSettingsWithMode:ConversationSettingsPresentationModeShowAllMedia];
}

- (void)showConversationSettingsAndShowVerification
{
    [self showConversationSettingsWithMode:ConversationSettingsPresentationModeShowVerification];
}

- (void)showConversationSettingsAndShowMemberRequests
{
    [self showConversationSettingsWithMode:ConversationSettingsPresentationModeShowMemberRequests];
}

- (void)showConversationSettingsWithMode:(ConversationSettingsPresentationMode)mode
{
    NSMutableArray<UIViewController *> *viewControllers = [self.viewControllersUpToSelf mutableCopy];

    ConversationSettingsViewController *settingsView =
        [[ConversationSettingsViewController alloc] initWithThreadViewModel:self.threadViewModel];
    settingsView.conversationSettingsViewDelegate = self;
    [viewControllers addObject:settingsView];

    switch (mode) {
        case ConversationSettingsPresentationModeDefault:
            break;
        case ConversationSettingsPresentationModeShowVerification:
            settingsView.showVerificationOnAppear = YES;
            break;
        case ConversationSettingsPresentationModeShowMemberRequests: {
            UIViewController *_Nullable view = [settingsView buildMemberRequestsAndInvitesView];
            if (view != nil) {
                [viewControllers addObject:view];
            }
            break;
        }
        case ConversationSettingsPresentationModeShowAllMedia:
            [viewControllers addObject:[[MediaTileViewController alloc] initWithThread:self.thread]];
            break;
    }

    [self.navigationController setViewControllers:viewControllers animated:YES];
}

- (NSArray<UIViewController *> *)viewControllersUpToSelf
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.navigationController);

    if (self.navigationController.topViewController == self) {
        return self.navigationController.viewControllers;
    }

    NSArray *viewControllers = self.navigationController.viewControllers;
    NSUInteger index = [viewControllers indexOfObject:self];

    if (index == NSNotFound) {
        OWSFailDebug(@"Unexpectedly missing from view hierarhy");
        return viewControllers;
    }

    return [viewControllers subarrayWithRange:NSMakeRange(0, index + 1)];
}

#pragma mark - Load More

- (void)autoLoadMoreIfNecessary
{
    BOOL isMainAppAndActive = CurrentAppContext().isMainAppAndActive;
    if (self.isUserScrolling || self.isWaitingForDeceleration || !self.isViewVisible || !isMainAppAndActive) {
        return;
    }
    if (!self.showLoadOlderHeader && !self.showLoadNewerHeader) {
        return;
    }
    [self.navigationController.view layoutIfNeeded];
    CGSize navControllerSize = self.navigationController.view.frame.size;
    CGFloat loadThreshold = MAX(navControllerSize.width, navControllerSize.height) * 3;

    BOOL closeToTop = self.collectionView.contentOffset.y < loadThreshold;
    if (self.showLoadOlderHeader && closeToTop) {
        [BenchManager benchWithTitle:@"loading older interactions"
                               block:^{
                                   [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
                                       [self.conversationViewModel appendOlderItemsWithTransaction:transaction];
                                   }];
                               }];
    }

    CGFloat distanceFromBottom = self.collectionView.contentSize.height - self.collectionView.bounds.size.height
        - self.collectionView.contentOffset.y;
    BOOL closeToBottom = distanceFromBottom < loadThreshold;
    if (self.showLoadNewerHeader && closeToBottom) {
        [BenchManager benchWithTitle:@"loading newer interactions"
                               block:^{
                                   [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
                                       [self.conversationViewModel appendNewerItemsWithTransaction:transaction];
                                   }];
                               }];
    }
}

- (void)resetShowLoadMore
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.conversationViewModel);

    _showLoadOlderHeader = self.conversationViewModel.canLoadOlderItems;
    _showLoadNewerHeader = self.conversationViewModel.canLoadNewerItems;
}

- (void)updateShowLoadMoreHeadersWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.conversationViewModel);

    BOOL valueChanged = NO;

    {
        BOOL newValue = self.conversationViewModel.canLoadOlderItems;
        valueChanged = _showLoadOlderHeader != newValue;

        _showLoadOlderHeader = newValue;
    }

    {
        BOOL newValue = self.conversationViewModel.canLoadNewerItems;
        valueChanged = valueChanged || (_showLoadNewerHeader != newValue);

        _showLoadNewerHeader = newValue;
    }

    if (valueChanged) {
        [self resetContentAndLayoutWithTransaction:transaction];
    }
}

#pragma mark Bubble User Actions

- (void)handleFailedDownloadTapForMessage:(TSMessage *)message
{
    OWSAssert(message);

    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        NSArray<TSAttachment *> *attachments = [message allAttachmentsWithTransaction:transaction.unwrapGrdbRead];
        [self.attachmentDownloads downloadAttachmentsForMessage:message
            bypassPendingMessageRequest:NO
            attachments:attachments
            success:^(NSArray<TSAttachmentStream *> *attachmentStreams) {
                OWSLogInfo(@"Successfully redownloaded attachment in thread: %@", message.threadWithSneakyTransaction);
            }
            failure:^(NSError *error) { OWSLogWarn(@"Failed to redownload message with error: %@", error); }];
    }];
}

- (void)resendFailedOutgoingMessage:(TSOutgoingMessage *)message
{
    TSOutgoingMessage *messageToSend;

    // If the message was remotely deleted, resend a *delete* message
    // rather than the message itself.
    if (message.wasRemotelyDeleted) {
        messageToSend = [[TSOutgoingDeleteMessage alloc] initWithThread:self.thread message:message];
    } else {
        messageToSend = message;
    }

    NSArray<SignalServiceAddress *> *recipientsWithChangedSafetyNumber =
        [message failedRecipientAddressesWithErrorCode:OWSErrorCodeUntrustedIdentity];
    if (recipientsWithChangedSafetyNumber.count > 0) {
        // Show special safety number change dialog
        SafetyNumberConfirmationSheet *sheet = [[SafetyNumberConfirmationSheet alloc]
            initWithAddressesToConfirm:recipientsWithChangedSafetyNumber
                      confirmationText:MessageStrings.sendButton
                     completionHandler:^(BOOL didConfirm) {
                         if (didConfirm) {
                             DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                                 [self.messageSenderJobQueue addMessage:messageToSend.asPreparer
                                                            transaction:transaction];
                             });
                         }
                     }];
        [self presentViewController:sheet animated:YES completion:nil];
        return;
    }

    ActionSheetController *actionSheet = [[ActionSheetController alloc] initWithTitle:nil
                                                                              message:message.mostRecentFailureText];

    [actionSheet addAction:[OWSActionSheets cancelAction]];

    ActionSheetAction *deleteMessageAction = [[ActionSheetAction alloc]
        initWithTitle:CommonStrings.deleteForMeButton
                style:ActionSheetActionStyleDestructive
              handler:^(ActionSheetAction *action) {
                  DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                      [message anyRemoveWithTransaction:transaction];
                  });
              }];
    [actionSheet addAction:deleteMessageAction];

    ActionSheetAction *resendMessageAction = [[ActionSheetAction alloc]
                  initWithTitle:NSLocalizedString(@"SEND_AGAIN_BUTTON", @"")
        accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"send_again")
                          style:ActionSheetActionStyleDefault
                        handler:^(ActionSheetAction *action) {
                            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                                [self.messageSenderJobQueue addMessage:messageToSend.asPreparer
                                                           transaction:transaction];
                            });
                        }];

    [actionSheet addAction:resendMessageAction];

    [self dismissKeyBoard];
    [self presentActionSheet:actionSheet];
}

- (void)tappedNonBlockingIdentityChangeForAddress:(nullable SignalServiceAddress *)address
{
    if (address == nil) {
        if (self.thread.isGroupThread) {
            // Before 2.13 we didn't track the recipient id in the identity change error.
            OWSLogWarn(@"Ignoring tap on legacy nonblocking identity change since it has no signal id");
            return;
            
        } else {
            TSContactThread *thread = (TSContactThread *)self.thread;
            OWSLogInfo(@"Assuming tap on legacy nonblocking identity change corresponds to current contact thread: %@",
                thread.contactAddress);
            address = thread.contactAddress;
        }
    }

    [self showFingerprintWithAddress:address];
}

- (void)tappedCorruptedMessage:(TSErrorMessage *)message
{
    __block NSString *threadName;
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        threadName = [self.contactsManager displayNameForThread:self.thread transaction:transaction];
    }];
    NSString *alertMessage = [NSString
        stringWithFormat:NSLocalizedString(@"CORRUPTED_SESSION_DESCRIPTION", @"ActionSheet title"), threadName];

    ActionSheetController *alert = [[ActionSheetController alloc] initWithTitle:nil message:alertMessage];

    [alert addAction:[OWSActionSheets cancelAction]];

    ActionSheetAction *resetSessionAction = [[ActionSheetAction alloc]
                  initWithTitle:NSLocalizedString(@"FINGERPRINT_SHRED_KEYMATERIAL_BUTTON", @"")
        accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"reset_session")
                          style:ActionSheetActionStyleDefault
                        handler:^(ActionSheetAction *action) {
                            if (![self.thread isKindOfClass:[TSContactThread class]]) {
                                // Corrupt Message errors only appear in contact threads.
                                OWSLogError(@"Unexpected request to reset session in group thread. Refusing");
                                return;
                            }
                            TSContactThread *contactThread = (TSContactThread *)self.thread;
                            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                                [self.sessionResetJobQueue addContactThread:contactThread transaction:transaction];
                            });
                        }];
    [alert addAction:resetSessionAction];

    [self dismissKeyBoard];
    [self presentActionSheet:alert];
}

- (void)tappedInvalidIdentityKeyErrorMessage:(TSInvalidIdentityKeyErrorMessage *)errorMessage
{
    NSString *keyOwner = [self.contactsManager displayNameForAddress:errorMessage.theirSignalAddress];
    NSString *titleFormat = NSLocalizedString(@"SAFETY_NUMBERS_ACTIONSHEET_TITLE", @"Action sheet heading");
    NSString *titleText = [NSString stringWithFormat:titleFormat, keyOwner];

    ActionSheetController *actionSheet = [[ActionSheetController alloc] initWithTitle:titleText message:nil];

    [actionSheet addAction:[OWSActionSheets cancelAction]];

    ActionSheetAction *showSafteyNumberAction =
        [[ActionSheetAction alloc] initWithTitle:NSLocalizedString(@"SHOW_SAFETY_NUMBER_ACTION", @"Action sheet item")
                         accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"show_safety_number")
                                           style:ActionSheetActionStyleDefault
                                         handler:^(ActionSheetAction *action) {
                                             OWSLogInfo(@"Remote Key Changed actions: Show fingerprint display");
                                             [self showFingerprintWithAddress:errorMessage.theirSignalAddress];
                                         }];
    [actionSheet addAction:showSafteyNumberAction];

    ActionSheetAction *acceptSafetyNumberAction = [[ActionSheetAction alloc]
                  initWithTitle:NSLocalizedString(@"ACCEPT_NEW_IDENTITY_ACTION", @"Action sheet item")
        accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"accept_safety_number")
                          style:ActionSheetActionStyleDefault
                        handler:^(ActionSheetAction *action) {
                            OWSLogInfo(@"Remote Key Changed actions: Accepted new identity key");

        // DEPRECATED: we're no longer creating these incoming SN error's per message,
        // but there will be some legacy ones in the wild, behind which await
        // as-of-yet-undecrypted messages
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                            if ([errorMessage isKindOfClass:[TSInvalidIdentityKeyReceivingErrorMessage class]]) {
                                // Deliberately crash if the user fails to explicitly accept the new identity
                                // key. In practice we haven't been creating these messages in over a year.
                                [errorMessage throws_acceptNewIdentityKey];
#pragma clang diagnostic pop
                            }
                        }];
    [actionSheet addAction:acceptSafetyNumberAction];

    [self dismissKeyBoard];
    [self presentActionSheet:actionSheet];
}

- (void)handleCallTap:(TSCall *)call
{
    OWSAssertDebug(call);

    if (![self.thread isKindOfClass:[TSContactThread class]]) {
        OWSFailDebug(@"unexpected thread: %@", self.thread);
        return;
    }

    TSContactThread *contactThread = (TSContactThread *)self.thread;
    NSString *displayName = [self.contactsManager displayNameForAddress:contactThread.contactAddress];

    ActionSheetController *alert = [[ActionSheetController alloc]
        initWithTitle:[CallStrings callBackAlertTitle]
              message:[NSString stringWithFormat:[CallStrings callBackAlertMessageFormat], displayName]];

    __weak ConversationViewController *weakSelf = self;
    ActionSheetAction *callAction =
        [[ActionSheetAction alloc] initWithTitle:[CallStrings callBackAlertCallButton]
                         accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"call_back")
                                           style:ActionSheetActionStyleDefault
                                         handler:^(ActionSheetAction *action) {
                                             switch (call.offerType) {
                                                 case TSRecentCallOfferTypeAudio:
                                                     [weakSelf startIndividualAudioCall];
                                                     break;
                                                 case TSRecentCallOfferTypeVideo:
                                                     [weakSelf startIndividualVideoCall];
                                                     break;
                                             }
                                         }];
    [alert addAction:callAction];
    [alert addAction:[OWSActionSheets cancelAction]];

    [self.inputToolbar clearDesiredKeyboard];
    [self dismissKeyBoard];
    [self presentActionSheet:alert];
}

- (void)updateSystemContactWithAddress:(SignalServiceAddress *)address
                 withNewNameComponents:(NSPersonNameComponents *)newNameComponents
{
    if (!self.contactsManager.supportsContactEditing) {
        OWSFailDebug(@"Contact editing unexpectedly unsupported");
        return;
    }

    CNContactViewController *contactViewController =
        [self.contactsViewHelper contactViewControllerForAddress:address
                                                 editImmediately:YES
                                          addToExistingCnContact:nil
                                           updatedNameComponents:newNameComponents];
    contactViewController.delegate = self;

    [self.navigationController pushViewController:contactViewController animated:YES];
}

#pragma mark - MessageDetailViewDelegate

- (void)detailViewMessageWasDeleted:(MessageDetailViewController *)messageDetailViewController
{
    OWSLogInfo(@"");
    [self.navigationController popToViewController:self animated:YES];
}

#pragma mark - LongTextViewDelegate

- (void)longTextViewMessageWasDeleted:(LongTextViewController *)longTextViewController
{
    OWSLogInfo(@"");
    [self.navigationController popToViewController:self animated:YES];
}

#pragma mark -

- (void)presentMessageActions:(NSArray<MessageAction *> *)messageActions withFocusedCell:(ConversationViewCell *)cell
{
    MessageActionsViewController *messageActionsViewController =
        [[MessageActionsViewController alloc] initWithFocusedViewItem:cell.viewItem
                                                          focusedView:cell
                                                              actions:messageActions];
    messageActionsViewController.delegate = self;

    self.messageActionsViewController = messageActionsViewController;

    [self setupMessageActionsStateForCell:cell];

    [messageActionsViewController presentOnWindow:self.view.window
        prepareConstraints:^{
            // In order to ensure the bottom bar remains above the keyboard, we pin it
            // to our bottom bar which follows the inputAccessoryView
            [messageActionsViewController.bottomBar autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.bottomBar];

            // We only want the message actions to show up over the detail view, in
            // the case where we are expanded. So match its edges to our nav controller.
            [messageActionsViewController.view autoPinToEdgesOfView:self.navigationController.view];
        }
        animateAlongside:^{
            self.bottomBar.alpha = 0;
        }
        completion:nil];
}

- (void)updateMessageActionsStateForCell:(ConversationViewCell *)cell
{
    // While presenting message actions, cache the original content offset.
    // This allows us to restore the user to their original scroll position
    // when they dismiss the menu.
    self.messageActionsOriginalContentOffset = self.collectionView.contentOffset;
    self.messageActionsOriginalFocusY = [self.view convertPoint:cell.frame.origin fromView:self.collectionView].y;
}

- (void)setupMessageActionsStateForCell:(ConversationViewCell *)cell
{
    [self updateMessageActionsStateForCell:cell];

    // While the menu actions are presented, temporarily use extra content
    // inset padding so that interactions near the top or bottom of the
    // collection view can be scrolled anywhere within the viewport.
    // This allows us to keep the message position constant even when
    // messages dissappear above / below the focused message to the point
    // that we have less than one screen worth of content.
    CGSize navControllerSize = self.navigationController.view.frame.size;
    self.messageActionsExtraContentInsetPadding = MAX(navControllerSize.width, navControllerSize.height);

    UIEdgeInsets contentInset = self.collectionView.contentInset;
    contentInset.top += self.messageActionsExtraContentInsetPadding;
    contentInset.bottom += self.messageActionsExtraContentInsetPadding;
    self.collectionView.contentInset = contentInset;
}

- (void)clearMessageActionsState
{
    self.bottomBar.alpha = 1;

    UIEdgeInsets contentInset = self.collectionView.contentInset;
    contentInset.top -= self.messageActionsExtraContentInsetPadding;
    contentInset.bottom -= self.messageActionsExtraContentInsetPadding;
    self.collectionView.contentInset = contentInset;

    self.collectionView.contentOffset = self.messageActionsOriginalContentOffset;
    self.messageActionsOriginalContentOffset = CGPointZero;
    self.messageActionsExtraContentInsetPadding = 0;
    self.messageActionsViewController = nil;
}

- (BOOL)isPresentingMessageActions
{
    return self.messageActionsViewController != nil;
}

- (void)dismissMessageActionsAnimated:(BOOL)animated
{
    [self dismissMessageActionsAnimated:animated
                             completion:^ {
                             }];
}

- (void)dismissMessageActionsAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    OWSLogVerbose(@"");

    if (!self.isPresentingMessageActions) {
        return;
    }

    if (animated) {
        [self.messageActionsViewController
            dismissAndAnimateAlongside:^{
                self.bottomBar.alpha = 1;
            }
            completion:^{
                [self clearMessageActionsState];
                completion();
            }];
    } else {
        [self.messageActionsViewController dismissWithoutAnimating];
        [self clearMessageActionsState];
        completion();
    }
}

- (void)dismissMessageActionsIfNecessary
{
    if (self.shouldDismissMessageActions) {
        [self dismissMessageActionsAnimated:YES];
    }
}

- (BOOL)shouldDismissMessageActions
{
    if (!self.isPresentingMessageActions) {
        return NO;
    }
    NSString *_Nullable messageActionInteractionId = self.messageActionsViewController.focusedInteraction.uniqueId;
    if (messageActionInteractionId == nil) {
        return NO;
    }
    // Check whether there is still a view item for this interaction.
    return (self.conversationViewModel.viewState.interactionIndexMap[messageActionInteractionId] == nil);
}

- (nullable NSValue *)contentOffsetForMessageActionInteraction
{
    OWSAssertDebug(self.messageActionsViewController);

    NSString *_Nullable messageActionInteractionId = self.messageActionsViewController.focusedInteraction.uniqueId;
    if (messageActionInteractionId == nil) {
        OWSFailDebug(@"Missing message action interaction.");
        return nil;
    }

    NSNumber *_Nullable interactionIndex
        = self.conversationViewModel.viewState.interactionIndexMap[messageActionInteractionId];
    if (interactionIndex == nil) {
        // This is expected if the menu action interaction is being deleted.
        return nil;
    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:interactionIndex.integerValue inSection:0];
    UICollectionViewLayoutAttributes *_Nullable layoutAttributes =
        [self.layout layoutAttributesForItemAtIndexPath:indexPath];
    if (layoutAttributes == nil) {
        OWSFailDebug(@"Missing layoutAttributes.");
        return nil;
    }
    CGRect cellFrame = layoutAttributes.frame;
    return [NSValue valueWithCGPoint:CGPointMake(0, cellFrame.origin.y - self.messageActionsOriginalFocusY)];
}

#pragma mark - ConversationViewCellDelegate

- (BOOL)conversationCell:(ConversationViewCell *)cell shouldAllowReplyForItem:(nonnull id<ConversationViewItem>)viewItem
{
    if (!self.thread.isLocalUserFullMemberOfThread) {
        return NO;
    }
    if (self.threadViewModel.hasPendingMessageRequest) {
        return NO;
    }

    if ([viewItem.interaction isKindOfClass:[TSMessage class]]) {
        TSMessage *message = (TSMessage *)viewItem.interaction;
        if (message.wasRemotelyDeleted) {
            return NO;
        }
    }

    if (viewItem.interaction.interactionType == OWSInteractionType_OutgoingMessage) {
        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
        if (outgoingMessage.messageState == TSOutgoingMessageStateFailed) {
            // Don't allow "delete" or "reply" on "failed" outgoing messages.
            return NO;
        } else if (outgoingMessage.messageState == TSOutgoingMessageStateSending) {
            // Don't allow "delete" or "reply" on "sending" outgoing messages.
            return NO;
        }
    }

    return YES;
}

- (void)conversationCell:(ConversationViewCell *)cell
             shouldAllowReply:(BOOL)shouldAllowReply
    didLongpressMediaViewItem:(id<ConversationViewItem>)viewItem
{
    NSArray<MessageAction *> *messageActions =
        [ConversationViewItemActions mediaActionsWithConversationViewItem:viewItem
                                                         shouldAllowReply:shouldAllowReply
                                                                 delegate:self];
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell
            shouldAllowReply:(BOOL)shouldAllowReply
    didLongpressTextViewItem:(id<ConversationViewItem>)viewItem
{
    NSArray<MessageAction *> *messageActions =
        [ConversationViewItemActions textActionsWithConversationViewItem:viewItem
                                                        shouldAllowReply:shouldAllowReply
                                                                delegate:self];
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell
             shouldAllowReply:(BOOL)shouldAllowReply
    didLongpressQuoteViewItem:(id<ConversationViewItem>)viewItem
{
    NSArray<MessageAction *> *messageActions =
        [ConversationViewItemActions quotedMessageActionsWithConversationViewItem:viewItem
                                                                 shouldAllowReply:shouldAllowReply
                                                                         delegate:self];
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell
    didLongpressSystemMessageViewItem:(id<ConversationViewItem>)viewItem
{
    NSArray<MessageAction *> *messageActions =
        [ConversationViewItemActions infoMessageActionsWithConversationViewItem:viewItem delegate:self];
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell
        shouldAllowReply:(BOOL)shouldAllowReply
     didLongpressSticker:(id<ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);
    NSArray<MessageAction *> *messageActions =
        [ConversationViewItemActions mediaActionsWithConversationViewItem:viewItem
                                                         shouldAllowReply:shouldAllowReply
                                                                 delegate:self];
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell didTapAvatar:(id<ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);

    if (viewItem.interaction.interactionType != OWSInteractionType_IncomingMessage) {
        OWSFailDebug(@"not an incoming message.");
        return;
    }

    TSIncomingMessage *incomingMessage = (TSIncomingMessage *)viewItem.interaction;
    GroupViewHelper *groupViewHelper = [[GroupViewHelper alloc] initWithThreadViewModel:self.threadViewModel];
    groupViewHelper.delegate = self;
    MemberActionSheet *actionSheet = [[MemberActionSheet alloc] initWithAddress:incomingMessage.authorAddress
                                                                groupViewHelper:groupViewHelper];
    [actionSheet presentFromViewController:self];
}

- (void)conversationCell:(ConversationViewCell *)cell didChangeLongpress:(id<ConversationViewItem>)viewItem
{
    if (!
        [self.messageActionsViewController.focusedInteraction.uniqueId isEqualToString:viewItem.interaction.uniqueId]) {
        OWSFailDebug(@"Received longpress update for unexpected cell");
        return;
    }

    [self.messageActionsViewController didChangeLongpress];
}

- (void)conversationCell:(ConversationViewCell *)cell didEndLongpress:(id<ConversationViewItem>)viewItem
{
    if (!
        [self.messageActionsViewController.focusedInteraction.uniqueId isEqualToString:viewItem.interaction.uniqueId]) {
        OWSFailDebug(@"Received longpress update for unexpected cell");
        return;
    }

    [self.messageActionsViewController didEndLongpress];
}

- (void)conversationCell:(ConversationViewCell *)cell didTapReactions:(id<ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);

    if (!viewItem.reactionState.hasReactions) {
        OWSFailDebug(@"missing reaction state");
        return;
    }

    if (![viewItem.interaction isKindOfClass:[TSMessage class]]) {
        OWSFailDebug(@"Unexpected interaction type");
        return;
    }

    ReactionsDetailSheet *detailSheet =
        [[ReactionsDetailSheet alloc] initWithReactionState:viewItem.reactionState
                                                    message:(TSMessage *)viewItem.interaction];
    [self presentViewController:detailSheet animated:YES completion:nil];
    self.reactionsDetailSheet = detailSheet;
}

- (BOOL)conversationCellHasPendingMessageRequest:(ConversationViewCell *)cell
{
    return self.threadViewModel.hasPendingMessageRequest;
}

- (BOOL)isShowingSelectionUI
{
    return self.uiMode == ConversationUIMode_Selection;
}

- (BOOL)isViewItemSelected:(id<ConversationViewItem>)viewItem
{
    return [self.selectedItems objectForKey:viewItem.interaction.uniqueId] != nil;
}

- (void)conversationCell:(nonnull ConversationViewCell *)cell didSelectViewItem:(id<ConversationViewItem>)viewItem
{
    OWSAssertDebug(self.isShowingSelectionUI);

    NSIndexPath *_Nullable indexPath = [self.conversationViewModel indexPathForViewItem:viewItem];
    if (indexPath == nil) {
        OWSFailDebug(@"indexPath was unexpectedly nil");
        return;
    }

    [self.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];

    NSMutableDictionary *dict = [self.selectedItems mutableCopy];
    dict[viewItem.interaction.uniqueId] = viewItem;
    self.selectedItems = [dict copy];
    [self updateSelectionButtons];
    [self updateSelectionHighlight];
}

- (void)conversationCell:(nonnull ConversationViewCell *)cell didDeselectViewItem:(id<ConversationViewItem>)viewItem
{
    OWSAssertDebug(self.isShowingSelectionUI);

    NSIndexPath *_Nullable indexPath = [self.conversationViewModel indexPathForViewItem:viewItem];
    if (indexPath == nil) {
        OWSFailDebug(@"indexPath was unexpectedly nil");
        return;
    }

    [self.collectionView deselectItemAtIndexPath:indexPath animated:NO];

    NSMutableDictionary *dict = [self.selectedItems mutableCopy];
    [dict removeObjectForKey:viewItem.interaction.uniqueId];
    self.selectedItems = [dict copy];
    [self updateSelectionButtons];
    [self updateSelectionHighlight];
}

- (void)reloadReactionsDetailSheetWithTransaction:(SDSAnyReadTransaction *)transaction
{
    if (!self.reactionsDetailSheet) {
        return;
    }

    NSString *messageId = self.reactionsDetailSheet.messageId;

    NSNumber *_Nullable index = self.conversationViewModel.viewState.interactionIndexMap[messageId];
    if (index == nil) {
        // The message no longer exists, dismiss the sheet.
        [self dismissReactionsDetailSheetAnimated:YES];
    }

    id<ConversationViewItem> viewItem = [self viewItemForIndex:index.integerValue];

    InteractionReactionState *_Nullable reactionState = viewItem.reactionState;
    if (!reactionState.hasReactions) {
        // There are no longer reactions on this message, dismiss the sheet.
        [self dismissReactionsDetailSheetAnimated:YES];
        return;
    }

    // Update the detail sheet with the latest reaction
    // state, in case the reactions have changed.
    [self.reactionsDetailSheet setReactionState:reactionState transaction:transaction];
}

- (void)dismissReactionsDetailSheetAnimated:(BOOL)animated
{
    if (!self.reactionsDetailSheet) {
        return;
    }

    [self.reactionsDetailSheet dismissViewControllerAnimated:animated
                                                  completion:^{
                                                      self.reactionsDetailSheet = nil;
                                                  }];
}

- (void)conversationCell:(ConversationViewCell *)cell didReplyToItem:(id<ConversationViewItem>)viewItem
{
    [self populateReplyForViewItem:viewItem];
}

- (void)presentAddThreadToProfileWhitelistWithSuccess:(void (^)(void))successHandler
{
    [[OWSProfileManager shared] presentAddThreadToProfileWhitelist:self.thread
                                                fromViewController:self
                                                           success:successHandler];
}

#pragma mark - Audio Setup

- (void)prepareAudioPlayerForViewItem:(id<ConversationViewItem>)viewItem
                     attachmentStream:(TSAttachmentStream *)attachmentStream
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentStream);

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:attachmentStream.originalFilePath]) {
        OWSFailDebug(@"Missing audio file: %@", attachmentStream.originalMediaURL);
    }

    if (self.audioAttachmentPlayer) {
        // Is this player associated with this media adapter?
        if (self.audioAttachmentPlayer.owner == viewItem.interaction.uniqueId) {
            return;
        }

        [self.audioAttachmentPlayer stop];
        self.audioAttachmentPlayer = nil;
    }

    self.audioAttachmentPlayer = [[OWSAudioPlayer alloc] initWithMediaUrl:attachmentStream.originalMediaURL
                                                            audioBehavior:OWSAudioBehavior_AudioMessagePlayback
                                                                 delegate:viewItem];

    // Associate the player with this media adapter.
    self.audioAttachmentPlayer.owner = viewItem.interaction.uniqueId;

    [self.audioAttachmentPlayer setupAudioPlayer];
}

#pragma mark - OWSMessageBubbleViewDelegate

- (void)didTapImageViewItem:(id<ConversationViewItem>)viewItem
           attachmentStream:(TSAttachmentStream *)attachmentStream
                  imageView:(UIView *)imageView
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentStream);
    OWSAssertDebug(imageView);

    [self dismissKeyBoard];

    MediaPageViewController *pageVC = [[MediaPageViewController alloc] initWithInitialMediaAttachment:attachmentStream
                                                                                               thread:self.thread];

    [self presentViewController:pageVC animated:YES completion:nil];
}

- (void)didTapVideoViewItem:(id<ConversationViewItem>)viewItem
           attachmentStream:(TSAttachmentStream *)attachmentStream
                  imageView:(UIImageView *)imageView
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentStream);

    [self dismissKeyBoard];

    MediaPageViewController *pageVC = [[MediaPageViewController alloc] initWithInitialMediaAttachment:attachmentStream
                                                                                               thread:self.thread];

    [self presentViewController:pageVC animated:YES completion:nil];
}

- (void)didTapAudioViewItem:(id<ConversationViewItem>)viewItem attachmentStream:(TSAttachmentStream *)attachmentStream
{
    [self prepareAudioPlayerForViewItem:viewItem attachmentStream:attachmentStream];

    // Resume from where we left off
    [self.audioAttachmentPlayer setCurrentTime:viewItem.audioProgressSeconds];

    [self.audioAttachmentPlayer togglePlayState];
}

- (void)didScrubAudioViewItem:(id<ConversationViewItem>)viewItem
                       toTime:(NSTimeInterval)time
             attachmentStream:(TSAttachmentStream *)attachmentStream
{
    [self prepareAudioPlayerForViewItem:viewItem attachmentStream:attachmentStream];

    [self.audioAttachmentPlayer setCurrentTime:time];
}

- (void)didTapPdfForItem:(id<ConversationViewItem>)viewItem attachmentStream:(TSAttachmentStream *)attachmentStream
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentStream);

    PdfViewController *pdfView = [[PdfViewController alloc] initWithViewItem:viewItem
                                                            attachmentStream:attachmentStream];
    UIViewController *navigationController = [[OWSNavigationController alloc] initWithRootViewController:pdfView];
    [self presentFullScreenViewController:navigationController animated:YES completion:nil];
}

- (void)didTapTruncatedTextMessage:(id<ConversationViewItem>)conversationItem
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(conversationItem);
    OWSAssertDebug([conversationItem.interaction isKindOfClass:[TSMessage class]]);

    if (conversationItem.displayableBodyText.canRenderTruncatedTextInline) {
        conversationItem.isTruncatedTextVisible = YES;

        CGPoint contentOffset = self.collectionView.contentOffset;
        [self reloadData];
        [self.collectionView setContentOffset:contentOffset animated:NO];
    } else {
        LongTextViewController *viewController = [[LongTextViewController alloc] initWithViewItem:conversationItem];
        viewController.delegate = self;
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

- (void)didTapMention:(Mention *)mention
{
    [ImpactHapticFeedback impactOccuredWithStyle:UIImpactFeedbackStyleLight];

    GroupViewHelper *groupViewHelper = [[GroupViewHelper alloc] initWithThreadViewModel:self.threadViewModel];
    groupViewHelper.delegate = self;
    MemberActionSheet *actionSheet = [[MemberActionSheet alloc] initWithAddress:mention.address
                                                                groupViewHelper:groupViewHelper];
    [actionSheet presentFromViewController:self];
}

- (void)didTapContactShareViewItem:(id<ConversationViewItem>)conversationItem
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(conversationItem);
    OWSAssertDebug(conversationItem.contactShare);
    OWSAssertDebug([conversationItem.interaction isKindOfClass:[TSMessage class]]);

    ContactViewController *view = [[ContactViewController alloc] initWithContactShare:conversationItem.contactShare];
    [self.navigationController pushViewController:view animated:YES];
}

- (void)didTapSendMessageToContactShare:(ContactShareViewModel *)contactShare
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(contactShare);

    [self.contactShareViewHelper sendMessageWithContactShare:contactShare fromViewController:self];
}

- (void)didTapSendInviteToContactShare:(ContactShareViewModel *)contactShare
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(contactShare);

    [self.contactShareViewHelper showInviteContactWithContactShare:contactShare fromViewController:self];
}

- (void)didTapShowAddToContactUIForContactShare:(ContactShareViewModel *)contactShare
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(contactShare);

    [self.contactShareViewHelper showAddToContactsWithContactShare:contactShare fromViewController:self];
}

- (void)didTapStickerPack:(StickerPackInfo *)stickerPackInfo
{
    OWSAssertIsOnMainThread();

    [self showStickerPack:stickerPackInfo];
}

- (void)didTapGroupInviteLink:(NSURL *)url
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug([GroupManager isPossibleGroupInviteLink:url]);

    [GroupInviteLinksUI openGroupInviteLink:url fromViewController:self];
}

- (void)didTapFailedIncomingAttachment:(id<ConversationViewItem>)viewItem
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);

    // Restart failed downloads
    TSMessage *message = (TSMessage *)viewItem.interaction;
    [self handleFailedDownloadTapForMessage:message];
}

- (void)didTapPendingMessageRequestIncomingAttachment:(id<ConversationViewItem>)viewItem
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);

    // Start downloads for message.
    TSMessage *message = (TSMessage *)viewItem.interaction;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        NSArray<TSAttachment *> *attachments = [message allAttachmentsWithTransaction:transaction.unwrapGrdbRead];
        [self.attachmentDownloads downloadAttachmentsForMessage:message
            bypassPendingMessageRequest:YES
            attachments:attachments
            success:^(NSArray<TSAttachmentStream *> *attachmentStreams) {
                OWSLogInfo(@"Successfully downloaded attachment in thread: %@", message.threadWithSneakyTransaction);
            }
            failure:^(NSError *error) { OWSLogWarn(@"Failed to download message with error: %@", error); }];
    }];
}

- (void)didTapFailedOutgoingMessage:(TSOutgoingMessage *)message
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(message);

    [self resendFailedOutgoingMessage:message];
}

- (void)didTapConversationItem:(id<ConversationViewItem>)viewItem
                                 quotedReply:(OWSQuotedReplyModel *)quotedReply
    failedThumbnailDownloadAttachmentPointer:(TSAttachmentPointer *)attachmentPointer
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentPointer);

    TSMessage *message = (TSMessage *)viewItem.interaction;
    if (![message isKindOfClass:[TSMessage class]]) {
        OWSFailDebug(@"message had unexpected class: %@", message.class);
        return;
    }

    [self.attachmentDownloads downloadAttachmentPointer:attachmentPointer
        message:message
        bypassPendingMessageRequest:NO
        success:^(NSArray<TSAttachmentStream *> *attachmentStreams) {
            OWSAssertDebug(attachmentStreams.count == 1);
            TSAttachmentStream *attachmentStream = attachmentStreams.firstObject;
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                [message anyUpdateMessageWithTransaction:transaction
                                                   block:^(TSMessage *latestInstance) {
                                                       [latestInstance
                                                           setQuotedMessageThumbnailAttachmentStream:attachmentStream];
                                                   }];
            });
        }
        failure:^(NSError *error) {
            OWSLogWarn(@"Failed to redownload thumbnail with error: %@", error);
        }];
}

- (void)didTapConversationItem:(id<ConversationViewItem>)viewItem quotedReply:(OWSQuotedReplyModel *)quotedReply
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(quotedReply);
    OWSAssertDebug(quotedReply.timestamp > 0);
    OWSAssertDebug(quotedReply.authorAddress.isValid);

    __block NSIndexPath *_Nullable indexPath;
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        indexPath = [self.conversationViewModel ensureLoadWindowContainsQuotedReply:quotedReply
                                                                        transaction:transaction];
    }];

    if (quotedReply.isRemotelySourced || !indexPath) {
        [self presentRemotelySourcedQuotedReplyToast];
        return;
    }

    [self scrollToInteractionWithIndexPath:indexPath
                        onScreenPercentage:1
                                  position:ScrollToCenterIfNotEntirelyOnScreen
                                  animated:YES];

    // TODO: Highlight the quoted message?
}

- (void)didTapConversationItem:(id<ConversationViewItem>)viewItem linkPreview:(OWSLinkPreview *)linkPreview
{
    OWSAssertIsOnMainThread();

    NSURL *_Nullable url = [NSURL URLWithString:linkPreview.urlString];
    if (!url) {
        OWSFailDebug(@"Invalid link preview URL.");
        return;
    }

    if ([StickerPackInfo isStickerPackShareUrl:url]) {
        StickerPackInfo *_Nullable stickerPackInfo = [StickerPackInfo parseStickerPackShareUrl:url];

        if (stickerPackInfo == nil) {
            OWSFailDebug(@"Could not parse sticker pack share URL: %@", url);
        } else {
            StickerPackViewController *packView =
                [[StickerPackViewController alloc] initWithStickerPackInfo:stickerPackInfo];

            [packView presentFrom:self animated:YES];
            return;
        }
    }

    if ([GroupManager isPossibleGroupInviteLink:url]) {
        [self didTapGroupInviteLink:url];
        return;
    }

    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)showDetailViewForViewItem:(id<ConversationViewItem>)conversationItem
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(conversationItem);
    OWSAssertDebug([conversationItem.interaction isKindOfClass:[TSMessage class]]);

    TSMessage *message = (TSMessage *)conversationItem.interaction;
    MessageDetailViewController *detailVC =
        [[MessageDetailViewController alloc] initWithViewItem:conversationItem
                                                      message:message
                                                       thread:self.thread
                                                         mode:MessageMetadataViewModeFocusOnMetadata];
    detailVC.delegate = self;
    [self.navigationController pushViewController:detailVC animated:YES];
}

- (void)populateReplyForViewItem:(id<ConversationViewItem>)conversationItem
{
    OWSLogDebug(@"user did tap reply");
    self.uiMode = ConversationUIMode_Normal;

    __block OWSQuotedReplyModel *quotedReply;
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        quotedReply = [OWSQuotedReplyModel quotedReplyForSendingWithConversationViewItem:conversationItem
                                                                             transaction:transaction];
    }];

    if (![quotedReply isKindOfClass:[OWSQuotedReplyModel class]]) {
        OWSFailDebug(@"unexpected quotedMessage: %@", quotedReply.class);
        return;
    }

    if (SSKDebugFlags.internalLogging) {
        OWSLogInfo(@"");
    }
    self.inputToolbar.quotedReply = quotedReply;
    [self.inputToolbar beginEditingMessage];
}

#pragma mark - OWSMessageStickerViewDelegate

- (void)showStickerPack:(StickerPackInfo *)stickerPackInfo
{
    OWSAssertIsOnMainThread();

    StickerPackViewController *packView = [[StickerPackViewController alloc] initWithStickerPackInfo:stickerPackInfo];
    [packView presentFrom:self animated:YES];
}

#pragma mark - OWSMessageViewOnceViewDelegate

- (void)didTapViewOnceAttachment:(id<ConversationViewItem>)viewItem
                attachmentStream:(TSAttachmentStream *)attachmentStream
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentStream);

    [ViewOnceMessageViewController tryToPresentWithInteraction:viewItem.interaction from:self];
}

- (void)didTapViewOnceExpired:(id<ConversationViewItem>)viewItem
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);

    if ([viewItem.interaction isKindOfClass:[TSOutgoingMessage class]]) {
        [self presentViewOnceOutgoingToast];
    } else {
        [self presentViewOnceAlreadyViewedToast];
    }
}

#pragma mark - CNContactViewControllerDelegate

- (void)contactViewController:(CNContactViewController *)viewController
       didCompleteWithContact:(nullable CNContact *)contact
{
    [self.navigationController popToViewController:self animated:YES];
}

#pragma mark - ContactsViewHelperObserver

- (void)contactsViewHelperDidUpdateContacts
{
    [self updateNavigationTitle];
    [self reloadData];
}

#pragma mark - Scroll Down Button

- (void)createConversationScrollButtons
{
    self.scrollDownButton = [[ConversationScrollButton alloc] initWithIconName:@"chevron-down-20"];
    [self.scrollDownButton addTarget:self
                              action:@selector(scrollDownButtonTapped)
                    forControlEvents:UIControlEventTouchUpInside];
    self.scrollDownButton.hidden = YES;
    self.scrollDownButton.alpha = 0;
    [self.view addSubview:self.scrollDownButton];
    [self.scrollDownButton autoSetDimension:ALDimensionWidth toSize:ConversationScrollButton.buttonSize];
    SET_SUBVIEW_ACCESSIBILITY_IDENTIFIER(self, _scrollDownButton);

    [self.scrollDownButton autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:self.bottomBar withOffset:-16];
    [self.scrollDownButton autoPinEdgeToSuperviewSafeArea:ALEdgeTrailing];

    self.scrollToNextMentionButton = [[ConversationScrollButton alloc] initWithIconName:@"mention-24"];
    [self.scrollToNextMentionButton addTarget:self
                                       action:@selector(scrollToNextMentionButtonTapped)
                             forControlEvents:UIControlEventTouchUpInside];
    self.scrollToNextMentionButton.hidden = YES;
    self.scrollToNextMentionButton.alpha = 0;
    [self.view addSubview:self.scrollToNextMentionButton];
    [self.scrollToNextMentionButton autoSetDimension:ALDimensionWidth toSize:ConversationScrollButton.buttonSize];
    SET_SUBVIEW_ACCESSIBILITY_IDENTIFIER(self, _scrollToNextMentionButton);

    [self.scrollToNextMentionButton autoPinEdge:ALEdgeBottom
                                         toEdge:ALEdgeTop
                                         ofView:self.scrollDownButton
                                     withOffset:-10];
    [self.scrollToNextMentionButton autoPinEdgeToSuperviewSafeArea:ALEdgeTrailing];
}

- (void)setUnreadMessageCount:(NSUInteger)unreadMessageCount
{
    OWSAssertIsOnMainThread();
    if (_unreadMessageCount != unreadMessageCount) {
        _unreadMessageCount = unreadMessageCount;
        [self configureScrollDownButtons];
    }
}

- (void)setUnreadMentionMessages:(nullable NSArray<TSMessage *> *)unreadMentionMessages
{
    OWSAssertIsOnMainThread();
    if (_unreadMentionMessages != unreadMentionMessages) {
        _unreadMentionMessages = unreadMentionMessages;
        [self configureScrollDownButtons];
    }
}

/// Checks to see if the unread message flag can be cleared. Shortcircuits if the flag is not set to begin with
- (void)clearUnreadMessageFlagIfNecessary
{
    OWSAssertIsOnMainThread();
    if (self.unreadMessageCount > 0) {
        [self updateUnreadMessageFlagUsingAsyncTransaction];
    }
}

- (void)updateUnreadMessageFlagUsingAsyncTransaction
{
    // Resubmits to the main queue because we can't verify we're not already in a transaction we don't know about.
    // This method may be called in response to all sorts of view state changes, e.g. scroll state. These changes
    // can be a result of a UIKit response to app activity that already has an open transaction.
    //
    // We need a transaction to proceed, but we can't verify that we're not already in one (unless explicitly handed one)
    // To workaround this, we async a block to open a fresh transaction on the main queue.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *newTransaction) {
            OWSAssertDebug(newTransaction);
            [self updateUnreadMessageFlagWithTransaction:newTransaction];
        }];
    });
}

- (void)updateUnreadMessageFlagWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertIsOnMainThread();
    InteractionFinder *interactionFinder = [[InteractionFinder alloc] initWithThreadUniqueId:self.thread.uniqueId];
    NSUInteger unreadCount = [interactionFinder unreadCountWithTransaction:transaction.unwrapGrdbRead];
    [self setUnreadMessageCount:unreadCount];

    self.unreadMentionMessages = [MentionFinder messagesMentioningWithAddress:self.tsAccountManager.localAddress
                                                                           in:self.thread
                                                          includeReadMessages:NO
                                                                  transaction:transaction.unwrapGrdbRead];
}

- (void)scrollDownButtonTapped
{
    NSIndexPath *indexPathOfUnreadMessagesIndicator = [self indexPathOfUnreadMessagesIndicator];
    if (indexPathOfUnreadMessagesIndicator != nil) {
        NSInteger unreadRow = indexPathOfUnreadMessagesIndicator.row;

        BOOL isScrolledAboveUnreadIndicator = YES;
        NSArray<NSIndexPath *> *visibleIndices = self.collectionView.indexPathsForVisibleItems;
        for (NSIndexPath *indexPath in visibleIndices) {
            if (indexPath.row > unreadRow) {
                isScrolledAboveUnreadIndicator = NO;
                break;
            }
        }

        if (isScrolledAboveUnreadIndicator) {
            // Only scroll as far as the unread indicator if we're scrolled above the unread indicator.
            [self scrollToInteractionWithIndexPath:indexPathOfUnreadMessagesIndicator
                                onScreenPercentage:1
                                          position:ScrollToTop
                                          animated:YES];
            return;
        }
    }

    [self scrollToBottomAnimated:YES];
}

- (void)scrollToNextMentionButtonTapped
{
    TSMessage *_Nullable nextMessage = self.unreadMentionMessages.firstObject;
    if (nextMessage) {
        [self scrollToInteractionWithUniqueId:nextMessage.uniqueId
                           onScreenPercentage:1
                                     position:ScrollToBottomIfNotEntirelyOnScreen
                                     animated:YES];
    }
}

- (void)configureScrollDownButtons
{
    OWSAssertIsOnMainThread();

    CGFloat scrollSpaceToBottom = (self.safeContentHeight + self.collectionView.contentInset.bottom
        - (self.collectionView.contentOffset.y + self.collectionView.frame.size.height));
    CGFloat pageHeight = (self.collectionView.frame.size.height
        - (self.collectionView.contentInset.top + self.collectionView.contentInset.bottom));
    BOOL isScrolledUpOnePage = scrollSpaceToBottom > pageHeight * 1.f;

    BOOL hasLaterMessageOffscreen = ([self lastSortIdInLoadedWindow] > [self lastVisibleSortId]) || [self.conversationViewModel canLoadNewerItems];

    BOOL scrollDownWasHidden = self.isHidingScrollDownButton ? YES : self.scrollDownButton.hidden;
    BOOL scrollDownIsHidden = scrollDownWasHidden;

    BOOL scrollToNextMentionWasHidden
        = self.isHidingScrollToNextMentionButton ? YES : self.scrollToNextMentionButton.hidden;
    BOOL scrollToNextMentionIsHidden = scrollToNextMentionWasHidden;

    if (self.isInPreviewPlatter) {
        scrollDownIsHidden = YES;
        scrollToNextMentionIsHidden = YES;

    } else if (self.isPresentingMessageActions) {
        // Content offset calculations get messed up when we're presenting message actions
        // Don't change button visibility if we're presenting actions
        // no-op

    } else {
        BOOL shouldScrollDownAppear = isScrolledUpOnePage || hasLaterMessageOffscreen;
        scrollDownIsHidden = !shouldScrollDownAppear;

        BOOL shouldScrollToMentionAppear = shouldScrollDownAppear && self.unreadMentionMessages.count > 0;
        scrollToNextMentionIsHidden = !shouldScrollToMentionAppear;
    }

    BOOL scrollDownVisibilityDidChange = scrollDownIsHidden != scrollDownWasHidden;
    BOOL scrollToNextMentionVisibilityDidChange = scrollToNextMentionIsHidden != scrollToNextMentionWasHidden;

    if (scrollDownVisibilityDidChange || scrollToNextMentionVisibilityDidChange) {
        if (scrollDownVisibilityDidChange) {
            self.scrollDownButton.hidden = NO;
            self.isHidingScrollDownButton = scrollDownIsHidden;
            [self.scrollDownButton.layer removeAllAnimations];
        }
        if (scrollToNextMentionVisibilityDidChange) {
            self.scrollToNextMentionButton.hidden = NO;
            self.isHidingScrollToNextMentionButton = scrollToNextMentionIsHidden;
            [self.scrollToNextMentionButton.layer removeAllAnimations];
        }

        [UIView animateWithDuration:0.2
            animations:^{
                if (scrollDownVisibilityDidChange) {
                    self.scrollDownButton.alpha = scrollDownIsHidden ? 0 : 1;
                }
                if (scrollToNextMentionVisibilityDidChange) {
                    self.scrollToNextMentionButton.alpha = scrollToNextMentionIsHidden ? 0 : 1;
                }
            }
            completion:^(BOOL finished) {
                if (!finished) {
                    return;
                }
                if (scrollDownVisibilityDidChange) {
                    self.scrollDownButton.hidden = scrollDownIsHidden;
                    self.isHidingScrollDownButton = NO;
                }
                if (scrollToNextMentionVisibilityDidChange) {
                    self.scrollToNextMentionButton.hidden = scrollToNextMentionIsHidden;
                    self.isHidingScrollToNextMentionButton = NO;
                }
            }];
    }

    self.scrollDownButton.unreadCount = self.unreadMessageCount;
    self.scrollToNextMentionButton.unreadCount = self.unreadMentionMessages.count;
}

#pragma mark - Attachment Picking: Contacts

- (void)chooseContactForSending
{
    ContactsPicker *contactsPicker = [[ContactsPicker alloc] initWithAllowsMultipleSelection:NO
                                                                            subtitleCellType:SubtitleCellValueNone];
    contactsPicker.contactsPickerDelegate = self;
    contactsPicker.title
        = NSLocalizedString(@"CONTACT_PICKER_TITLE", @"navbar title for contact picker when sharing a contact");

    OWSNavigationController *navigationController =
        [[OWSNavigationController alloc] initWithRootViewController:contactsPicker];
    [self dismissKeyBoard];
    [self presentFormSheetViewController:navigationController animated:YES completion:nil];
}

#pragma mark - Attachment Picking: Documents

- (void)showAttachmentDocumentPickerMenu
{
    ActionSheetController *actionSheet = [ActionSheetController new];

    ActionSheetAction *mediaAction = [[ActionSheetAction alloc]
        initWithTitle:NSLocalizedString(@"MEDIA_FROM_LIBRARY_BUTTON", @"media picker option to choose from library")
                style:ActionSheetActionStyleDefault
              handler:^(ActionSheetAction *action) {
                  [self chooseFromLibraryAsDocument:YES];
              }];
    [actionSheet addAction:mediaAction];

    ActionSheetAction *browseAction = [[ActionSheetAction alloc]
        initWithTitle:NSLocalizedString(@"BROWSE_FILES_BUTTON", @"browse files option from file sharing menu")
                style:ActionSheetActionStyleDefault
              handler:^(ActionSheetAction *action) {
                  [self showDocumentPicker];
              }];
    [actionSheet addAction:browseAction];

    [actionSheet addAction:OWSActionSheets.cancelAction];

    [self dismissKeyBoard];
    [self presentActionSheet:actionSheet];
}

- (void)showDocumentPicker
{
    NSString *allItems = (__bridge NSString *)kUTTypeItem;
    NSArray<NSString *> *documentTypes = @[ allItems ];

    // UIDocumentPickerModeImport copies to a temp file within our container.
    // It uses more memory than "open" but lets us avoid working with security scoped URLs.
    UIDocumentPickerMode pickerMode = UIDocumentPickerModeImport;

    UIDocumentPickerViewController *pickerController =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes inMode:pickerMode];
    pickerController.delegate = self;

    [self dismissKeyBoard];
    [self presentFormSheetViewController:pickerController animated:YES completion:nil];
}

#pragma mark - Attachment Picking: GIFs

- (void)showGifPicker
{
    GifPickerNavigationViewController *gifModal = [GifPickerNavigationViewController new];
    gifModal.approvalDelegate = self;
    [self dismissKeyBoard];
    [self presentViewController:gifModal animated:YES completion:nil];
}

- (void)messageWasSent:(TSOutgoingMessage *)message
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(message);

    if (SSKDebugFlags.internalLogging) {
        OWSLogInfo(@"");
    }

    self.lastMessageSentDate = [NSDate new];
    [self.conversationViewModel clearUnreadMessagesIndicator];
    self.inputToolbar.quotedReply = nil;

    if ([Environment.shared.preferences soundInForeground]) {
        SystemSoundID soundId = [OWSSounds systemSoundIDForSound:OWSStandardSound_MessageSent quiet:YES];
        AudioServicesPlaySystemSound(soundId);
    }
    [self.typingIndicators didSendOutgoingMessageInThread:self.thread];
}

#pragma mark UIDocumentMenuDelegate

- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu
    didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker
{
    documentPicker.delegate = self;

    [self dismissKeyBoard];
    [self presentFormSheetViewController:documentPicker animated:YES completion:nil];
}

#pragma mark UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    OWSLogDebug(@"Picked document at url: %@", url);

    NSString *type;
    NSError *typeError;
    [url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&typeError];
    if (typeError) {
        OWSFailDebug(@"Determining type of picked document at url: %@ failed with error: %@", url, typeError);
    }
    if (!type) {
        OWSFailDebug(@"falling back to default filetype for picked document at url: %@", url);
        type = (__bridge NSString *)kUTTypeData;
    }

    NSNumber *isDirectory;
    NSError *isDirectoryError;
    [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&isDirectoryError];
    if (isDirectoryError) {
        OWSFailDebug(@"Determining if picked document was a directory failed with error: %@", isDirectoryError);
    } else if ([isDirectory boolValue]) {
        OWSLogInfo(@"User picked directory.");

        dispatch_async(dispatch_get_main_queue(), ^{
            [OWSActionSheets
                showActionSheetWithTitle:
                    NSLocalizedString(@"ATTACHMENT_PICKER_DOCUMENTS_PICKED_DIRECTORY_FAILED_ALERT_TITLE",
                        @"Alert title when picking a document fails because user picked a directory/bundle")
                                 message:NSLocalizedString(
                                             @"ATTACHMENT_PICKER_DOCUMENTS_PICKED_DIRECTORY_FAILED_ALERT_BODY",
                                             @"Alert body when picking a document fails because user picked a "
                                             @"directory/bundle")];
        });
        return;
    }

    NSString *filename = url.lastPathComponent;
    if (!filename) {
        OWSFailDebug(@"Unable to determine filename");
        filename = NSLocalizedString(
            @"ATTACHMENT_DEFAULT_FILENAME", @"Generic filename for an attachment with no known name");
    }

    OWSAssertDebug(type);
    OWSAssertDebug(filename);
    NSError *error;
    _Nullable id<DataSource> dataSource = [DataSourcePath dataSourceWithURL:url
                                                 shouldDeleteOnDeallocation:NO
                                                                      error:&error];
    if (dataSource == nil) {
        OWSFailDebug(@"error: %@", error);

        dispatch_async(dispatch_get_main_queue(), ^{
            [OWSActionSheets
                showActionSheetWithTitle:NSLocalizedString(@"ATTACHMENT_PICKER_DOCUMENTS_FAILED_ALERT_TITLE",
                                             @"Alert title when picking a document fails for an unknown reason")];
        });
        return;
    }

    [dataSource setSourceFilename:filename];

    // Although we want to be able to send higher quality attachments through the document picker
    // it's more important that we ensure the sent format is one all clients can accept (e.g. *not* quicktime .mov)
    if ([SignalAttachment isInvalidVideoWithDataSource:dataSource dataUTI:type]) {
        [self showApprovalDialogAfterProcessingVideoURL:url filename:filename];
        return;
    }

    // "Document picker" attachments _SHOULD NOT_ be resized, if possible.
    SignalAttachment *attachment = [SignalAttachment attachmentWithDataSource:dataSource
                                                                      dataUTI:type
                                                                 imageQuality:TSImageQualityOriginal];
    [self showApprovalDialogForAttachment:attachment];
}

#pragma mark - Media Libary

- (void)takePictureOrVideoWithPhotoCapture:(nullable PhotoCapture *)photoCapture
{
    [BenchManager startEventWithTitle:@"Show-Camera" eventId:@"Show-Camera"];
    [self ows_askForCameraPermissions:^(BOOL cameraGranted) {
        if (!cameraGranted) {
            OWSLogWarn(@"camera permission denied.");
            return;
        }
        [self ows_askForMicrophonePermissions:^(BOOL micGranted) {
            if (!micGranted) {
                OWSLogWarn(@"proceeding, though mic permission denied.");
                // We can still continue without mic permissions, but any captured video will
                // be silent.
            }

            SendMediaNavigationController *pickerModal =
                [SendMediaNavigationController showingCameraFirstWithPhotoCapture:photoCapture];
            pickerModal.sendMediaNavDelegate = self;
            pickerModal.modalPresentationStyle = UIModalPresentationOverFullScreen;

            [self dismissKeyBoard];
            [self presentViewController:pickerModal animated:YES completion:nil];
        }];
    }];
}

- (void)chooseFromLibraryAsMedia
{
    OWSAssertIsOnMainThread();

    [self chooseFromLibraryAsDocument:NO];
}

- (void)chooseFromLibraryAsDocument:(BOOL)shouldTreatAsDocument
{
    OWSAssertIsOnMainThread();

    [BenchManager startEventWithTitle:@"Show-Media-Library" eventId:@"Show-Media-Library"];

    [self ows_askForMediaLibraryPermissions:^(BOOL granted) {
        if (!granted) {
            OWSLogWarn(@"Media Library permission denied.");
            return;
        }
        
        SendMediaNavigationController *pickerModal;
        if (shouldTreatAsDocument) {
            pickerModal = [SendMediaNavigationController asMediaDocumentPicker];
        } else {
            pickerModal = [SendMediaNavigationController showingMediaLibraryFirst];
        }
        
        pickerModal.sendMediaNavDelegate = self;
        
        [self dismissKeyBoard];
        [self presentFullScreenViewController:pickerModal animated:YES completion:nil];
    }];
}

#pragma mark - SendMediaNavDelegate

- (void)sendMediaNavDidCancel:(SendMediaNavigationController *)sendMediaNavigationController
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)sendMediaNav:(SendMediaNavigationController *)sendMediaNavigationController
    didApproveAttachments:(NSArray<SignalAttachment *> *)attachments
              messageBody:(nullable MessageBody *)messageBody
{
    [self tryToSendAttachments:attachments messageBody:messageBody];
    [self.inputToolbar clearTextMessageAnimated:NO];

    // we want to already be at the bottom when the user returns, rather than have to watch
    // the new message scroll into view.
    [self scrollToBottomAnimated:NO];

    [self dismissViewControllerAnimated:YES completion:nil];
}

- (nullable MessageBody *)sendMediaNavInitialMessageBody:(SendMediaNavigationController *)sendMediaNavigationController
{
    return self.inputToolbar.messageBody;
}

- (void)sendMediaNav:(SendMediaNavigationController *)sendMediaNavigationController
    didChangeMessageBody:(nullable MessageBody *)messageBody
{
    [self.inputToolbar setMessageBody:messageBody animated:NO];
}

- (NSString *)sendMediaNavApprovalButtonImageName
{
    return @"send-solid-24";
}

- (BOOL)sendMediaNavCanSaveAttachments
{
    return YES;
}

- (nullable NSString *)sendMediaNavTextInputContextIdentifier
{
    return self.textInputContextIdentifier;
}

- (NSArray<NSString *> *)sendMediaNavRecipientNames
{
    return @[ [self.contactsManager displayNameForThreadWithSneakyTransaction:self.thread] ];
}

- (NSArray<SignalServiceAddress *> *)sendMediaNavMentionableAddresses
{
    if (!self.supportsMentions) {
        return @[];
    }

    return self.thread.recipientAddresses;
}

#pragma mark -

- (void)sendContactShare:(ContactShareViewModel *)contactShare
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(contactShare);

    OWSLogVerbose(@"Sending contact share.");

    __block BOOL didAddToProfileWhitelist;
    TSThread *thread = self.thread;
    DatabaseStorageAsyncWrite(SDSDatabaseStorage.shared, ^(SDSAnyWriteTransaction *transaction) {
        didAddToProfileWhitelist = [ThreadUtil addThreadToProfileWhitelistIfEmptyOrPendingRequest:thread
                                                                                      transaction:transaction];

        // TODO - in line with QuotedReply and other message attachments, saving should happen as part of sending
        // preparation rather than duplicated here and in the SAE
        if (contactShare.avatarImage) {
            [contactShare.dbRecord saveAvatarImage:contactShare.avatarImage transaction:transaction];
        }

        [transaction addAsyncCompletion:^{
            TSOutgoingMessage *message = [ThreadUtil enqueueMessageWithContactShare:contactShare.dbRecord
                                                                             thread:thread];
            [self messageWasSent:message];

            if (didAddToProfileWhitelist) {
                [self ensureBannerState];
            }
        }];
    });
}

- (void)showApprovalDialogAfterProcessingVideoURL:(NSURL *)movieURL filename:(nullable NSString *)filename
{
    OWSAssertIsOnMainThread();

    [ModalActivityIndicatorViewController
        presentFromViewController:self
                        canCancel:YES
                  backgroundBlock:^(ModalActivityIndicatorViewController *modalActivityIndicator) {
                      NSError *dataSourceError;
                      id<DataSource> dataSource = [DataSourcePath dataSourceWithURL:movieURL
                                                         shouldDeleteOnDeallocation:NO
                                                                              error:&dataSourceError];
                      if (dataSourceError != nil) {
                          [self showErrorAlertForAttachment:nil];
                          return;
                      }

                      dataSource.sourceFilename = filename;
                      VideoCompressionResult *compressionResult =
                          [SignalAttachment compressVideoAsMp4WithDataSource:dataSource
                                                                     dataUTI:(NSString *)kUTTypeMPEG4];

                      compressionResult.attachmentPromise
                          .then(^(SignalAttachment *attachment) {
                              OWSAssertIsOnMainThread();
                              OWSAssertDebug([attachment isKindOfClass:[SignalAttachment class]]);

                              if (modalActivityIndicator.wasCancelled) {
                                  return;
                              }

                              [modalActivityIndicator dismissWithCompletion:^{
                                  if (!attachment || [attachment hasError]) {
                                      OWSLogError(@"Invalid attachment: %@.",
                                          attachment ? [attachment errorName] : @"Missing data");
                                      [self showErrorAlertForAttachment:attachment];
                                  } else {
                                      [self showApprovalDialogForAttachment:attachment];
                                  }
                              }];
                          })
                          .catch(^(NSError *error) {
                              OWSLogError(@"Error: %@.", error);
                              [self showErrorAlertForAttachment:nil];
                          });
                  }];
}

#pragma mark - Audio

- (void)requestRecordingVoiceMemo
{
    OWSAssertIsOnMainThread();

    NSUUID *voiceMessageUUID = [NSUUID UUID];
    self.voiceMessageUUID = voiceMessageUUID;

    __weak typeof(self) weakSelf = self;
    [self ows_askForMicrophonePermissions:^(BOOL granted) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (strongSelf.voiceMessageUUID != voiceMessageUUID) {
            // This voice message recording has been cancelled
            // before recording could begin.
            return;
        }

        if (granted) {
            [strongSelf startRecordingVoiceMemo];
        } else {
            OWSLogInfo(@"we do not have recording permission.");
            [strongSelf cancelVoiceMemo];
            [self ows_showNoMicrophonePermissionActionSheet];
        }
    }];
}

- (void)startRecordingVoiceMemo
{
    OWSAssertIsOnMainThread();

    OWSLogInfo(@"startRecordingVoiceMemo");

    // Cancel any ongoing audio playback.
    [self.audioAttachmentPlayer stop];
    self.audioAttachmentPlayer = nil;

    NSString *temporaryDirectory = OWSTemporaryDirectory();
    NSString *filename = [NSString stringWithFormat:@"%lld.m4a", [NSDate ows_millisecondTimeStamp]];
    NSString *filepath = [temporaryDirectory stringByAppendingPathComponent:filename];
    NSURL *fileURL = [NSURL fileURLWithPath:filepath];

    // Setup audio session
    BOOL configuredAudio = [self.audioSession startAudioActivity:self.recordVoiceNoteAudioActivity];
    if (!configuredAudio) {
        OWSFailDebug(@"Couldn't configure audio session");
        [self cancelVoiceMemo];
        return;
    }

    NSError *error;
    // Initiate and prepare the recorder
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:fileURL
                                                     settings:@{
                                                         AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                                         AVSampleRateKey : @(44100),
                                                         AVNumberOfChannelsKey : @(2),
                                                         AVEncoderBitRateKey : @(128 * 1024),
                                                     }
                                                        error:&error];
    if (error) {
        OWSFailDebug(@"Couldn't create audioRecorder: %@", error);
        [self cancelVoiceMemo];
        return;
    }

    self.audioRecorder.meteringEnabled = YES;

    if (![self.audioRecorder prepareToRecord]) {
        OWSFailDebug(@"audioRecorder couldn't prepareToRecord.");
        [self cancelVoiceMemo];
        return;
    }

    if (![self.audioRecorder record]) {
        OWSFailDebug(@"audioRecorder couldn't record.");
        [self cancelVoiceMemo];
        return;
    }
}

- (void)endRecordingVoiceMemo
{
    OWSAssertIsOnMainThread();

    OWSLogInfo(@"endRecordingVoiceMemo");

    self.voiceMessageUUID = nil;

    if (!self.audioRecorder) {
        // No voice message recording is in progress.
        // We may be cancelling before the recording could begin.
        OWSLogError(@"Missing audioRecorder");
        return;
    }

    NSTimeInterval durationSeconds = self.audioRecorder.currentTime;

    [self stopRecording];

    const NSTimeInterval kMinimumRecordingTimeSeconds = 1.f;
    if (durationSeconds < kMinimumRecordingTimeSeconds) {
        OWSLogInfo(@"Discarding voice message; too short.");
        self.audioRecorder = nil;

        [self dismissKeyBoard];

        [OWSActionSheets
            showActionSheetWithTitle:
                NSLocalizedString(@"VOICE_MESSAGE_TOO_SHORT_ALERT_TITLE",
                    @"Title for the alert indicating the 'voice message' needs to be held to be held down to record.")
                             message:NSLocalizedString(@"VOICE_MESSAGE_TOO_SHORT_ALERT_MESSAGE",
                                         @"Message for the alert indicating the 'voice message' needs to be held to be "
                                         @"held "
                                         @"down to record.")];
        return;
    }

    NSError *error;
    _Nullable id<DataSource> dataSource = [DataSourcePath dataSourceWithURL:self.audioRecorder.url
                                                 shouldDeleteOnDeallocation:YES
                                                                      error:&error];
    self.audioRecorder = nil;

    if (error != nil) {
        OWSFailDebug(@"Couldn't load audioRecorder data: %@", error);
        self.audioRecorder = nil;
        return;
    }

    NSString *filename = [NSString stringWithFormat:@"%@ %@.%@",
                                   NSLocalizedString(@"VOICE_MESSAGE_FILE_NAME", @"Filename for voice messages."),
                                   [NSDateFormatter localizedStringFromDate:[NSDate new]
                                                                  dateStyle:NSDateFormatterShortStyle
                                                                  timeStyle:NSDateFormatterShortStyle],
                                   @"m4a"];
    [dataSource setSourceFilename:filename];
    SignalAttachment *attachment =
        [SignalAttachment voiceMessageAttachmentWithDataSource:dataSource dataUTI:(NSString *)kUTTypeMPEG4Audio];
    OWSLogVerbose(@"voice memo duration: %f, file size: %zd", durationSeconds, [dataSource dataLength]);
    if (!attachment || [attachment hasError]) {
        OWSLogWarn(@"Invalid attachment: %@.", attachment ? [attachment errorName] : @"Missing data");
        [self showErrorAlertForAttachment:attachment];
    } else {
        [self tryToSendAttachments:@[ attachment ] messageBody:nil];
    }
}

- (void)stopRecording
{
    [self.audioRecorder stop];
    [self.audioSession endAudioActivity:self.recordVoiceNoteAudioActivity];
}

- (void)cancelRecordingVoiceMemo
{
    OWSAssertIsOnMainThread();
    OWSLogDebug(@"cancelRecordingVoiceMemo");

    [self stopRecording];
    self.audioRecorder = nil;
    self.voiceMessageUUID = nil;
}

- (void)setAudioRecorder:(nullable AVAudioRecorder *)audioRecorder
{
    // Prevent device from sleeping while recording a voice message.
    if (audioRecorder) {
        [DeviceSleepManager.shared addBlockWithBlockObject:audioRecorder];
    } else if (_audioRecorder) {
        [DeviceSleepManager.shared removeBlockWithBlockObject:_audioRecorder];
    }

    _audioRecorder = audioRecorder;
}

#pragma mark Accessory View

- (void)cameraButtonPressed
{
    OWSAssertIsOnMainThread();

    [self takePictureOrVideoWithPhotoCapture:nil];
}

- (void)cameraButtonPressedWithPhotoCapture:(nullable PhotoCapture *)photoCapture
{
    OWSAssertIsOnMainThread();

    [self takePictureOrVideoWithPhotoCapture:photoCapture];
}

- (void)galleryButtonPressed
{
    OWSAssertIsOnMainThread();

    [self chooseFromLibraryAsMedia];
}

- (void)gifButtonPressed
{
    OWSAssertIsOnMainThread();

    [self showGifPicker];
}

- (void)fileButtonPressed
{
    OWSAssertIsOnMainThread();

    [self showAttachmentDocumentPickerMenu];
}

- (void)contactButtonPressed
{
    OWSAssertIsOnMainThread();

    [self chooseContactForSending];
}

- (void)locationButtonPressed
{
    OWSAssertIsOnMainThread();

    LocationPicker *locationPicker = [LocationPicker new];
    locationPicker.delegate = self;

    OWSNavigationController *navigationController =
        [[OWSNavigationController alloc] initWithRootViewController:locationPicker];
    [self dismissKeyBoard];
    [self presentFormSheetViewController:navigationController animated:YES completion:nil];
}

- (void)didSelectRecentPhotoWithAsset:(PHAsset *)asset attachment:(SignalAttachment *)attachment
{
    OWSAssertIsOnMainThread();

    [self dismissKeyBoard];

    SendMediaNavigationController *pickerModal =
        [SendMediaNavigationController showingApprovalWithPickedLibraryMediaAsset:asset
                                                                       attachment:attachment
                                                                         delegate:self];

    [self presentFullScreenViewController:pickerModal animated:true completion:nil];
}

- (void)setLastSortIdMarkedRead:(uint64_t)lastSortIdMarkedRead
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.isMarkingAsRead);
    _lastSortIdMarkedRead = lastSortIdMarkedRead;
}

- (void)markVisibleMessagesAsRead
{
    OWSAssertIsOnMainThread();
    if (self.presentedViewController) {
        return;
    }
    if (OWSWindowManager.shared.shouldShowCallView) {
        return;
    }
    if (self.navigationController.topViewController != self) {
        return;
    }

    // Always clear the thread unread flag
    [self clearThreadUnreadFlagIfNecessary];

    uint64_t lastVisibleSortId = [self lastVisibleSortId];
    BOOL isShowingUnreadMessage = (lastVisibleSortId > [self lastSortIdMarkedRead]);
    if (!self.isMarkingAsRead && isShowingUnreadMessage) {
        self.isMarkingAsRead = YES;
        [self clearUnreadMessageFlagIfNecessary];

        [BenchManager benchAsyncWithTitle:@"marking as read"
                                    block:^(void (^_Nonnull benchCompletion)(void)) {
                                        [[OWSReadReceiptManager shared]
                                            markAsReadLocallyBeforeSortId:lastVisibleSortId
                                                                   thread:self.thread
                                                 hasPendingMessageRequest:self.threadViewModel.hasPendingMessageRequest
                                                               completion:^{
                                                                   OWSAssertIsOnMainThread();
                                                                   [self setLastSortIdMarkedRead:lastVisibleSortId];
                                                                   self.isMarkingAsRead = NO;

                                                                   // If -markVisibleMessagesAsRead wasn't invoked on a
                                                                   // timer, we'd want to double check that the current
                                                                   // -lastVisibleSortId hasn't incremented since we
                                                                   // started the read receipt request. But we have a
                                                                   // timer, so if it has changed, this method will just
                                                                   // be reinvoked in <100ms.

                                                                   benchCompletion();
                                                               }];
                                    }];
    }
}

- (void)conversationSettingsDidUpdate
{
    OWSAssertIsOnMainThread();

    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        // We updated the group, so if there was a pending message request we should accept it.
        [ThreadUtil addThreadToProfileWhitelistIfEmptyOrPendingRequest:self.thread transaction:transaction];
    });
}

- (void)popKeyBoard
{
    [self.inputToolbar beginEditingMessage];
}

- (void)dismissKeyBoard
{
    [self.inputToolbar endEditingMessage];
    [self.inputToolbar clearDesiredKeyboard];
}

#pragma mark Drafts

- (void)loadDraftInCompose
{
    OWSAssertIsOnMainThread();

    __block MessageBody *_Nullable draft;
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        draft = [self.thread currentDraftWithTransaction:transaction];
    }];
    OWSAssertDebug(self.inputToolbar != nil);
    OWSAssertDebug(self.inputToolbar.messageBody.text.length == 0);
    [self.inputToolbar setMessageBody:draft animated:NO];
}

- (void)saveDraft
{
    if (!self.inputToolbar.hidden) {
        TSThread *thread = self.thread;
        MessageBody *currentDraft = [self.inputToolbar messageBody];

        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [thread updateWithDraft:currentDraft transaction:transaction];
        });
    }
}

#pragma mark 3D Touch Preview Actions

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems
{
    return @[];
}

#pragma mark - ConversationHeaderViewDelegate

- (void)didTapConversationHeaderView:(ConversationHeaderView *)conversationHeaderView
{
    [self showConversationSettings];
}

#ifdef USE_DEBUG_UI
- (void)navigationTitleLongPressed:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        [DebugUITableViewController presentDebugUIForThread:self.thread fromViewController:self];
    }
}
#endif

#pragma mark - ConversationInputTextViewDelegate

- (void)textViewDidChange:(UITextView *)textView
{
    if (textView.text.length > 0) {
        [self.typingIndicators didStartTypingOutgoingInputInThread:self.thread];
    }
}

- (void)inputTextViewSendMessagePressed
{
    [self sendButtonPressed];
}

- (void)didPasteAttachment:(SignalAttachment *_Nullable)attachment
{
    // If the thing we pasted is sticker-like, send it immediately
    // and render it borderless.
    if (attachment.isBorderless) {
        [self tryToSendAttachments:@[ attachment ] messageBody:nil];
    } else {
        [self showApprovalDialogForAttachment:attachment];
    }
}

- (void)showApprovalDialogForAttachment:(SignalAttachment *_Nullable)attachment
{
    if (attachment == nil) {
        OWSFailDebug(@"attachment was unexpectedly nil");
        [self showErrorAlertForAttachment:nil];
        return;
    }
    [self showApprovalDialogForAttachments:@[ attachment ]];
}

- (void)showApprovalDialogForAttachments:(NSArray<SignalAttachment *> *)attachments
{
    OWSNavigationController *modal =
        [AttachmentApprovalViewController wrappedInNavControllerWithAttachments:attachments
                                                             initialMessageBody:self.inputToolbar.messageBody
                                                               approvalDelegate:self];

    [self presentFullScreenViewController:modal animated:YES completion:nil];
}

- (void)tryToSendAttachments:(NSArray<SignalAttachment *> *)attachments messageBody:(MessageBody *_Nullable)messageBody
{
    DispatchMainThreadSafe(^{
        __weak ConversationViewController *weakSelf = self;
        if ([self isBlockedConversation]) {
            [self showUnblockConversationUI:^(BOOL isBlocked) {
                if (!isBlocked) {
                    [weakSelf tryToSendAttachments:attachments messageBody:messageBody];
                }
            }];
            return;
        }

        BOOL didShowSNAlert =
            [self showSafetyNumberConfirmationIfNecessaryWithConfirmationText:[SafetyNumberStrings confirmSendButton]
                                                                   completion:^(BOOL didConfirmIdentity) {
                                                                       if (didConfirmIdentity) {
                                                                           [weakSelf tryToSendAttachments:attachments
                                                                                              messageBody:messageBody];
                                                                       }
                                                                   }];
        if (didShowSNAlert) {
            return;
        }

        for (SignalAttachment *attachment in attachments) {
            if ([attachment hasError]) {
                OWSLogWarn(@"Invalid attachment: %@.", attachment ? [attachment errorName] : @"Missing data");
                [self showErrorAlertForAttachment:attachment];
                return;
            }
        }

        BOOL didAddToProfileWhitelist =
            [ThreadUtil addThreadToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction:self.thread];

        __block TSOutgoingMessage *message;
        [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *_Nonnull transaction) {
            message = [ThreadUtil enqueueMessageWithBody:messageBody
                                        mediaAttachments:attachments
                                                  thread:self.thread
                                        quotedReplyModel:self.inputToolbar.quotedReply
                                        linkPreviewDraft:nil
                                             transaction:transaction];
        }];

        [self messageWasSent:message];

        if (didAddToProfileWhitelist) {
            [self ensureBannerState];
        }
    });
}

- (void)applyTheme
{
    OWSAssertIsOnMainThread();

    // make sure toolbar extends below iPhoneX home button.
    self.view.backgroundColor = Theme.toolbarBackgroundColor;
    self.collectionView.backgroundColor = Theme.backgroundColor;

    [self updateNavigationTitle];
    [self updateNavigationBarSubtitleLabel];

    [self createInputToolbar];
    [self updateInputToolbarLayout];
    [self updateBarButtonItems];

    [self reloadData];

    // Re-styling the message actions is tricky,
    // since this happens rarely just dismiss
    [self dismissMessageActionsAnimated:NO];
    [self dismissReactionsDetailSheetAnimated:NO];
}

- (void)reloadData
{
    if (self.viewHasEverAppeared) {
        // [UICollectionView reloadData] sometimes has no effect.
        // This might be a regression in iOS 13? reloadSections
        // does not appear to have the same issue.
        [UIView performWithoutAnimation:^{
            [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
            [self.collectionView.collectionViewLayout invalidateLayout];
        }];
    } else {
        // Don't reload sections until the view has appeared and the
        // collection view has loaded.
        [self.collectionView reloadData];
        [self.collectionView.collectionViewLayout invalidateLayout];
    }
}

- (void)createInputToolbar
{
    MessageBody *_Nullable existingDraft;
    if (_inputToolbar != nil) {
        existingDraft = _inputToolbar.messageBody;
    }

    _inputToolbar = [[ConversationInputToolbar alloc] initWithConversationStyle:self.conversationStyle];
    self.inputToolbar.inputToolbarDelegate = self;
    self.inputToolbar.inputTextViewDelegate = self;
    self.inputToolbar.mentionDelegate = self;
    [self.inputToolbar setMessageBody:existingDraft animated:NO];
    SET_SUBVIEW_ACCESSIBILITY_IDENTIFIER(self, _inputToolbar);
    // reloadBottomBar is expensive and we need to avoid it while
    // initially configuring the view. viewWillAppear() will call
    // reloadBottomBar(). After viewWillAppear(), we need to call
    // reloadBottomBar() to reflect changes in the theme.
    if (self.hasViewWillAppearOccurred) {
        [self reloadBottomBar];
    }
}

#pragma mark - AttachmentApprovalViewControllerDelegate

- (void)attachmentApprovalDidAppear:(AttachmentApprovalViewController *)attachmentApproval
{
    // no-op
}

- (void)attachmentApproval:(AttachmentApprovalViewController *)attachmentApproval
     didApproveAttachments:(NSArray<SignalAttachment *> *)attachments
               messageBody:(MessageBody *_Nullable)messageBody
{
    [self tryToSendAttachments:attachments messageBody:messageBody];
    [self.inputToolbar clearTextMessageAnimated:NO];
    [self dismissViewControllerAnimated:YES completion:nil];

    // We always want to scroll to the bottom of the conversation after the local user
    // sends a message.  Normally, this is taken care of in yapDatabaseModified:, but
    // we don't listen to db modifications when this view isn't visible, i.e. when the
    // attachment approval view is presented.
    [self scrollToBottomAnimated:NO];
}

- (void)attachmentApprovalDidCancel:(AttachmentApprovalViewController *)attachmentApproval
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)attachmentApproval:(AttachmentApprovalViewController *)attachmentApproval
      didChangeMessageBody:(nullable MessageBody *)newMessageBody
{
    [self.inputToolbar setMessageBody:newMessageBody animated:NO];
}

- (nullable NSString *)attachmentApprovalTextInputContextIdentifier
{
    return self.textInputContextIdentifier;
}

- (NSArray<NSString *> *)attachmentApprovalRecipientNames
{
    return @[ [self.contactsManager displayNameForThreadWithSneakyTransaction:self.thread] ];
}

- (NSArray<SignalServiceAddress *> *)attachmentApprovalMentionableAddresses
{
    if (!self.supportsMentions) {
        return @[];
    }

    return self.thread.recipientAddresses;
}

#pragma mark -

- (void)showErrorAlertForAttachment:(SignalAttachment *_Nullable)attachment
{
    OWSAssertDebug(attachment == nil || [attachment hasError]);

    NSString *errorMessage
        = (attachment ? [attachment localizedErrorDescription] : [SignalAttachment missingDataErrorMessage]);

    OWSLogError(@": %@", errorMessage);

    [OWSActionSheets showActionSheetWithTitle:NSLocalizedString(@"ATTACHMENT_ERROR_ALERT_TITLE",
                                                  @"The title of the 'attachment error' alert.")
                                      message:errorMessage];
}

- (CGFloat)safeContentHeight
{
    // Don't use self.collectionView.contentSize.height as the collection view's
    // content size might not be set yet.
    //
    // We can safely call prepareLayout to ensure the layout state is up-to-date
    // since our layout uses a dirty flag internally to debounce redundant work.
    [self.layout prepareLayout];
    return [self.collectionView.collectionViewLayout collectionViewContentSize].height;
}

#pragma mark - UIScrollViewDelegate

- (void)updateLastKnownDistanceFromBottom
{
    // Never update the lastKnownDistanceFromBottom,
    // if we're presenting the message actions which
    // temporarily meddles with the content insets.
    if (!self.isPresentingMessageActions) {
        self.lastKnownDistanceFromBottom = @(self.safeDistanceFromBottom);
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Constantly try to update the lastKnownDistanceFromBottom.
    [self updateLastKnownDistanceFromBottom];

    [self configureScrollDownButtons];

    [self scheduleScrollUpdateTimer];
}

- (void)scheduleScrollUpdateTimer
{
    [self.scrollUpdateTimer invalidate];
    self.scrollUpdateTimer = [NSTimer weakScheduledTimerWithTimeInterval:0.1f
                                                                  target:self
                                                                selector:@selector(scrollUpdateTimerDidFire)
                                                                userInfo:nil
                                                                 repeats:NO];
}

- (void)scrollUpdateTimerDidFire
{
    if (!self.viewHasEverAppeared) {
        return;
    }

    [self autoLoadMoreIfNecessary];
    [self saveLastVisibleSortIdAndOnScreenPercentage];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.userHasScrolled = YES;
    self.isUserScrolling = YES;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)willDecelerate
{
    if (!self.isUserScrolling) {
        return;
    }

    self.isUserScrolling = NO;

    if (willDecelerate) {
        self.isWaitingForDeceleration = willDecelerate;
    } else {
        [self scheduleScrollUpdateTimer];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (!self.isWaitingForDeceleration) {
        return;
    }

    self.isWaitingForDeceleration = NO;

    [self scheduleScrollUpdateTimer];
}

#pragma mark - ConversationSettingsViewDelegate

- (void)resendGroupUpdateForErrorMessage:(TSErrorMessage *)message
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug([self.thread isKindOfClass:[TSGroupThread class]]);
    OWSAssertDebug(message);

    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    [GroupManager sendGroupUpdateMessageObjcWithThread:groupThread].thenOn(
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            OWSLogInfo(@"Group updated, removing group creation error.");

            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                [message anyRemoveWithTransaction:transaction];
            });
        });
}

- (void)conversationColorWasUpdated
{
    [self.conversationStyle updateProperties];
    [self.headerView updateAvatar];
    [self resetContentAndLayoutWithSneakyTransaction];
}

- (void)popAllConversationSettingsViewsWithCompletion:(void (^_Nullable)(void))completionBlock
{
    if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:YES
                                                         completion:^{
                                                             [self.navigationController
                                                                 popToViewController:self
                                                                            animated:YES
                                                                          completion:completionBlock];
                                                         }];
    } else {
        [self.navigationController popToViewController:self animated:YES completion:completionBlock];
    }
}

#pragma mark - Conversation Search

- (void)setUiMode:(ConversationUIMode)newValue
{
    ConversationUIMode oldValue = _uiMode;
    if (newValue == oldValue) {
        return;
    }

    _uiMode = newValue;
    [self uiModeDidChangeWithOldValue:oldValue];
}

#pragma mark - Conversation Search

- (void)conversationSettingsDidRequestConversationSearch
{
    self.uiMode = ConversationUIMode_Search;
    [self popAllConversationSettingsViewsWithCompletion:^{
        // This delay is unfortunate, but without it, self.searchController.uiSearchController.searchBar
        // isn't yet ready to become first responder. Presumably we're still mid transition.
        // A hardcorded constant like this isn't great because it's either too slow, making our users
        // wait, or too fast, and fails to wait long enough to be ready to become first responder.
        // Luckily in this case the stakes aren't catastrophic. In the case that we're too aggressive
        // the user will just have to manually tap into the search field before typing.

        // Leaving this assert in as proof that we're not ready to become first responder yet.
        // If this assert fails, *great* maybe we can get rid of this delay.
        OWSAssertDebug(![self.searchController.uiSearchController.searchBar canBecomeFirstResponder]);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.searchController.uiSearchController.searchBar becomeFirstResponder];
        });
    }];
}

#pragma mark ConversationSearchControllerDelegate

- (void)didDismissSearchController:(UISearchController *)searchController
{
    OWSLogVerbose(@"");
    OWSAssertIsOnMainThread();
    // This method is called not only when the user taps "cancel" in the searchController, but also
    // called when the searchController was dismissed because we switched to another uiMode, like
    // "selection". We only want to revert to "normal" in the former case - when the user tapped
    // "cancel" in the search controller. Otherwise, if we're already in another mode, like
    // "selection", we want to stay in that mode.
    if (self.uiMode == ConversationUIMode_Search) {
        self.uiMode = ConversationUIMode_Normal;
    }
}

- (void)conversationSearchController:(ConversationSearchController *)conversationSearchController
              didUpdateSearchResults:(nullable ConversationScreenSearchResultSet *)conversationScreenSearchResultSet
{
    OWSAssertIsOnMainThread();

    OWSLogVerbose(@"conversationScreenSearchResultSet: %@", conversationScreenSearchResultSet.debugDescription);
    self.lastSearchedText = conversationScreenSearchResultSet.searchText;
    [UIView performWithoutAnimation:^{
        [self.collectionView reloadItemsAtIndexPaths:self.collectionView.indexPathsForVisibleItems];
    }];
    if (conversationScreenSearchResultSet) {
        [BenchManager completeEventWithEventId:self.lastSearchedText];
    }
}

- (void)conversationSearchController:(ConversationSearchController *)conversationSearchController
                  didSelectMessageId:(NSString *)messageId
{
    OWSLogDebug(@"messageId: %@", messageId);
    [self scrollToInteractionWithUniqueId:messageId
                       onScreenPercentage:1
                                 position:ScrollToCenterIfNotEntirelyOnScreen
                                 animated:YES];
    [BenchManager completeEventWithEventId:[NSString stringWithFormat:@"Conversation Search Nav: %@", messageId]];
}

#pragma mark - ConversationViewLayoutDelegate

- (BOOL)shouldHideCollectionViewContent
{
    // Avoid layout and measurement during view configuration.
    return !self.hasViewWillAppearOccurred;
}

- (NSArray<id<ConversationViewLayoutItem>> *)layoutItems
{
    if (self.shouldHideCollectionViewContent) {
        return 0;
    }

    return self.viewItems;
}

- (CGFloat)layoutHeaderHeight
{
    return (self.showLoadOlderHeader ? LoadMoreMessagesView.fixedHeight : 0.f);
}

- (CGFloat)layoutFooterHeight
{
    return (self.showLoadNewerHeader ? LoadMoreMessagesView.fixedHeight : 0.f);
}

#pragma mark - ConversationInputToolbarDelegate

- (void)sendButtonPressed
{
    [BenchManager startEventWithTitle:@"Send Message" eventId:@"message-send"];
    [BenchManager startEventWithTitle:@"Send Message milestone: clearTextMessageAnimated completed"
                              eventId:@"fromSendUntil_clearTextMessageAnimated"];
    [BenchManager startEventWithTitle:@"Send Message milestone: toggleDefaultKeyboard completed"
                              eventId:@"fromSendUntil_toggleDefaultKeyboard"];

    [self.inputToolbar acceptAutocorrectSuggestion];
    [self tryToSendTextMessage:self.inputToolbar.messageBody updateKeyboardState:YES];
}

- (void)tryToSendTextMessage:(MessageBody *)messageBody updateKeyboardState:(BOOL)updateKeyboardState
{
    OWSAssertIsOnMainThread();

    __weak ConversationViewController *weakSelf = self;
    if ([self isBlockedConversation]) {
        [self showUnblockConversationUI:^(BOOL isBlocked) {
            if (!isBlocked) {
                [weakSelf tryToSendTextMessage:messageBody updateKeyboardState:NO];
            }
        }];
        return;
    }

    BOOL didShowSNAlert =
        [self showSafetyNumberConfirmationIfNecessaryWithConfirmationText:[SafetyNumberStrings confirmSendButton]
                                                               completion:^(BOOL didConfirmIdentity) {
                                                                   if (didConfirmIdentity) {
                                                                       [weakSelf resetVerificationStateToDefault];
                                                                       [weakSelf tryToSendTextMessage:messageBody
                                                                                  updateKeyboardState:NO];
                                                                   }
                                                               }];
    if (didShowSNAlert) {
        return;
    }

    if (messageBody.text.length < 1) {
        return;
    }

    BOOL didAddToProfileWhitelist =
        [ThreadUtil addThreadToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction:self.thread];
    __block TSOutgoingMessage *message;

    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        message = [ThreadUtil enqueueMessageWithBody:messageBody
                                              thread:self.thread
                                    quotedReplyModel:self.inputToolbar.quotedReply
                                    linkPreviewDraft:self.inputToolbar.linkPreviewDraft
                                         transaction:transaction];
    }];
    [self.conversationViewModel clearUnreadMessagesIndicator];
    [self.conversationViewModel appendUnsavedOutgoingTextMessage:message];
    [self messageWasSent:message];

    // Clearing the text message is a key part of the send animation.
    // It takes 10-15ms, but we do it inline rather than dispatch async
    // since the send can't feel "complete" without it.
    [BenchManager benchWithTitle:@"clearTextMessageAnimated"
                           block:^{
                               [self.inputToolbar clearTextMessageAnimated:YES];
                           }];
    [BenchManager completeEventWithEventId:@"fromSendUntil_clearTextMessageAnimated"];

    dispatch_async(dispatch_get_main_queue(), ^{
        // After sending we want to return from the numeric keyboard to the
        // alphabetical one. Because this is so slow (40-50ms), we prefer it
        // happens async, after any more essential send UI work is done.
        [BenchManager benchWithTitle:@"toggleDefaultKeyboard"
                               block:^{
                                   [self.inputToolbar toggleDefaultKeyboard];
                               }];
        [BenchManager completeEventWithEventId:@"fromSendUntil_toggleDefaultKeyboard"];
    });

    TSThread *thread = self.thread;
    DatabaseStorageAsyncWrite(self.databaseStorage,
        ^(SDSAnyWriteTransaction *transaction) { [thread updateWithDraft:nil transaction:transaction]; });

    if (didAddToProfileWhitelist) {
        [self ensureBannerState];
    }
}

- (void)sendSticker:(StickerInfo *)stickerInfo
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(stickerInfo);

    OWSLogVerbose(@"Sending sticker.");

    TSOutgoingMessage *message = [ThreadUtil enqueueMessageWithInstalledSticker:stickerInfo thread:self.thread];
    [self messageWasSent:message];
}

- (void)presentManageStickersView
{
    OWSAssertIsOnMainThread();

    ManageStickersViewController *manageStickersView = [ManageStickersViewController new];
    OWSNavigationController *navigationController =
        [[OWSNavigationController alloc] initWithRootViewController:manageStickersView];
    [self presentFormSheetViewController:navigationController animated:YES completion:nil];
}

- (void)updateToolbarHeight
{
    [self updateInputAccessoryPlaceholderHeight];

    // Normally, the keyboard frame change triggered by updating
    // the bottom bar height will cause the content insets to reload.
    // However, if the toolbar updates while it's not the first
    // responder (e.g. dismissing a quoted reply) we need to preserve
    // our constraints here.
    if (!self.inputToolbar.isInputViewFirstResponder) {
        [self updateContentInsetsAnimated:NO];
    }
}

- (void)voiceMemoGestureDidStart
{
    OWSAssertIsOnMainThread();

    OWSLogInfo(@"voiceMemoGestureDidStart");

    const CGFloat kIgnoreMessageSendDoubleTapDurationSeconds = 2.f;
    if (self.lastMessageSentDate &&
        [[NSDate new] timeIntervalSinceDate:self.lastMessageSentDate] < kIgnoreMessageSendDoubleTapDurationSeconds) {
        // If users double-taps the message send button, the second tap can look like a
        // very short voice message gesture.  We want to ignore such gestures.
        [self.inputToolbar cancelVoiceMemoIfNecessary];
        [self.inputToolbar hideVoiceMemoUI:NO];
        [self cancelRecordingVoiceMemo];
        return;
    }

    [self.inputToolbar showVoiceMemoUI];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    [self requestRecordingVoiceMemo];
}

- (void)voiceMemoGestureDidComplete
{
    OWSAssertIsOnMainThread();

    OWSLogInfo(@"");

    [self.inputToolbar hideVoiceMemoUI:YES];
    [self endRecordingVoiceMemo];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (void)voiceMemoGestureDidLock
{
    OWSAssertIsOnMainThread();
    OWSLogInfo(@"");

    [self.inputToolbar lockVoiceMemoUI];
}

- (void)voiceMemoGestureDidCancel
{
    OWSAssertIsOnMainThread();

    OWSLogInfo(@"voiceMemoGestureDidCancel");

    [self.inputToolbar hideVoiceMemoUI:NO];
    [self cancelRecordingVoiceMemo];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (void)voiceMemoGestureDidUpdateCancelWithRatioComplete:(CGFloat)cancelAlpha
{
    OWSAssertIsOnMainThread();

    [self.inputToolbar setVoiceMemoUICancelAlpha:cancelAlpha];
}

- (void)cancelVoiceMemo
{
    OWSAssertIsOnMainThread();

    [self.inputToolbar cancelVoiceMemoIfNecessary];
    [self.inputToolbar hideVoiceMemoUI:NO];
    [self cancelRecordingVoiceMemo];
}

#pragma mark - Database Observation

- (void)setIsViewVisible:(BOOL)isViewVisible
{
    _isViewVisible = isViewVisible;

    [self updateCellsVisible];
}

- (void)updateCellsVisible
{
    BOOL isAppInBackground = CurrentAppContext().isInBackground;
    BOOL isCellVisible = self.isViewVisible && !isAppInBackground;
    for (ConversationViewCell *cell in self.collectionView.visibleCells) {
        cell.isCellVisible = isCellVisible;
    }
}

#pragma mark - ConversationCollectionViewDelegate

- (void)collectionViewWillChangeSizeFrom:(CGSize)oldSize to:(CGSize)newSize
{
    OWSAssertIsOnMainThread();
}

- (void)collectionViewDidChangeSizeFrom:(CGSize)oldSize to:(CGSize)newSize
{
    OWSAssertIsOnMainThread();

    if (oldSize.width != newSize.width) {
        [self resetForSizeOrOrientationChange];
    }

    [self configureScrollDownButtons];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.shouldHideCollectionViewContent) {
        return 0;
    }

    return (NSInteger)self.viewItems.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<ConversationViewItem> _Nullable viewItem = [self viewItemForIndex:indexPath.row];
    ConversationViewCell *cell = [viewItem dequeueCellForCollectionView:self.collectionView indexPath:indexPath];
    if (!cell) {
        OWSFailDebug(@"Could not dequeue cell.");
        return cell;
    }
    cell.viewItem = viewItem;
    cell.delegate = self;
    if ([cell isKindOfClass:[OWSMessageCell class]]) {
        OWSMessageCell *messageCell = (OWSMessageCell *)cell;
        messageCell.messageBubbleView.delegate = self;
        messageCell.messageStickerView.delegate = self;
        messageCell.messageViewOnceView.delegate = self;
    }
    cell.conversationStyle = self.conversationStyle;

    [cell loadForDisplay];
    [cell layoutIfNeeded];

    // This must happen after load for display, since the tap
    // gesture doesn't get added to a view until this point.
    if ([cell isKindOfClass:[OWSMessageCell class]]) {
        OWSMessageCell *messageCell = (OWSMessageCell *)cell;
        [self.tapGestureRecognizer requireGestureRecognizerToFail:messageCell.messageViewTapGestureRecognizer];
        [self.tapGestureRecognizer requireGestureRecognizerToFail:messageCell.contentViewTapGestureRecognizer];

        [messageCell.messageViewTapGestureRecognizer requireGestureRecognizerToFail:self.panGestureRecognizer];
        [messageCell.contentViewTapGestureRecognizer requireGestureRecognizerToFail:self.panGestureRecognizer];
    }

#ifdef DEBUG
    // TODO: Confirm with nancy if this will work.
    NSString *cellName = [NSString stringWithFormat:@"interaction.%@", NSUUID.UUID.UUIDString];
    if (viewItem.hasBodyText && viewItem.displayableBodyText.displayAttributedText.length > 0) {
        NSString *textForId =
            [viewItem.displayableBodyText.displayAttributedText.string stringByReplacingOccurrencesOfString:@" "
                                                                                                 withString:@"_"];
        cellName = [NSString stringWithFormat:@"message.text.%@", textForId];
    } else if (viewItem.stickerInfo) {
        cellName = [NSString stringWithFormat:@"message.sticker.%@", [viewItem.stickerInfo asKey]];
    }
    cell.accessibilityIdentifier = ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, cellName);
#endif

    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:UICollectionElementKindSectionHeader] ||
        [kind isEqualToString:UICollectionElementKindSectionFooter]) {
        LoadMoreMessagesView *loadMoreView =
            [self.collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                    withReuseIdentifier:LoadMoreMessagesView.reuseIdentifier
                                                           forIndexPath:indexPath];
        [loadMoreView configureForDisplay];
        return loadMoreView;
    }
    OWSFailDebug(@"unexpected supplementaryElement: %@", kind);
    return [UICollectionReusableView new];
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
    OWSAssertDebug([cell isKindOfClass:[ConversationViewCell class]]);

    ConversationViewCell *conversationViewCell = (ConversationViewCell *)cell;
    conversationViewCell.isCellVisible = YES;
}

- (void)collectionView:(UICollectionView *)collectionView
    didEndDisplayingCell:(nonnull UICollectionViewCell *)cell
      forItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    OWSAssertDebug([cell isKindOfClass:[ConversationViewCell class]]);

    ConversationViewCell *conversationViewCell = (ConversationViewCell *)cell;
    conversationViewCell.isCellVisible = NO;
}

// We use this hook to ensure scroll state continuity.  As the collection
// view's content size changes, we want to keep the same cells in view.
- (CGPoint)collectionView:(UICollectionView *)collectionView
    targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
{
    if (self.isPresentingMessageActions) {
        NSValue *_Nullable contentOffset = [self contentOffsetForMessageActionInteraction];
        if (contentOffset != nil) {
            return contentOffset.CGPointValue;
        }
    }

    if (self.scrollContinuity == kScrollContinuityBottom && self.lastKnownDistanceFromBottom
        && CurrentAppContext().isAppForegroundAndActive) {
        NSValue *_Nullable contentOffset =
            [self contentOffsetForLastKnownDistanceFromBottom:self.lastKnownDistanceFromBottom.floatValue];
        if (contentOffset) {
            proposedContentOffset = contentOffset.CGPointValue;
        }
    }

    return proposedContentOffset;
}

// We use this hook to ensure scroll state continuity.  As the collection
// view's content size changes, we want to keep the same cells in view.
- (nullable NSValue *)contentOffsetForLastKnownDistanceFromBottom:(CGFloat)lastKnownDistanceFromBottom
{
    // Adjust the content offset to reflect the "last known" distance
    // from the bottom of the content.
    CGFloat contentOffsetYBottom = self.maxContentOffsetY;
    CGFloat contentOffsetY = contentOffsetYBottom - MAX(0, lastKnownDistanceFromBottom);
    CGFloat minContentOffsetY = -self.collectionView.safeAreaInsets.top;
    contentOffsetY = MAX(minContentOffsetY, contentOffsetY);
    return [NSValue valueWithCGPoint:CGPointMake(0, contentOffsetY)];
}

#pragma mark - Scroll State

- (BOOL)isScrolledToBottom
{
    CGFloat distanceFromBottom = self.safeDistanceFromBottom;
    const CGFloat kIsAtBottomTolerancePts = 5;
    BOOL isScrolledToBottom = distanceFromBottom <= kIsAtBottomTolerancePts;
    return isScrolledToBottom;
}

- (CGFloat)safeDistanceFromBottom
{
    // This is a bit subtle.
    //
    // The _wrong_ way to determine if we're scrolled to the bottom is to
    // measure whether the collection view's content is "near" the bottom edge
    // of the collection view.  This is wrong because the collection view
    // might not have enough content to fill the collection view's bounds
    // _under certain conditions_ (e.g. with the keyboard dismissed).
    //
    // What we're really interested in is something a bit more subtle:
    // "Is the scroll view scrolled down as far as it can, "at rest".
    //
    // To determine that, we find the appropriate "content offset y" if
    // the scroll view were scrolled down as far as possible.  IFF the
    // actual "content offset y" is "near" that value, we return YES.
    CGFloat maxContentOffsetY = self.maxContentOffsetY;
    CGFloat distanceFromBottom = maxContentOffsetY - self.collectionView.contentOffset.y;
    return distanceFromBottom;
}

- (CGFloat)maxContentOffsetY
{
    CGFloat contentHeight = self.safeContentHeight;

    UIEdgeInsets adjustedContentInset = self.collectionView.adjustedContentInset;
    // Note the usage of MAX() to handle the case where there isn't enough
    // content to fill the collection view at its current size.
    CGFloat maxContentOffsetY = contentHeight + adjustedContentInset.bottom - self.collectionView.bounds.size.height;
    return maxContentOffsetY;
}

#pragma mark - ContactsPickerDelegate

- (void)contactsPickerDidCancel:(ContactsPicker *)contactsPicker
{
    OWSLogDebug(@"");
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactsPicker:(ContactsPicker *)contactsPicker contactFetchDidFail:(NSError *)error
{
    OWSLogDebug(@"with error %@", error);
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactsPicker:(ContactsPicker *)contactsPicker didSelectContact:(Contact *)contact
{
    OWSAssertDebug(contact);
    OWSAssertDebug(contact.cnContactId);

    CNContact *_Nullable cnContact = [self.contactsManager cnContactWithId:contact.cnContactId];
    if (!cnContact) {
        OWSFailDebug(@"Could not load system contact.");
        return;
    }

    OWSLogDebug(@"with contact: %@", contact);

    OWSContact *_Nullable contactShareRecord = [OWSContacts contactForSystemContact:cnContact];
    if (!contactShareRecord) {
        OWSFailDebug(@"Could not convert system contact.");
        return;
    }

    BOOL isProfileAvatar = NO;
    __block NSData *_Nullable avatarImageData = [self.contactsManager avatarDataForCNContactId:cnContact.identifier];
    for (SignalServiceAddress *address in contact.registeredAddresses) {
        if (avatarImageData) {
            break;
        }
        avatarImageData = [self.contactsManager profileImageDataForAddressWithSneakyTransaction:address];
        if (avatarImageData) {
            isProfileAvatar = YES;
        }
    }
    contactShareRecord.isProfileAvatar = isProfileAvatar;

    ContactShareViewModel *contactShare = [[ContactShareViewModel alloc] initWithContactShareRecord:contactShareRecord
                                                                                    avatarImageData:avatarImageData];

    ContactShareApprovalViewController *approveContactShare =
        [[ContactShareApprovalViewController alloc] initWithContactShare:contactShare];
    approveContactShare.delegate = self;
    OWSAssertDebug(contactsPicker.navigationController);
    [contactsPicker.navigationController pushViewController:approveContactShare animated:YES];
}

- (void)contactsPicker:(ContactsPicker *)contactsPicker didSelectMultipleContacts:(NSArray<Contact *> *)contacts
{
    OWSFailDebug(@"with contacts: %@", contacts);
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)contactsPicker:(ContactsPicker *)contactsPicker shouldSelectContact:(Contact *)contact
{
    // Any reason to preclude contacts?
    return YES;
}

#pragma mark - ContactShareApprovalViewControllerDelegate

- (void)approveContactShare:(ContactShareApprovalViewController *)approveContactShare
     didApproveContactShare:(ContactShareViewModel *)contactShare
{
    OWSLogInfo(@"");

    [self dismissViewControllerAnimated:YES
                             completion:^{
                                 [self sendContactShare:contactShare];
                             }];
}

- (void)approveContactShare:(ContactShareApprovalViewController *)approveContactShare
      didCancelContactShare:(ContactShareViewModel *)contactShare
{
    OWSLogInfo(@"");

    [self dismissViewControllerAnimated:YES completion:nil];
}

- (nullable NSString *)contactApprovalCustomTitle:(ContactShareApprovalViewController *)contactApproval
{
    return nil;
}

- (nullable NSString *)contactApprovalRecipientsDescription:(ContactShareApprovalViewController *)contactApproval
{
    OWSLogInfo(@"");

    __block NSString *result;
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        result = [self.contactsManager displayNameForThread:self.thread transaction:transaction];
    }];
    return result;
}

- (ApprovalMode)contactApprovalMode:(ContactShareApprovalViewController *)contactApproval
{
    OWSLogInfo(@"");

    return ApprovalModeSend;
}

#pragma mark - ContactShareViewHelperDelegate

- (void)didCreateOrEditContact
{
    OWSLogInfo(@"");
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Toast

- (void)presentMissingQuotedReplyToast
{
    OWSLogInfo(@"");

    NSString *toastText = NSLocalizedString(@"QUOTED_REPLY_ORIGINAL_MESSAGE_DELETED",
        @"Toast alert text shown when tapping on a quoted message which we cannot scroll to because the local copy of "
        @"the message was since deleted.");

    ToastController *toastController = [[ToastController alloc] initWithText:toastText];

    CGFloat bottomInset = kToastInset + self.collectionView.contentInset.bottom + self.view.layoutMargins.bottom;

    [toastController presentToastViewFromBottomOfView:self.view inset:bottomInset];
}

- (void)presentRemotelySourcedQuotedReplyToast
{
    OWSLogInfo(@"");

    NSString *toastText = NSLocalizedString(@"QUOTED_REPLY_ORIGINAL_MESSAGE_REMOTELY_SOURCED",
        @"Toast alert text shown when tapping on a quoted message which we cannot scroll to because the local copy of "
        @"the message didn't exist when the quote was received.");

    ToastController *toastController = [[ToastController alloc] initWithText:toastText];

    CGFloat bottomInset = kToastInset + self.collectionView.contentInset.bottom + self.view.layoutMargins.bottom;

    [toastController presentToastViewFromBottomOfView:self.view inset:bottomInset];
}

- (void)presentViewOnceAlreadyViewedToast
{
    OWSLogInfo(@"");

    NSString *toastText = NSLocalizedString(@"VIEW_ONCE_ALREADY_VIEWED_TOAST",
        @"Toast alert text shown when tapping on a view-once message that has already been viewed.");

    ToastController *toastController = [[ToastController alloc] initWithText:toastText];

    CGFloat bottomInset = kToastInset + self.collectionView.contentInset.bottom + self.view.layoutMargins.bottom;

    [toastController presentToastViewFromBottomOfView:self.view inset:bottomInset];
}

- (void)presentViewOnceOutgoingToast
{
    OWSLogInfo(@"");

    NSString *toastText = NSLocalizedString(
        @"VIEW_ONCE_OUTGOING_TOAST", @"Toast alert text shown when tapping on a view-once message that you have sent.");

    ToastController *toastController = [[ToastController alloc] initWithText:toastText];

    CGFloat bottomInset = kToastInset + self.collectionView.contentInset.bottom + self.view.layoutMargins.bottom;

    [toastController presentToastViewFromBottomOfView:self.view inset:bottomInset];
}

#pragma mark - ConversationViewModelDelegate

- (void)conversationViewModelWillUpdate
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.conversationViewModel);

    // HACK to work around radar #28167779
    // "UICollectionView performBatchUpdates can trigger a crash if the collection view is flagged for layout"
    // more: https://github.com/PSPDFKit-labs/radar.apple.com/tree/master/28167779%20-%20CollectionViewBatchingIssue
    // This was our #2 crash, and much exacerbated by the refactoring somewhere between 2.6.2.0-2.6.3.8
    //
    // NOTE: It's critical we do this before beginLongLivedReadTransaction.
    //       We want to relayout our contents using the old message mappings and
    //       view items before they are updated.
    [self.collectionView layoutIfNeeded];
    // ENDHACK to work around radar #28167779
}

- (void)conversationViewModelDidUpdateWithSneakyTransaction:(ConversationUpdate *)conversationUpdate
{
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        [self conversationViewModelDidUpdate:conversationUpdate transaction:transaction];
    }];
}

- (void)conversationViewModelDidUpdate:(ConversationUpdate *)conversationUpdate
                           transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(conversationUpdate);
    OWSAssertDebug(self.conversationViewModel);

    if (!self.viewLoaded) {
        // It's safe to ignore updates before the view loads;
        // viewWillAppear will call resetContentAndLayout.
        return;
    }
    NSUInteger oldPendingMemberRequestCount = self.pendingMemberRequestCount;
    TSThread *_Nullable lastestThread = [TSThread anyFetchWithUniqueId:self.thread.uniqueId transaction:transaction];
    if (lastestThread == nil) {
        lastestThread = self.thread;
    }
    _threadViewModel = [[ThreadViewModel alloc] initWithThread:lastestThread transaction:transaction];
    [self updateNavigationBarSubtitleLabel];
    [self updateBarButtonItems];

    NSUInteger newPendingMemberRequestCount = self.pendingMemberRequestCount;
    if (oldPendingMemberRequestCount != newPendingMemberRequestCount && self.canApprovePendingMemberRequests) {
        [self ensureBannerState];
    }

    // If the message has been deleted / disappeared, we need to dismiss
    [self dismissMessageActionsIfNecessary];

    [self reloadReactionsDetailSheetWithTransaction:transaction];

    if (self.isGroupConversation) {
        [self updateNavigationTitle];
    }

    if (conversationUpdate.conversationUpdateType == ConversationUpdateType_Minor) {
        [self showMessageRequestDialogIfRequiredAsync];
        return;
    } else if (conversationUpdate.conversationUpdateType == ConversationUpdateType_Reload) {
        [self resetContentAndLayoutWithTransaction:transaction];
        [self updateUnreadMessageFlagWithTransaction:transaction];
        [self showMessageRequestDialogIfRequiredAsync];
        return;
    }

    [self resetShowLoadMore];

    OWSAssertDebug(conversationUpdate.conversationUpdateType == ConversationUpdateType_Diff);
    OWSAssertDebug(conversationUpdate.updateItems);

    // We want to auto-scroll to the bottom of the conversation
    // if the user is inserting new interactions.
    __block BOOL scrollToBottom = NO;

    self.scrollContinuity = ([self isScrolledToBottom] ? kScrollContinuityBottom : kScrollContinuityTop);

    BOOL isSusceptibleToCrashAfterDeletingLastItem;
    if (@available(iOS 12, *)) {
        isSusceptibleToCrashAfterDeletingLastItem = NO;
    } else {
        isSusceptibleToCrashAfterDeletingLastItem = YES;
    }

    NSNumber *_Nullable interactionCount;
    if (isSusceptibleToCrashAfterDeletingLastItem) {
        interactionCount = @([self.thread numberOfInteractionsWithTransaction:transaction]);
    }

    __block BOOL shouldInvalidateLayout = NO;
    void (^batchUpdates)(void) = ^{
        OWSAssertIsOnMainThread();

        const NSUInteger section = 0;
        BOOL hasInserted = NO, hasUpdated = NO;
        for (ConversationUpdateItem *updateItem in conversationUpdate.updateItems) {
            switch (updateItem.updateItemType) {
                case ConversationUpdateItemType_Delete: {
                    // Always perform deletes before inserts and updates.
                    OWSAssertDebug(!hasInserted && !hasUpdated);
                    [self.collectionView deleteItemsAtIndexPaths:@[
                        [NSIndexPath indexPathForRow:(NSInteger)updateItem.oldIndex inSection:section]
                    ]];

                    if (isSusceptibleToCrashAfterDeletingLastItem) {
                        OWSAssertDebug(interactionCount != nil);
                        if (interactionCount.unsignedLongValue == 0) {
                            shouldInvalidateLayout = YES;
                        }
                    }

                    break;
                }
                case ConversationUpdateItemType_Insert: {
                    // Always perform inserts before updates.
                    OWSAssertDebug(!hasUpdated);
                    [self.collectionView insertItemsAtIndexPaths:@[
                        [NSIndexPath indexPathForRow:(NSInteger)updateItem.newIndex inSection:section]
                    ]];
                    hasInserted = YES;

                    id<ConversationViewItem> viewItem = updateItem.viewItem;
                    OWSAssertDebug(viewItem);
                    if ([viewItem.interaction isKindOfClass:[TSOutgoingMessage class]]
                        && conversationUpdate.shouldJumpToOutgoingMessage) {
                        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
                        if (!outgoingMessage.isFromLinkedDevice) {
                            scrollToBottom = YES;
                        }
                    }

                    break;
                }
                case ConversationUpdateItemType_Update: {
                    [self.collectionView reloadItemsAtIndexPaths:@[
                        [NSIndexPath indexPathForRow:(NSInteger)updateItem.oldIndex inSection:section]
                    ]];
                    hasUpdated = YES;
                    break;
                }
            }
        }

        if (shouldInvalidateLayout) {
            OWSLogDebug(@"invalidating layout");
            [self.layout invalidateLayout];
        }
    };

    BOOL shouldAnimateUpdates = conversationUpdate.shouldAnimateUpdates;
    void (^batchUpdatesCompletion)(BOOL) = ^(BOOL finished) {
        OWSAssertIsOnMainThread();

        // We can't use the transaction parameter; this completion
        // will be run async.
        [self updateUnreadMessageFlagUsingAsyncTransaction];
        [self configureScrollDownButtons];

        [self showMessageRequestDialogIfRequired];

        if (scrollToBottom) {
            [self scrollToBottomAnimated:NO];
        }

        // Try to update the lastKnownDistanceFromBottom; the content size may have changed.
        [self updateLastKnownDistanceFromBottom];

        if (!finished) {
            OWSLogInfo(@"performBatchUpdates did not finish");
            // If did not finish, reset to get back to a known good state.
            [self resetContentAndLayoutWithSneakyTransaction];
        } else {
            if (self.isShowingSelectionUI) {
                [self maintainSelectionAfterMappingChange];
                [self updateSelectionHighlight];
            }
        }
    };

    @try {
        if (shouldAnimateUpdates) {
            [self.collectionView performBatchUpdates:batchUpdates completion:batchUpdatesCompletion];
        } else {
            // HACK: We use `UIView.animateWithDuration:0` rather than `UIView.performWithAnimation` to work around a
            // UIKit Crash like:
            //
            //     *** Assertion failure in -[ConversationViewLayout prepareForCollectionViewUpdates:],
            //     /BuildRoot/Library/Caches/com.apple.xbs/Sources/UIKit_Sim/UIKit-3600.7.47/UICollectionViewLayout.m:760
            //     *** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'While
            //     preparing update a visible view at <NSIndexPath: 0xc000000011c00016> {length = 2, path = 0 - 142}
            //     wasn't found in the current data model and was not in an update animation. This is an internal
            //     error.'
            //
            // I'm unclear if this is a bug in UIKit, or if we're doing something crazy in
            // ConversationViewLayout#prepareLayout. To reproduce, rapidily insert and delete items into the
            // conversation. See `DebugUIMessages#thrashCellsInThread:`
            [UIView animateWithDuration:0.0
                             animations:^{
                                 [self.collectionView performBatchUpdates:batchUpdates
                                                               completion:batchUpdatesCompletion];
                                 [BenchManager completeEventWithEventId:@"message-send"];
                             }];
        }
    } @catch (NSException *exception) {
        OWSFailDebug(@"exception: %@ of type: %@ with reason: %@, user info: %@.",
            exception.description,
            exception.name,
            exception.reason,
            exception.userInfo);

        for (ConversationUpdateItem *updateItem in conversationUpdate.updateItems) {
            switch (updateItem.updateItemType) {
                case ConversationUpdateItemType_Delete:
                    OWSLogWarn(@"ConversationUpdateItemType_Delete class: %@, itemId: %@, oldIndex: %lu, "
                               @"newIndex: %lu",
                        [updateItem.viewItem class],
                        updateItem.viewItem.itemId,
                        (unsigned long)updateItem.oldIndex,
                        (unsigned long)updateItem.newIndex);
                    break;
                case ConversationUpdateItemType_Insert:
                    OWSLogWarn(@"ConversationUpdateItemType_Insert class: %@, itemId: %@, oldIndex: %lu, "
                               @"newIndex: %lu",
                        [updateItem.viewItem class],
                        updateItem.viewItem.itemId,
                        (unsigned long)updateItem.oldIndex,
                        (unsigned long)updateItem.newIndex);
                    break;
                case ConversationUpdateItemType_Update:
                    OWSLogWarn(@"ConversationUpdateItemType_Update class: %@, itemId: %@, oldIndex: %lu, "
                               @"newIndex: %lu",
                        [updateItem.viewItem class],
                        updateItem.viewItem.itemId,
                        (unsigned long)updateItem.oldIndex,
                        (unsigned long)updateItem.newIndex);
                    break;
            }
        }

        @throw exception;
    }

    self.lastReloadDate = [NSDate new];
}

- (void)conversationViewModelWillLoadMoreItems
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.conversationViewModel);

    // To maintain scroll position after changing the items loaded in the conversation view:
    //
    // 1. in conversationViewModelWillLoadMoreItems
    //   - Get position of some interactions cell before transition.
    //   - Get content offset before transition
    //
    // 2. Load More
    //
    // 3. in conversationViewModelDidLoadMoreItems
    //   - Get position of that same interaction's cell (it'll have a new index)
    //   - Get content offset after transition
    //   - Offset scrollViewContent so that the cell is in the same spot after as it was before.
    NSIndexPath *_Nullable indexPath = self.lastVisibleIndexPath;
    if (indexPath == nil) {
        // nothing visible yet
        return;
    }

    id<ConversationViewItem> viewItem = [self viewItemForIndex:indexPath.row];
    if (viewItem == nil) {
        OWSFailDebug(@"viewItem was unexpectedly nil");
        return;
    }

    UIView *cell = [self collectionView:self.collectionView cellForItemAtIndexPath:indexPath];
    if (cell == nil) {
        OWSFailDebug(@"cell was unexpectedly nil");
        return;
    }

    CGRect frame = cell.frame;
    CGPoint contentOffset = self.collectionView.contentOffset;

    self.scrollStateBeforeLoadingMore = [[ConversationScrollState alloc] initWithReferenceViewItem:viewItem
                                                                                    referenceFrame:frame
                                                                                     contentOffset:contentOffset];
}

- (void)conversationViewModelDidLoadMoreItems
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.conversationViewModel);

    [self.layout prepareLayout];

    ConversationScrollState *_Nullable scrollState = self.scrollStateBeforeLoadingMore;
    if (scrollState == nil) {
        OWSFailDebug(@"scrollState was unexpectedly nil");
        return;
    }

    NSIndexPath *_Nullable newIndexPath =
        [self.conversationViewModel indexPathForViewItem:scrollState.referenceViewItem];
    if (newIndexPath == nil) {
        OWSFailDebug(@"newIndexPath was unexpectedly nil");
        return;
    }

    UIView *_Nullable cell = [self collectionView:self.collectionView cellForItemAtIndexPath:newIndexPath];
    if (cell == nil) {
        OWSFailDebug(@"cell was unexpectedly nil");
        return;
    }

    CGRect newFrame = cell.frame;
    // distance from top of cell to top of content pane.
    CGFloat previousDistance = scrollState.referenceFrame.origin.y - scrollState.contentOffset.y;
    CGFloat newDistance = newFrame.origin.y - previousDistance;

    CGPoint newContentOffset = CGPointMake(0, newDistance);

    // Note: It's important that we call `setContentOffset:animated:NO` rather than `setContentOffset:`,
    // even though `setContentOffset:` is, by default, not animated. UICollectionView does some
    // other work in `setContentOffset:animated:NO`. Without that additional work, we see situations
    // where contentOffset is incorrectly reset to the top - causing the user to inexplicably be
    // farther back in their history than they expect.
    //
    // When using `[self.collectionView setContentOffset:newContentOffset]`, a trivial repro is:
    //
    //   - have enough messages that you can load in a couple pages (e.g. 100)
    //   - tap the top of the navbar to hit UICollectionView's "scroll to top" tap gesture
    //   - you see "loading more..." which is shortly replaced by the newly loaded messages
    //   - At this point you would expect to maintain the conversation context, such that the messages
    //     visible before loading are visible at the same screen coordinates.
    //   - But instead, after the messages load in, you are immediately scrolled back even farther
    //     to the *new* top of the conversation, causing *another* page of messages to be loaded.
    //
    // I'm unclear what the underlying issue is, but it may be related to:
    //  - we set contentOffset here, but collectionView hasn't yet internally updated it's contentSize
    //    to reflect the new layout. Maybe this triggers a "reset".
    //  - Manually setting the collectionView.contentSize view [collectionView setContentSize:]` to
    //    the new `[self safeContentHeight]` also did not remedy the issue, so it seems like there is
    //    some other relevant state.
    //  - I could find no public API to trigger collectionView to update it's own contentSize sync,
    //    but a debugger shows it as happening as a result of `[collectionView layoutSubviews]`
    //  - manually calling layout methods doesn't update the content size: e.g.
    //    - [collectionView layoutIfNeeded]; // <- doesn't help
    //    - [collectionView setNeedsLayout]; [collectionView layoutIfNeeded]; // <- doesn't help
    //    - [collectionView layoutSubviews]; // <- doesn't help
    [self.collectionView setContentOffset:newContentOffset animated:NO];
}

- (void)conversationViewModelRangeDidChangeWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertIsOnMainThread();

    if (!self.conversationViewModel) {
        OWSFailDebug(@"conversationViewModel was unexpectedly nil");
        return;
    }

    [self updateShowLoadMoreHeadersWithTransaction:transaction];
}

- (void)conversationViewModelDidReset
{
    OWSAssertIsOnMainThread();

    // Scroll to bottom to get view back to a known good state.
    [self scrollToBottomAnimated:NO];
}

#pragma mark - Orientation

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    OWSAssertIsOnMainThread();

    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    [self dismissMessageActionsAnimated:NO];
    [self dismissReactionsDetailSheetAnimated:NO];

    __weak ConversationViewController *weakSelf = self;
    [coordinator
        animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            [self scrollToLastVisibleInteractionAnimated:NO];
        }
        completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            ConversationViewController *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            // When transition animation is complete, update layout to reflect
            // new size.
            [strongSelf resetForSizeOrOrientationChange];

            [strongSelf updateInputToolbarLayout];

            [self scrollToLastVisibleInteractionAnimated:NO];
        }];
}

- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    [self ensureBannerState];
    [self updateBarButtonItems];
    [self updateNavigationBarSubtitleLabel];
}

- (void)resetForSizeOrOrientationChange
{
    self.scrollContinuity = kScrollContinuityBottom;

    self.conversationStyle.viewWidth = floor(self.collectionView.width);
    // Evacuate cached cell sizes.
    for (id<ConversationViewItem> viewItem in self.viewItems) {
        [viewItem clearCachedLayoutState];
    }
    [self reloadData];
    if (self.viewHasEverAppeared) {
        // Try to update the lastKnownDistanceFromBottom; the content size may have changed.
        [self updateLastKnownDistanceFromBottom];
    }
    [self updateInputToolbarLayout];
    [self updateLeftBarItem];
    [self maintainSelectionAfterMappingChange];
    [self updateSelectionHighlight];
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];

    [self updateContentInsetsAnimated:NO];
    [self updateInputToolbarLayout];
}

- (void)updateInputToolbarLayout
{
    [self.inputToolbar updateLayoutWithSafeAreaInsets:self.view.safeAreaInsets];
}

#pragma mark - Message Request

- (void)showMessageRequestDialogIfRequiredAsync
{
    __weak ConversationViewController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf showMessageRequestDialogIfRequired]; });
}

- (void)showMessageRequestDialogIfRequired
{
    OWSAssertIsOnMainThread();

    if (self.threadViewModel.hasPendingMessageRequest || self.isLocalUserRequestingMember) {
        [self.requestView removeFromSuperview];
        if (self.isLocalUserRequestingMember) {
            MemberRequestView *memberRequestView =
                [[MemberRequestView alloc] initWithThreadViewModel:self.threadViewModel fromViewController:self];
            memberRequestView.delegate = self;
            self.requestView = memberRequestView;
        } else {
            MessageRequestView *messageRequestView =
                [[MessageRequestView alloc] initWithThreadViewModel:self.threadViewModel];
            messageRequestView.delegate = self;
            self.requestView = messageRequestView;
        }
        [self reloadBottomBar];
    } else {
        if (self.requestView != nil) {
            [self dismissMessageRequestView];
        } else {
            [self reloadBottomBar];
            [self updateInputVisibility];
        }
    }
}

- (void)dismissMessageRequestView
{
    OWSAssertIsOnMainThread();

    if (!self.requestView) {
        return;
    }

    // Slide the request view off the bottom of the screen.
    CGFloat bottomInset = self.view.safeAreaInsets.bottom;

    UIView *dismissingView = self.requestView;
    self.requestView = nil;

    [self reloadBottomBar];
    [self updateInputVisibility];

    // Add the view on top of the new bottom bar (if there is one),
    // and then slide it off screen to reveal the new input view.
    [self.view addSubview:dismissingView];
    [dismissingView autoPinWidthToSuperview];
    [dismissingView autoPinEdgeToSuperviewEdge:ALEdgeBottom];

    CGRect endFrame = dismissingView.bounds;
    endFrame.origin.y -= endFrame.size.height + bottomInset;

    [UIView animateWithDuration:0.2
        animations:^{
            dismissingView.bounds = endFrame;
        }
        completion:^(BOOL finished) {
            [dismissingView removeFromSuperview];
        }];
}

#pragma mark - LocationPickerDelegate

- (void)didPickLocation:(LocationPicker *)locationPicker location:(Location *)location
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(location);

    OWSLogVerbose(@"Sending location share.");

    __weak ConversationViewController *weakSelf = self;

    [location prepareAttachmentObjc].then(^(SignalAttachment *attachment) {
        OWSAssertIsOnMainThread();
        OWSAssertDebug([attachment isKindOfClass:[SignalAttachment class]]);

        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        __block TSOutgoingMessage *message;

        [strongSelf.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
            message = [ThreadUtil enqueueMessageWithBody:[[MessageBody alloc] initWithText:location.messageText
                                                                                    ranges:MessageBodyRanges.empty]
                                        mediaAttachments:@[ attachment ]
                                                  thread:strongSelf.thread
                                        quotedReplyModel:nil
                                        linkPreviewDraft:nil
                                             transaction:transaction];
        }];

        [strongSelf messageWasSent:message];
    });
}

#pragma mark - InputAccessoryViewPlaceholderDelegate

- (void)inputAccessoryPlaceholderKeyboardIsDismissingInteractively
{
    // No animation, just follow along with the keyboard.
    self.isDismissingInteractively = YES;
    [self updateBottomBarPosition];
    self.isDismissingInteractively = NO;
}

- (void)inputAccessoryPlaceholderKeyboardIsDismissingWithAnimationDuration:(NSTimeInterval)animationDuration
                                                            animationCurve:(UIViewAnimationCurve)animationCurve
{
    [self handleKeyboardStateChange:animationDuration animationCurve:animationCurve];
}

- (void)inputAccessoryPlaceholderKeyboardIsPresentingWithAnimationDuration:(NSTimeInterval)animationDuration
                                                            animationCurve:(UIViewAnimationCurve)animationCurve
{
    [self handleKeyboardStateChange:animationDuration animationCurve:animationCurve];
}

- (void)handleKeyboardStateChange:(NSTimeInterval)animationDuration animationCurve:(UIViewAnimationCurve)animationCurve
{
    if (self.shouldAnimateKeyboardChanges && animationDuration > 0) {
        // The animation curve provided by the keyboard notifications
        // is a private value not represented in UIViewAnimationOptions.
        // We don't use a block based animation here because it's not
        // possible to pass a curve directly to block animations.
        [UIView beginAnimations:@"keyboardStateChange" context:nil];
        [UIView setAnimationBeginsFromCurrentState:YES];
        [UIView setAnimationCurve:animationCurve];
        [UIView setAnimationDuration:animationDuration];
        [self updateBottomBarPosition];
        [UIView commitAnimations];
        [self updateContentInsetsAnimated:YES];
    } else {
        [self updateBottomBarPosition];
        [self updateContentInsetsAnimated:NO];
    }
}

// MARK: -

- (void)reloadBottomBar
{
    UIView *bottomView;

    if (self.requestView != nil) {
        bottomView = self.requestView;
    } else {
        switch (self.uiMode) {
            case ConversationUIMode_Search:
                bottomView = self.searchController.resultsBar;
                break;
            case ConversationUIMode_Selection:
                bottomView = self.selectionToolbar;
                break;
            case ConversationUIMode_Normal:
                bottomView = self.inputToolbar;
                break;
        }
    }

    if (bottomView.superview == self.bottomBar && self.viewHasEverAppeared) {
        // Do nothing, the view has not changed.
        return;
    }

    for (UIView *subView in self.bottomBar.subviews) {
        [subView removeFromSuperview];
    }

    [self.bottomBar addSubview:bottomView];

    // The message requests view expects to extend into the safe area
    if (self.requestView) {
        [bottomView autoPinEdgesToSuperviewEdges];
    } else {
        [bottomView autoPinEdgesToSuperviewMargins];
    }

    [self updateInputAccessoryPlaceholderHeight];
    [self updateContentInsetsAnimated:self.viewHasEverAppeared];
}

- (void)updateInputAccessoryPlaceholderHeight
{
    OWSAssertIsOnMainThread();

    // If we're currently dismissing interactively, skip updating the
    // input accessory height. Changing it while dismissing can lead to
    // an infinite loop of keyboard frame changes as the listeners in
    // InputAcessoryViewPlaceholder will end up calling back here if
    // a dismissal is in progress.
    if (self.isDismissingInteractively) {
        return;
    }

    // Apply any pending layout changes to ensure we're measuring the up-to-date height.
    [self.bottomBar.superview layoutIfNeeded];

    self.inputAccessoryPlaceholder.desiredHeight = self.bottomBar.height;
}

- (void)updateBottomBarPosition
{
    OWSAssertIsOnMainThread();

    // Don't update the bottom bar position if an interactive pop is in progress
    switch (self.navigationController.interactivePopGestureRecognizer.state) {
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateFailed:
            break;
        default:
            return;
    }

    self.bottomBarBottomConstraint.constant = -self.inputAccessoryPlaceholder.keyboardOverlap;

    // We always want to apply the new bottom bar position immediately,
    // as this only happens during animations (interactive or otherwise)
    [self.bottomBar.superview layoutIfNeeded];
}

- (void)updateContentInsetsAnimated:(BOOL)animated
{
    OWSAssertIsOnMainThread();

    // Don't update the content insets if an interactive pop is in progress
    switch (self.navigationController.interactivePopGestureRecognizer.state) {
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateFailed:
            break;
        default:
            return;
    }

    [self.view layoutIfNeeded];

    UIEdgeInsets oldInsets = self.collectionView.contentInset;
    UIEdgeInsets newInsets = oldInsets;

    newInsets.bottom = self.messageActionsExtraContentInsetPadding + self.inputAccessoryPlaceholder.keyboardOverlap
        + self.bottomBar.height - self.view.safeAreaInsets.bottom;
    newInsets.top = self.messageActionsExtraContentInsetPadding;

    BOOL wasScrolledToBottom = [self isScrolledToBottom];

    // Changing the contentInset can change the contentOffset, so make sure we
    // stash the current value before making any changes.
    CGFloat oldYOffset = self.collectionView.contentOffset.y;

    if (!UIEdgeInsetsEqualToEdgeInsets(self.collectionView.contentInset, newInsets)) {
        self.collectionView.contentInset = newInsets;
    }
    self.collectionView.scrollIndicatorInsets = newInsets;

    void (^adjustInsets)(void) = ^(void) {
        // Adjust content offset to prevent the presented keyboard from obscuring content.
        BOOL hasViewBeenPresented = self.viewHasEverAppeared || self.isViewVisible;
        if (!hasViewBeenPresented) {
            // Do nothing.
        } else if (!self.viewHasEverAppeared) {
            // We need to apply the default scroll state between the first
            // viewWillAppear() and viewDidAppear().
            [self scrollToDefaultPositionAnimated:NO];
        } else if (wasScrolledToBottom) {
            // If we were scrolled to the bottom, don't do any fancy math. Just stay at the bottom.
            [self scrollToBottomAnimated:NO];
        } else if (self.isViewCompletelyAppeared) {
            // If we were scrolled away from the bottom, shift the content in lockstep with the
            // keyboard, up to the limits of the content bounds.
            CGFloat insetChange = newInsets.bottom - oldInsets.bottom;

            // Only update the content offset if the inset has changed.
            if (insetChange != 0) {
                // The content offset can go negative, up to the size of the top layout guide.
                // This accounts for the extended layout under the navigation bar.
                OWSAssertDebug(self.topLayoutGuide.length == self.view.safeAreaInsets.top);
                CGFloat minYOffset = -self.view.safeAreaInsets.top;

                CGFloat newYOffset = CGFloatClamp(oldYOffset + insetChange, minYOffset, self.safeContentHeight);
                CGPoint newOffset = CGPointMake(0, newYOffset);

                [self.collectionView setContentOffset:newOffset animated:NO];
            }
        }
    };

    if (animated) {
        adjustInsets();
    } else {
        [UIView performWithoutAnimation:adjustInsets];
    }
}

#pragma mark - Keyboard Shortcuts

- (void)focusInputToolbar
{
    OWSAssertIsOnMainThread();

    [self.inputToolbar clearDesiredKeyboard];
    [self popKeyBoard];
}

- (void)openAllMedia
{
    OWSAssertIsOnMainThread();

    [self showConversationSettingsAndShowAllMedia];
}

- (void)openStickerKeyboard
{
    OWSAssertIsOnMainThread();

    [self.inputToolbar showStickerKeyboard];
}

- (void)openAttachmentKeyboard
{
    OWSAssertIsOnMainThread();

    [self.inputToolbar showAttachmentKeyboard];
}

- (void)openGifSearch
{
    OWSAssertIsOnMainThread();

    [self showGifPicker];
}

@end

NS_ASSUME_NONNULL_END
