import Foundation
import Testing
@testable import SwiftLatex
@testable import SwiftLatexCore

/// stale generation / latest-wins 게시 계약 (DEVELOPMENT.md §4, §8).
@MainActor
@Suite struct LatexRenderModelTests {

    private func request(_ markdown: String) -> LatexRenderModel.Request {
        LatexRenderModel.Request(
            markdown: markdown,
            parsesDollarMath: false,
            pointSize: 17,
            colorRGBA: 0x000000FF,
            displayScale: 3
        )
    }

    private func waitForIdle(_ model: LatexRenderModel, timeout: TimeInterval = 10) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while model.hasOutstandingWork {
            #expect(Date() < deadline, "idle 시간 안에 outstanding task가 0이 되어야 한다")
            if Date() >= deadline { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        // 마지막 게시 hop 여유.
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    @Test func latestSubmissionWinsPublication() async throws {
        let model = LatexRenderModel()
        for i in 1...20 {
            model.submit(request("버전 \(i) \\(x_{\(i)}\\)"))
        }
        try await waitForIdle(model)

        let document = try #require(model.document)
        #expect(flatText(document).contains("버전 20"), "최신 제출만 게시되어야 한다")
    }

    @Test func twoStagePublicationHydratesMath() async throws {
        let model = LatexRenderModel()
        model.submit(request(#"인라인 \(a+b\) 수식"#))
        try await waitForIdle(model)

        let document = try #require(model.document)
        let segments = document.allMathSegments
        #expect(segments.count == 1)
        if let segment = segments.first {
            #expect(model.mathImages[segment] != nil, "hydration 게시 후 수식 이미지가 있어야 한다")
        }
    }

    @Test func mathRenderFailureKeepsSourceOnly() async throws {
        let model = LatexRenderModel()
        model.submit(request(#"고장 \(\frac{\) 수식"#))
        try await waitForIdle(model)

        let document = try #require(model.document)
        for segment in document.allMathSegments where model.mathImages[segment] == nil {
            // 렌더 실패 노드는 이미지 없이 원문 source 유지.
            #expect(!segment.source.isEmpty)
        }
    }

    private func flatText(_ document: ParsedDocument) -> String {
        document.blocks.map { block -> String in
            if case .paragraph(let runs) = block {
                return runs.map { run -> String in
                    switch run.content {
                    case .text(let s): return s
                    case .math(let seg): return seg.source
                    default: return ""
                    }
                }.joined()
            }
            return ""
        }.joined(separator: "\n")
    }
}
