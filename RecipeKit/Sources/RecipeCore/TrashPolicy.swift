import Foundation

/// ごみ箱の保持期間
public enum TrashPolicy {
    public static func expirationDate(deletedAt: Date) -> Date {
        deletedAt.addingTimeInterval(TimeInterval(RecipeLimits.trashRetentionDays) * 24 * 60 * 60)
    }

    public static func isExpired(deletedAt: Date, now: Date) -> Bool {
        expirationDate(deletedAt: deletedAt) <= now
    }

    /// 完全に削除されるまでの日数。1日未満は1日と数える
    public static func daysRemaining(deletedAt: Date, now: Date) -> Int {
        let seconds = expirationDate(deletedAt: deletedAt).timeIntervalSince(now)
        guard seconds > 0 else { return 0 }
        return Int((seconds / (24 * 60 * 60)).rounded(.up))
    }
}
