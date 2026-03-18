import WidgetKit
import SwiftUI

struct ClockEntry: TimelineEntry {
    let date: Date
    let skin: SkinDefinition
    var fetchedData: [String: String] = [:]  // DataSource.id.uuidString → display value
}
