//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalServiceKit
import SignalMessaging

@objc(OWSWebRTCCallMessageHandler)
public class WebRTCCallMessageHandler: NSObject, OWSCallMessageHandler {

    // MARK: Initializers

    @objc
    public override init() {
        super.init()

        SwiftSingletons.register(self)
    }

    // MARK: - Dependencies

    private var messageSender: MessageSender {
        return SSKEnvironment.shared.messageSender
    }

    private var accountManager: AccountManager {
        return AppEnvironment.shared.accountManager
    }

    private var callService: CallService {
        return AppEnvironment.shared.callService
    }

    // MARK: - Call Handlers

    public func receivedOffer(
        _ offer: SSKProtoCallMessageOffer,
        from caller: SignalServiceAddress,
        sourceDevice: UInt32,
        sentAtTimestamp: UInt64,
        serverReceivedTimestamp: UInt64,
        serverDeliveryTimestamp: UInt64,
        supportsMultiRing: Bool
    ) {
        AssertIsOnMainThread()

        let callType: SSKProtoCallMessageOfferType
        if offer.hasType {
            callType = offer.unwrappedType
        } else {
            // The type is not defined so assume the default, audio.
            callType = .offerAudioCall
        }

        let thread = TSContactThread.getOrCreateThread(contactAddress: caller)
        self.callService.individualCallService.handleReceivedOffer(
            thread: thread,
            callId: offer.id,
            sourceDevice: sourceDevice,
            sdp: offer.sdp,
            opaque: offer.opaque,
            sentAtTimestamp: sentAtTimestamp,
            serverReceivedTimestamp: serverReceivedTimestamp,
            serverDeliveryTimestamp: serverDeliveryTimestamp,
            callType: callType,
            supportsMultiRing: supportsMultiRing
        )
    }

    public func receivedAnswer(_ answer: SSKProtoCallMessageAnswer, from caller: SignalServiceAddress, sourceDevice: UInt32, supportsMultiRing: Bool) {
        AssertIsOnMainThread()

        let thread = TSContactThread.getOrCreateThread(contactAddress: caller)
        self.callService.individualCallService.handleReceivedAnswer(
            thread: thread,
            callId: answer.id,
            sourceDevice: sourceDevice,
            sdp: answer.sdp,
            opaque: answer.opaque,
            supportsMultiRing: supportsMultiRing
        )
    }

    public func receivedIceUpdate(_ iceUpdate: [SSKProtoCallMessageIceUpdate], from caller: SignalServiceAddress, sourceDevice: UInt32) {
        AssertIsOnMainThread()

        let thread = TSContactThread.getOrCreateThread(contactAddress: caller)
        self.callService.individualCallService.handleReceivedIceCandidates(
            thread: thread,
            callId: iceUpdate[0].id,
            sourceDevice: sourceDevice,
            candidates: iceUpdate
        )
    }

    public func receivedHangup(_ hangup: SSKProtoCallMessageHangup, from caller: SignalServiceAddress, sourceDevice: UInt32) {
        AssertIsOnMainThread()

        // deviceId is optional and defaults to 0.
        var deviceId: UInt32 = 0

        let type: SSKProtoCallMessageHangupType
        if hangup.hasType {
            type = hangup.unwrappedType

            if hangup.hasDeviceID {
                deviceId = hangup.deviceID
            }
        } else {
            // The type is not defined so assume the default, normal.
            type = .hangupNormal
        }

        let thread = TSContactThread.getOrCreateThread(contactAddress: caller)
        self.callService.individualCallService.handleReceivedHangup(
            thread: thread,
            callId: hangup.id,
            sourceDevice: sourceDevice,
            type: type,
            deviceId: deviceId
        )
    }

    public func receivedBusy(_ busy: SSKProtoCallMessageBusy, from caller: SignalServiceAddress, sourceDevice: UInt32) {
        AssertIsOnMainThread()

        let thread = TSContactThread.getOrCreateThread(contactAddress: caller)
        self.callService.individualCallService.handleReceivedBusy(
            thread: thread,
            callId: busy.id,
            sourceDevice: sourceDevice
        )
    }
}
