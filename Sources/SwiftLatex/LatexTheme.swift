import SwiftUI

/// v1 공개 theme. 값 비교로 렌더 요청 key에 포함된다.
public struct LatexTheme: Sendable, Equatable {
    public var textColor: Color
    public var linkColor: Color
    public var codeBlockBackground: Color
    public var inlineCodeBackground: Color
    public var quoteBar: Color
    public var codeHeaderBackground: Color

    public init(
        textColor: Color = .primary,
        linkColor: Color = .accessibleLink,
        codeBlockBackground: Color = Color(.secondarySystemBackground),
        inlineCodeBackground: Color = Color(.secondarySystemFill),
        quoteBar: Color = Color(.systemGray3),
        codeHeaderBackground: Color = Color(.tertiarySystemBackground)
    ) {
        self.textColor = textColor
        self.linkColor = linkColor
        self.codeBlockBackground = codeBlockBackground
        self.inlineCodeBackground = inlineCodeBackground
        self.quoteBar = quoteBar
        self.codeHeaderBackground = codeHeaderBackground
    }

    public static let `default` = LatexTheme()
}

public extension Color {
    /// 기본 링크 색. 시스템 블루(#007AFF)는 흰 배경에서 약 3.6:1로 본문 텍스트
    /// 대비 기준(4.5:1)에 미달해 접근성 audit이 실패한다. light/dark 각각
    /// 기준을 넘는 값을 쓴다 (light 약 7.5:1, dark 약 8.9:1).
    static let accessibleLink = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.75, blue: 1.00, alpha: 1)
            : UIColor(red: 0.04, green: 0.31, blue: 0.72, alpha: 1)
    })
}

private struct LatexThemeKey: EnvironmentKey {
    static let defaultValue = LatexTheme.default
}

extension EnvironmentValues {
    var latexTheme: LatexTheme {
        get { self[LatexThemeKey.self] }
        set { self[LatexThemeKey.self] = newValue }
    }
}

public extension View {
    func latexTheme(_ theme: LatexTheme) -> some View {
        environment(\.latexTheme, theme)
    }
}
