import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable {
    // Main
    case dashboard, schools, coaches, interactions, timeline, events
    // More
    case performance, offers, analytics, documents, deadlines
    // Bottom
    case settings

    var id: String { rawValue }

    var section: SidebarSection {
        switch self {
        case .dashboard, .schools, .coaches, .interactions, .timeline, .events:
            return .main
        case .performance, .offers, .analytics, .documents, .deadlines:
            return .more
        case .settings:
            return .bottom
        }
    }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .schools: return "Schools"
        case .coaches: return "Coaches"
        case .interactions: return "Interactions"
        case .timeline: return "Timeline"
        case .events: return "Events"
        case .performance: return "Performance"
        case .offers: return "Offers"
        case .analytics: return "Analytics"
        case .documents: return "Documents"
        case .deadlines: return "Deadlines"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "house"
        case .schools: return "building.2"
        case .coaches: return "person.2"
        case .interactions: return "bubble.left.and.bubble.right"
        case .timeline: return "clock"
        case .events: return "calendar"
        case .performance: return "chart.bar"
        case .offers: return "envelope.open"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .documents: return "doc.text"
        case .deadlines: return "exclamationmark.circle"
        case .settings: return "gear"
        }
    }

    enum SidebarSection: String, CaseIterable {
        case main, more, bottom

        var header: String? {
            switch self {
            case .main: return nil
            case .more: return "More"
            case .bottom: return nil
            }
        }
    }
}
