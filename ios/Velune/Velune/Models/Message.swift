import Foundation
import Supabase
import SwiftData

struct Message: Identifiable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id: UUID
    var soulerId: UUID
    var sessionId: UUID?
    var role: Role
    var content: String
    var createdAt: Date
}

extension Message {
    private struct Response: Codable {
        var id: UUID
        var soulerId: UUID
        var sessionId: UUID?
        var role: Role
        var content: String
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case soulerId = "souler_id"
            case sessionId = "session_id"
            case role
            case content
            case createdAt = "created_at"
        }
    }

    static func getHistory(sessionId: UUID) async throws -> [Message] {
        let supabase = try Backend.requireSupabase()
        let response: [Response] = try await supabase
            .from("messages")
            .select("id, souler_id, session_id, role, content, created_at")
            .eq("session_id", value: sessionId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return response.map { item in
            Message(
                id: item.id,
                soulerId: item.soulerId,
                sessionId: item.sessionId,
                role: item.role,
                content: item.content,
                createdAt: item.createdAt
            )
        }
    }

    @MainActor
    static func fetchCached(
        sessionId: UUID,
        userId: String,
        context: ModelContext
    ) throws -> [Message] {
        guard try fetchBucket(sessionId: sessionId, userId: userId, context: context) != nil else {
            return []
        }

        return try context.fetch(
            cachedMessageDescriptor(sessionId: sessionId, userId: userId)
        ).map(\.asMessage)
    }

    @MainActor
    static func shouldRefreshCache(
        sessionId: UUID,
        userId: String,
        sessionUpdatedAt: Date?,
        context: ModelContext
    ) throws -> Bool {
        guard let bucket = try fetchBucket(sessionId: sessionId, userId: userId, context: context) else {
            return true
        }

        guard let sessionUpdatedAt else { return false }
        return bucket.lastSessionUpdatedAt < sessionUpdatedAt
    }

    @MainActor
    static func replaceCached(
        messages: [Message],
        sessionId: UUID,
        userId: String,
        sessionUpdatedAt: Date,
        capacity: Int,
        context: ModelContext
    ) throws {
        let key = bucketKey(userId: userId, sessionId: sessionId)
        let now = Date()

        let bucket: MessageCacheBucket
        if let existingBucket = try fetchBucket(sessionId: sessionId, userId: userId, context: context) {
            bucket = existingBucket
        } else {
            bucket = MessageCacheBucket(
                key: key,
                userId: userId,
                sessionId: sessionId,
                enqueuedAt: now,
                lastSessionUpdatedAt: sessionUpdatedAt,
                lastSyncedAt: now,
                messageCount: messages.count
            )
            context.insert(bucket)
        }

        let staleMessages = try context.fetch(cachedMessageDescriptor(sessionId: sessionId, userId: userId))
        for staleMessage in staleMessages {
            context.delete(staleMessage)
        }

        for message in messages {
            context.insert(CachedMessage(message: message, userId: userId, sessionId: sessionId))
        }

        bucket.lastSessionUpdatedAt = sessionUpdatedAt
        bucket.lastSyncedAt = now
        bucket.messageCount = messages.count

        try context.save()
        try evictOverflowBuckets(userId: userId, capacity: capacity, context: context)
    }

    @MainActor
    static func evictOverflowBuckets(
        userId: String,
        capacity: Int,
        context: ModelContext
    ) throws {
        let resolvedCapacity = max(capacity, 0)
        var buckets = try context.fetch(bucketDescriptor(userId: userId))
        guard buckets.count > resolvedCapacity else { return }

        var hasChanges = false
        while buckets.count > resolvedCapacity {
            let oldest = buckets.removeFirst()
            let sessionMessages = try context.fetch(
                cachedMessageDescriptor(sessionId: oldest.sessionId, userId: userId)
            )
            for message in sessionMessages {
                context.delete(message)
            }
            context.delete(oldest)
            hasChanges = true
        }

        if hasChanges {
            try context.save()
        }
    }

    @MainActor
    static func clearCached(userId: String, context: ModelContext) throws {
        let buckets = try context.fetch(bucketDescriptor(userId: userId))
        let targetUserId = userId
        let messages = try context.fetch(
            FetchDescriptor<CachedMessage>(
                predicate: #Predicate<CachedMessage> {
                    $0.userId == targetUserId
                }
            )
        )

        guard !buckets.isEmpty || !messages.isEmpty else { return }

        for message in messages {
            context.delete(message)
        }
        for bucket in buckets {
            context.delete(bucket)
        }

        try context.save()
    }

    @MainActor
    static func fetchBucket(
        sessionId: UUID,
        userId: String,
        context: ModelContext
    ) throws -> MessageCacheBucket? {
        let targetKey = bucketKey(userId: userId, sessionId: sessionId)
        var descriptor = FetchDescriptor<MessageCacheBucket>(
            predicate: #Predicate<MessageCacheBucket> {
                $0.key == targetKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func bucketKey(userId: String, sessionId: UUID) -> String {
        "\(userId)#\(sessionId.uuidString)"
    }

    private static func cachedMessageDescriptor(
        sessionId: UUID,
        userId: String
    ) -> FetchDescriptor<CachedMessage> {
        let targetSessionId = sessionId
        let targetUserId = userId
        return FetchDescriptor<CachedMessage>(
            predicate: #Predicate<CachedMessage> {
                $0.sessionId == targetSessionId && $0.userId == targetUserId
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
    }

    private static func bucketDescriptor(userId: String) -> FetchDescriptor<MessageCacheBucket> {
        let targetUserId = userId
        return FetchDescriptor<MessageCacheBucket>(
            predicate: #Predicate<MessageCacheBucket> {
                $0.userId == targetUserId
            },
            sortBy: [SortDescriptor(\.enqueuedAt)]
        )
    }
}

@Model
class CachedMessage {
    @Attribute(.unique) var id: UUID
    var userId: String
    var sessionId: UUID
    var soulerId: UUID
    var roleRaw: String
    var content: String
    var createdAt: Date

    init(message: Message, userId: String, sessionId: UUID) {
        id = message.id
        self.userId = userId
        self.sessionId = sessionId
        soulerId = message.soulerId
        roleRaw = message.role.rawValue
        content = message.content
        createdAt = message.createdAt
    }

    var asMessage: Message {
        Message(
            id: id,
            soulerId: soulerId,
            sessionId: sessionId,
            role: Message.Role(rawValue: roleRaw) ?? .assistant,
            content: content,
            createdAt: createdAt
        )
    }
}

@Model
class MessageCacheBucket {
    @Attribute(.unique) var key: String
    var userId: String
    var sessionId: UUID
    var enqueuedAt: Date
    var lastSessionUpdatedAt: Date
    var lastSyncedAt: Date
    var messageCount: Int

    init(
        key: String,
        userId: String,
        sessionId: UUID,
        enqueuedAt: Date,
        lastSessionUpdatedAt: Date,
        lastSyncedAt: Date,
        messageCount: Int
    ) {
        self.key = key
        self.userId = userId
        self.sessionId = sessionId
        self.enqueuedAt = enqueuedAt
        self.lastSessionUpdatedAt = lastSessionUpdatedAt
        self.lastSyncedAt = lastSyncedAt
        self.messageCount = messageCount
    }
}
