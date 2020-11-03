//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation

public extension TSMessage {
    var reactionFinder: ReactionFinder {
        return ReactionFinder(uniqueMessageId: uniqueId)
    }

    @objc
    func removeAllReactions(transaction: SDSAnyWriteTransaction) {
        guard !CurrentAppContext().isRunningTests else { return }
        reactionFinder.deleteAllReactions(transaction: transaction.unwrapGrdbWrite)
    }

    @objc
    func allReactionIds(transaction: SDSAnyReadTransaction) -> [String]? {
        return reactionFinder.allUniqueIds(transaction: transaction.unwrapGrdbRead)
    }

    @objc
    func markUnreadReactionsAsRead(transaction: SDSAnyWriteTransaction) {
        let unreadReactions = reactionFinder.unreadReactions(transaction: transaction.unwrapGrdbWrite)
        unreadReactions.forEach { $0.markAsRead(transaction: transaction) }
    }

    @objc(reactionForReactor:transaction:)
    func reaction(for reactor: SignalServiceAddress, transaction: SDSAnyReadTransaction) -> OWSReaction? {
        return reactionFinder.reaction(for: reactor, transaction: transaction.unwrapGrdbRead)
    }

    @objc(recordReactionForReactor:emoji:sentAtTimestamp:receivedAtTimestamp:transaction:)
    @discardableResult
    func recordReaction(
        for reactor: SignalServiceAddress,
        emoji: String,
        sentAtTimestamp: UInt64,
        receivedAtTimestamp: UInt64,
        transaction: SDSAnyWriteTransaction
    ) -> OWSReaction? {
        Logger.info("")

        guard !wasRemotelyDeleted else {
            owsFailDebug("attempted to record a reaction for a message that was deleted")
            return nil
        }

        assert(emoji.isSingleEmoji)

        // Remove any previous reaction, there can only be one
        removeReaction(for: reactor, transaction: transaction)

        let reaction = OWSReaction(
            uniqueMessageId: uniqueId,
            emoji: emoji,
            reactor: reactor,
            sentAtTimestamp: sentAtTimestamp,
            receivedAtTimestamp: receivedAtTimestamp
        )

        reaction.anyInsert(transaction: transaction)

        // Reactions to messages we send need to be manually marked
        // as read as they trigger notifications we need to clear
        // out. Everything else can be automatically read.
        if !(self is TSOutgoingMessage) { reaction.markAsRead(transaction: transaction) }

        databaseStorage.touch(interaction: self, shouldReindex: false, transaction: transaction)

        return reaction
    }

    @objc(removeReactionForReactor:transaction:)
    func removeReaction(for reactor: SignalServiceAddress, transaction: SDSAnyWriteTransaction) {
        Logger.info("")

        guard let reaction = reaction(for: reactor, transaction: transaction) else { return }

        reaction.anyRemove(transaction: transaction)
        databaseStorage.touch(interaction: self, shouldReindex: false, transaction: transaction)

        DispatchQueue.main.async {
            SSKEnvironment.shared.notificationsManager.cancelNotifications(reactionId: reaction.uniqueId)
        }
    }

    // MARK: - Remote Delete

    @objc(OWSRemoteDeleteProcessingResult)
    enum RemoteDeleteProcessingResult: Int, Error {
        case deletedMessageMissing
        case invalidDelete
        case success
    }

    @objc
    class func tryToRemotelyDeleteMessage(
        fromAddress authorAddress: SignalServiceAddress,
        sentAtTimestamp: UInt64,
        threadUniqueId: String,
        serverTimestamp: UInt64,
        transaction: SDSAnyWriteTransaction
    ) -> RemoteDeleteProcessingResult {
        guard let messageToDelete = InteractionFinder.findMessage(
            withTimestamp: sentAtTimestamp,
            threadId: threadUniqueId,
            author: authorAddress,
            transaction: transaction
        ) else {
            // The message doesn't exist locally, so nothing to do.
            Logger.info("Attempted to remotely delete a message that doesn't exist \(sentAtTimestamp)")
            return .deletedMessageMissing
        }

        if messageToDelete is TSOutgoingMessage, authorAddress.isLocalAddress {
            messageToDelete.markMessageAsRemotelyDeleted(transaction: transaction)
            return .success
        } else if let incomingMessageToDelete = messageToDelete as? TSIncomingMessage {
            guard let messageToDeleteServerTimestamp = incomingMessageToDelete.serverTimestamp?.uint64Value else {
                // Older messages might be missing this, but since we only allow deleting for a small
                // window after you send a message we should generally never hit this path.
                owsFailDebug("can't delete a message without a serverTimestamp")
                return .invalidDelete
            }

            guard messageToDeleteServerTimestamp < serverTimestamp else {
                owsFailDebug("Can't delete a message from the future.")
                return .invalidDelete
            }

            guard serverTimestamp - messageToDeleteServerTimestamp < kDayInMs else {
                owsFailDebug("Ignoring message delete sent more than a day after the original message")
                return .invalidDelete
            }

            incomingMessageToDelete.markMessageAsRemotelyDeleted(transaction: transaction)

            return .success
        } else {
            owsFailDebug("Only incoming messages can be deleted remotely")
            return .invalidDelete
        }
    }

    private func markMessageAsRemotelyDeleted(transaction: SDSAnyWriteTransaction) {
        updateWithRemotelyDeletedAndRemoveRenderableContent(with: transaction)

        DispatchQueue.main.async {
            SSKEnvironment.shared.notificationsManager.cancelNotifications(messageId: self.uniqueId)
        }
    }
}
