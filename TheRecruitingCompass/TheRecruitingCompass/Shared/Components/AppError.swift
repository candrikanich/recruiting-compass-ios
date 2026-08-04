import SwiftUI

enum AppError: Equatable, Identifiable {
    case notFound
    case unauthorized
    case forbidden
    case serverError(statusCode: Int)
    case serviceUnavailable
    case networkOffline
    case sessionExpired
    case unknown

    var id: String {
        switch self {
        case .notFound: return "notFound"
        case .unauthorized: return "unauthorized"
        case .forbidden: return "forbidden"
        case .serverError(let code): return "serverError-\(code)"
        case .serviceUnavailable: return "serviceUnavailable"
        case .networkOffline: return "networkOffline"
        case .sessionExpired: return "sessionExpired"
        case .unknown: return "unknown"
        }
    }

    init(from error: Error) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                self = .networkOffline
            case .timedOut:
                self = .serviceUnavailable
            default:
                self = .unknown
            }
        } else {
            self = .unknown
        }
    }

    init(statusCode: Int) {
        switch statusCode {
        case 401: self = .unauthorized
        case 403: self = .forbidden
        case 404: self = .notFound
        case 500: self = .serverError(statusCode: 500)
        case 502, 503, 504: self = .serviceUnavailable
        default: self = .unknown
        }
    }

    var config: AppErrorConfig {
        switch self {
        case .notFound:
            return AppErrorConfig(
                headline: "That page ran a different route.",
                body: "We couldn't find what you're looking for. It may have moved, or the link might be off.",
                iconName: "magnifyingglass",
                iconBackground: Color(hex: "EFF6FF"),
                iconForeground: Color(hex: "3B82F6"),
                primaryButtonLabel: "Go to Dashboard",
                secondaryButtonLabel: "Search Schools",
                statusCode: nil
            )
        case .unauthorized:
            return AppErrorConfig(
                headline: "You'll need to sign in first.",
                body: "This page requires an account. Log in to pick up where you left off.",
                iconName: "lock.fill",
                iconBackground: Color(hex: "FFFBEB"),
                iconForeground: Color(hex: "F59E0B"),
                primaryButtonLabel: "Sign In",
                secondaryButtonLabel: "Create Account",
                statusCode: nil
            )
        case .forbidden:
            return AppErrorConfig(
                headline: "This isn't your playbook.",
                body: "You don't have access to this page. If you think that's a mistake, reach out to the account owner.",
                iconName: "shield.slash.fill",
                iconBackground: Color(hex: "FEF2F2"),
                iconForeground: Color(hex: "EF4444"),
                primaryButtonLabel: "Go to Dashboard",
                secondaryButtonLabel: nil,
                statusCode: nil
            )
        case .serverError(let code):
            return AppErrorConfig(
                headline: "We fumbled. It's on us.",
                body: "Something went wrong on our end. Your data is safe, but we hit an unexpected snag. Our team has been notified.",
                iconName: "exclamationmark.triangle.fill",
                iconBackground: Color(hex: "FEF2F2"),
                iconForeground: Color(hex: "EF4444"),
                primaryButtonLabel: "Try Again",
                secondaryButtonLabel: "Go Home",
                statusCode: code
            )
        case .serviceUnavailable:
            return AppErrorConfig(
                headline: "We're taking a timeout.",
                body: "Something on our end isn't cooperating right now. Your recruiting data is safe — we're just temporarily offline. Try again in a few minutes.",
                iconName: "clock.fill",
                iconBackground: Color(hex: "F8FAFC"),
                iconForeground: Color(hex: "64748B"),
                primaryButtonLabel: "Try Again",
                secondaryButtonLabel: "Go Home",
                statusCode: nil
            )
        case .networkOffline:
            return AppErrorConfig(
                headline: "Looks like the connection dropped.",
                body: "We can't reach our servers right now. Check your connection and try again.",
                iconName: "wifi.slash",
                iconBackground: Color(hex: "F8FAFC"),
                iconForeground: Color(hex: "64748B"),
                primaryButtonLabel: "Try Again",
                secondaryButtonLabel: nil,
                statusCode: nil
            )
        case .sessionExpired:
            return AppErrorConfig(
                headline: "You've been away for a while.",
                body: "For your security, we signed you out after a period of inactivity. Log back in to continue.",
                iconName: "clock.badge.exclamationmark.fill",
                iconBackground: Color(hex: "FFFBEB"),
                iconForeground: Color(hex: "F59E0B"),
                primaryButtonLabel: "Sign In Again",
                secondaryButtonLabel: nil,
                statusCode: nil
            )
        case .unknown:
            return AppErrorConfig(
                headline: "Something went sideways.",
                body: "We hit an unexpected snag. Your data is safe — try refreshing or head back home.",
                iconName: "exclamationmark.circle.fill",
                iconBackground: Color(hex: "F8FAFC"),
                iconForeground: Color(hex: "64748B"),
                primaryButtonLabel: "Try Again",
                secondaryButtonLabel: "Go Home",
                statusCode: nil
            )
        }
    }
}
