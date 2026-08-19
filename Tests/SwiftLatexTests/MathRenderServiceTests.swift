import Foundation
import Testing
import UIKit
@testable import SwiftLatex
@testable import SwiftLatexCore

/// iOS Simulator에서만 실행하는 UIKit 의존 테스트 (DEVELOPMENT.md §8 CI 원칙).
/// memory warning notification이 전역이라 직렬 실행한다.
@Suite(.serialized) struct MathRenderServiceTests {

    private func makeKey(
        latex: String = "x^2",
        pointSize: CGFloat = 17,
        rgba: UInt32 = 0x000000FF,
        display: Bool = false,
        scale: CGFloat = 3
    ) -> MathRenderKey {
        MathRenderKey(latex: latex, pointSize: pointSize, colorRGBA: rgba, isDisplay: display, displayScale: scale)
    }

    // MARK: - cache key (font/size/color/mode/scale)

    @Test func cacheKeyDistinguishesAllComponents() {
        let base = makeKey()
        #expect(base != makeKey(latex: "x^3"))
        #expect(base != makeKey(pointSize: 21))
        #expect(base != makeKey(rgba: 0xFFFFFFFF))
        #expect(base != makeKey(display: true))
        #expect(base != makeKey(scale: 2))
        #expect(base == makeKey())
    }

    // MARK: - raster + baseline layout

    @Test func renderProducesImageAndLayout() async throws {
        let service = MathRenderService()
        let rendered = try #require(await service.render(key: makeKey(latex: #"\frac{a}{b}"#)))
        #expect(rendered.image.size.width > 0)
        #expect(rendered.image.size.height > 0)
        #expect(rendered.descent >= 0)
    }

    @Test func renderCachesResult() async throws {
        let service = MathRenderService()
        let key = makeKey(latex: "a+b")
        let first = try #require(await service.render(key: key))
        let cached = try #require(await service.cachedImage(for: key))
        #expect(first.image === cached.image, "두 번째 조회는 cache hit이어야 한다")
    }

    @Test func oversizedMathSourceFailsPreflight() async {
        let service = MathRenderService()
        let huge = String(repeating: "x+", count: InputLimits.maxMathSourceUTF8Bytes)
        let rendered = await service.render(key: makeKey(latex: huge))
        #expect(rendered == nil, "수식 source 상한 초과는 asImage() 호출 전에 거부한다")
    }

    @Test func invalidLatexFallsBackToNil() async {
        let service = MathRenderService()
        let rendered = await service.render(key: makeKey(latex: #"\frac{"#))
        #expect(rendered == nil, "malformed LaTeX는 nil → 호출자가 원문 source 표시")
    }

    @Test func memoryWarningClearsCache() async throws {
        let service = MathRenderService()
        let key = makeKey(latex: "c^2")
        _ = await service.render(key: key)
        #expect(await service.cachedImage(for: key) != nil)
        await MainActor.run {
            NotificationCenter.default.post(
                name: UIApplication.didReceiveMemoryWarningNotification, object: nil
            )
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(await service.cachedImage(for: key) == nil, "memory warning에서 cache를 비운다")
    }
}
