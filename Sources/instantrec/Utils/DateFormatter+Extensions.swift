import Foundation

extension DateFormatter {
    static let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

extension Date {
    func smartTimeString() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(self) {
            let components = calendar.dateComponents([.hour, .minute], from: self, to: now)
            
            if let hours = components.hour, hours > 0 {
                return "\(hours)時間前"
            } else if let minutes = components.minute, minutes > 0 {
                return "\(minutes)分前"
            } else {
                return "今"
            }
        } else if calendar.isDateInYesterday(self) {
            return "昨日"
        } else {
            let components = calendar.dateComponents([.day], from: self, to: now)
            
            if let days = components.day, days <= 7 {
                return "\(days)日前"
            } else {
                // 1週間以上前は月日表示
                let monthDayFormatter = DateFormatter()
                monthDayFormatter.dateFormat = "M/d"
                return monthDayFormatter.string(from: self)
            }
        }
    }
    
    func smartAbsoluteString() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(self) {
            return "今日 \(DateFormatter.timeOnlyFormatter.string(from: self))"
        } else if calendar.isDateInYesterday(self) {
            return "昨日 \(DateFormatter.timeOnlyFormatter.string(from: self))"
        } else {
            let components = calendar.dateComponents([.day], from: self, to: now)
            
            if let days = components.day, days <= 7 {
                // 1週間以内は月日+時刻
                let monthDayTimeFormatter = DateFormatter()
                monthDayTimeFormatter.dateFormat = "M/d HH:mm"
                return monthDayTimeFormatter.string(from: self)
            } else if calendar.component(.year, from: self) == calendar.component(.year, from: now) {
                // 今年内は月日+時刻
                let monthDayTimeFormatter = DateFormatter()
                monthDayTimeFormatter.dateFormat = "M/d HH:mm"
                return monthDayTimeFormatter.string(from: self)
            } else {
                // 去年以前は年月日+時刻
                let fullFormatter = DateFormatter()
                fullFormatter.dateFormat = "yyyy/M/d HH:mm"
                return fullFormatter.string(from: self)
            }
        }
    }
    
    // 既存メソッドは互換性のため残す
    func relativeTimeString() -> String {
        return smartTimeString()
    }
    
    func absoluteTimeString() -> String {
        return smartAbsoluteString()
    }
}