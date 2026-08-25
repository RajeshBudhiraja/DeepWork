import UIKit

/// The design system. Tokens are fixed — do not invent, substitute, or
/// re-derive. Light and dark are mapped by token name so the two themes stay in
/// sync, and every token is a dynamic colour that resolves against the current
/// trait collection.
///
/// Rules encoded here:
/// - Each token is used only for the role named beside it.
/// - `text` and `textSecondary` already meet WCAG AA against `background`,
///   `surface`, and `surfaceElevated`. They are never tinted or adjusted.
/// - Hover / pressed / disabled states vary a token's *opacity*. No new hues.
enum Theme {

    enum Color {
        /// page background
        static let background = dynamic(light: 0xF3F7FA, dark: 0x040607)
        /// cards and grouped rows
        static let surface = dynamic(light: 0xE3E7E8, dark: 0x141617)
        /// sheets, popovers, raised surfaces
        static let surfaceElevated = dynamic(light: 0xFCFEFF, dark: 0x25282A)
        /// primary actions and key emphasis
        static let primary = dynamic(light: 0x024864, dark: 0x25617F)
        /// secondary actions and quieter emphasis
        static let secondary = dynamic(light: 0x75919B, dark: 0x7B98A2)
        /// highlights, badges, selected states
        static let accent = dynamic(light: 0x203B4E, dark: 0x456176)
        /// body and heading text
        static let text = dynamic(light: 0x12171A, dark: 0xE8ECEF)
        /// captions and supporting text
        static let textSecondary = dynamic(light: 0x4A4E4F, dark: 0xA1A5A7)
        /// dividers, outlines, input borders
        static let border = dynamic(light: 0x788287, dark: 0x585F63)
        /// confirmation and positive status
        static let success = dynamic(light: 0x308A39, dark: 0x67BB6B)
        /// caution and pending status
        static let warning = dynamic(light: 0x9A6A00, dark: 0xD49824)
        /// destructive actions and failure status
        static let error = dynamic(light: 0xBA4C43, dark: 0xEF7F74)

        /// Foreground for text sitting on a filled `primary` / `accent` /
        /// `error` surface — buttons and selected tiles.
        ///
        /// Not a new hue: it pairs the two near-white values already in the
        /// palette (`surfaceElevated` in light, `text` in dark) so filled-control
        /// text reads white in both themes. Every filled token above is dark
        /// enough in both themes to carry it.
        static let onFilled = dynamic(light: 0xFCFEFF, dark: 0xE8ECEF)

        private static func dynamic(light: Int, dark: Int) -> UIColor {
            UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
            }
        }
    }

    enum Font {
        /// Monospaced digits so the countdown does not jitter as digit widths
        /// change. Without this the timer visibly twitches every second.
        static func timer(_ size: CGFloat) -> UIFont {
            .monospacedDigitSystemFont(ofSize: size, weight: .thin)
        }

        static let largeTitle = UIFont.systemFont(ofSize: 34, weight: .bold)
        static let title = UIFont.systemFont(ofSize: 26, weight: .semibold)
        static let heading = UIFont.systemFont(ofSize: 20, weight: .semibold)
        static let body = UIFont.systemFont(ofSize: 16, weight: .regular)
        static let caption = UIFont.systemFont(ofSize: 13, weight: .medium)
        static let statValue = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .semibold)
    }

    enum Metric {
        static let gutter: CGFloat = 24
        static let cornerRadius: CGFloat = 16
        static let buttonHeight: CGFloat = 58
    }

    /// Opacity steps for interaction states. The design rules require varying a
    /// token's alpha rather than introducing a new hue, so these are the only
    /// sanctioned modifiers.
    enum State {
        static let pressed: CGFloat = 0.72
        static let disabled: CGFloat = 0.38
        /// Quiet supporting fills — a token used as a backdrop to itself.
        static let subtle: CGFloat = 0.14
    }
}

extension UIColor {
    /// Resolve a dynamic token against a view's traits.
    ///
    /// Needed wherever a colour crosses into `CGColor` (CALayer strokes, borders,
    /// shadows): `cgColor` snapshots whichever appearance was current at
    /// assignment and never re-resolves on a theme change.
    func resolved(for view: UIView) -> UIColor {
        resolvedColor(with: view.traitCollection)
    }

    /// 0xRRGGBB. Used only to express the fixed design tokens above.
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - Formatting

extension TimeInterval {

    /// `mm:ss`, or `h:mm:ss` past an hour.
    var clockString: String {
        let total = Int(rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    /// Compact human form for stats: `3h 20m`, `45m`, `30s`.
    var compactString: String {
        let total = Int(rounded())
        if total >= 3600 {
            let hours = total / 3600
            let minutes = (total % 3600) / 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        if total >= 60 { return "\(total / 60)m" }
        return "\(total)s"
    }
}
