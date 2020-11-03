/*
 *
 *  Copyright (C) 2019 Signal Messenger, LLC.
 *  All rights reserved.
 *
 *  SPDX-License-Identifier: GPL-3.0-only
 *
 */

#ifndef RFFI_PEER_CONNECTION_OBSERVER_H__
#define RFFI_PEER_CONNECTION_OBSERVER_H__

#include "api/data_channel_interface.h"
#include "api/peer_connection_interface.h"

/**
 * Adapter between the C++ PeerConnectionObserver interface and the
 * Rust PeerConnection.Observer interface.  Wraps an instance of the
 * Rust interface and dispatches C++ callbacks to Rust.
 */

namespace webrtc {
namespace rffi {

class PeerConnectionObserverRffi : public PeerConnectionObserver, public DataChannelObserver {
 public:
  PeerConnectionObserverRffi(const rust_object observer,
                             const PeerConnectionObserverCallbacks* callbacks);
  ~PeerConnectionObserverRffi() override;

  // Implementation of PeerConnectionObserver interface, which propagates
  // the callbacks to the Rust observer.
  void OnIceCandidate(const IceCandidateInterface* candidate) override;
  void OnIceCandidatesRemoved(
      const std::vector<cricket::Candidate>& candidates) override;
  void OnSignalingChange(
      PeerConnectionInterface::SignalingState new_state) override;
  void OnIceConnectionChange(
      PeerConnectionInterface::IceConnectionState new_state) override;
  void OnConnectionChange(
      PeerConnectionInterface::PeerConnectionState new_state) override;
  void OnIceConnectionReceivingChange(bool receiving) override;
  void OnIceGatheringChange(
      PeerConnectionInterface::IceGatheringState new_state) override;
  void OnAddStream(rtc::scoped_refptr<MediaStreamInterface> stream) override;
  void OnRemoveStream(rtc::scoped_refptr<MediaStreamInterface> stream) override;
  void OnDataChannel(rtc::scoped_refptr<DataChannelInterface> channel) override;
  void OnRenegotiationNeeded() override;
  void OnAddTrack(rtc::scoped_refptr<RtpReceiverInterface> receiver,
                  const std::vector<rtc::scoped_refptr<MediaStreamInterface>>&
                      streams) override;
  void OnTrack(
      rtc::scoped_refptr<RtpTransceiverInterface> transceiver) override;

  // Implementation of DataChannelObserver interface, which propagates
  // the callbacks to the Rust observer.
  void OnMessage(const DataBuffer& buffer) override;
  void OnBufferedAmountChange(uint64_t previous_amount) override {}
  void OnStateChange() override {}

 private:
  const rust_object observer_;
  PeerConnectionObserverCallbacks callbacks_;

};

} // namespace rffi
} // namespace webrtc

#endif /* RFFI_PEER_CONNECTION_OBSERVER_H__ */
