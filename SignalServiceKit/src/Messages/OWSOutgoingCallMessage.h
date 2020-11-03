//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "TSOutgoingMessage.h"

NS_ASSUME_NONNULL_BEGIN

@class SSKProtoCallMessageAnswer;
@class SSKProtoCallMessageBusy;
@class SSKProtoCallMessageHangup;
@class SSKProtoCallMessageIceUpdate;
@class SSKProtoCallMessageOffer;
@class TSThread;

/**
 * WebRTC call signaling sent out of band, via the Signal Service
 */
@interface OWSOutgoingCallMessage : TSOutgoingMessage

- (instancetype)initOutgoingMessageWithBuilder:(TSOutgoingMessageBuilder *)outgoingMessageBuilder NS_UNAVAILABLE;

- (instancetype)initWithThread:(TSThread *)thread
                  offerMessage:(SSKProtoCallMessageOffer *)offerMessage
           destinationDeviceId:(nullable NSNumber *)destinationDeviceId;
- (instancetype)initWithThread:(TSThread *)thread
                 answerMessage:(SSKProtoCallMessageAnswer *)answerMessage
           destinationDeviceId:(nullable NSNumber *)destinationDeviceId;
- (instancetype)initWithThread:(TSThread *)thread
             iceUpdateMessages:(NSArray<SSKProtoCallMessageIceUpdate *> *)iceUpdateMessage
           destinationDeviceId:(nullable NSNumber *)destinationDeviceId;
- (instancetype)initWithThread:(TSThread *)thread
           legacyHangupMessage:(SSKProtoCallMessageHangup *)legacyHangupMessage
           destinationDeviceId:(nullable NSNumber *)destinationDeviceId;
- (instancetype)initWithThread:(TSThread *)thread
                 hangupMessage:(SSKProtoCallMessageHangup *)hangupMessage
           destinationDeviceId:(nullable NSNumber *)destinationDeviceId;
- (instancetype)initWithThread:(TSThread *)thread
                   busyMessage:(SSKProtoCallMessageBusy *)busyMessage
           destinationDeviceId:(nullable NSNumber *)destinationDeviceId;

@property (nullable, nonatomic, readonly) SSKProtoCallMessageOffer *offerMessage;
@property (nullable, nonatomic, readonly) SSKProtoCallMessageAnswer *answerMessage;
@property (nullable, nonatomic, readonly) NSArray<SSKProtoCallMessageIceUpdate *> *iceUpdateMessages;
@property (nullable, nonatomic, readonly) SSKProtoCallMessageHangup *legacyHangupMessage;
@property (nullable, nonatomic, readonly) SSKProtoCallMessageHangup *hangupMessage;
@property (nullable, nonatomic, readonly) SSKProtoCallMessageBusy *busyMessage;
@property (nullable, nonatomic, readonly) NSNumber *destinationDeviceId;

@end

NS_ASSUME_NONNULL_END
