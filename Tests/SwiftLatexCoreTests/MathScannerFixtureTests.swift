import Testing
@testable import SwiftLatexCore

/// DEVELOPMENT.md §8 parser/보안 fixture.
/// "구현한 규칙과 fixture가 실제 계약이다."
@Suite struct MathScannerFixtureTests {

    // MARK: - Helpers

    private func parse(_ markdown: String, dollar: Bool = false) -> ParsedDocument {
        SwiftLatexParser.parse(markdown: markdown, parsesDollarMath: dollar)
    }

    private func firstParagraphRuns(_ document: ParsedDocument) -> [InlineRun] {
        for block in document.blocks {
            if case .paragraph(let runs) = block { return runs }
        }
        return []
    }

    private func plainText(of runs: [InlineRun]) -> String {
        runs.map { run in
            switch run.content {
            case .text(let s): return s
            case .code(let s): return s
            case .math(let seg): return seg.source
            case .link(let t, _): return t
            case .hardBreak: return "\n"
            case .softBreak: return " "
            }
        }.joined()
    }

    // MARK: - 기본 delimiter

    @Test func inlineParenMath() {
        let doc = parse(#"원의 넓이는 \( A = \pi r^2 \)입니다."#)
        let segments = doc.allMathSegments
        #expect(segments.count == 1)
        #expect(segments.first?.kind == .inlineParen)
        #expect(segments.first?.source == #"\( A = \pi r^2 \)"#)
        #expect(segments.first?.latex == #"A = \pi r^2"#)
        #expect(plainText(of: firstParagraphRuns(doc)) == #"원의 넓이는 \( A = \pi r^2 \)입니다."#)
    }

    @Test func displayBracketWholeParagraphIsBlockMath() {
        let doc = parse("본문\n\n\\[ E = mc^2 \\]\n\n다음")
        #expect(doc.blocks.contains { block in
            if case .blockMath(let seg) = block {
                return seg.kind == .displayBracket && seg.latex == "E = mc^2"
            }
            return false
        })
    }

    @Test func midParagraphDisplayBracketStaysPlainText() {
        let doc = parse(#"이건 \[x+y\] 인라인 위치다."#)
        #expect(doc.allMathSegments.isEmpty)
        #expect(doc.diagnostics.contains { $0.kind == .nonParagraphDisplayDelimiter })
    }

    // MARK: - escape (연속 backslash 홀짝)

    @Test func escapedBackslashBeforeParenIsNotDelimiter() {
        let doc = parse(#"\\(x\\)"#)
        #expect(doc.allMathSegments.isEmpty)
    }

    @Test func tripleBackslashParenIsDelimiter() {
        let doc = parse(#"\\\(x\)"#)
        #expect(doc.allMathSegments.map(\.latex) == ["x"])
    }

    // MARK: - 빈/미완성/중첩 delimiter

    @Test func unterminatedInlineMathStaysPlain() {
        let doc = parse(#"열림만 \(x + y 끝"#)
        #expect(doc.allMathSegments.isEmpty)
        #expect(doc.diagnostics.contains { $0.kind == .unterminatedDelimiter })
    }

    @Test func emptyInlineMathStaysPlain() {
        let doc = parse(#"빈 수식 \(\) 이다"#)
        #expect(doc.allMathSegments.isEmpty)
        #expect(doc.diagnostics.contains { $0.kind == .emptyMath })
    }

    @Test func nestedOpenerEmitsDiagnostic() {
        let doc = parse(#"중첩 \(a \(b\) c\) 다"#)
        #expect(doc.diagnostics.contains { $0.kind == .nestedDelimiter })
    }

    // MARK: - Dollar math (opt-in)

    @Test func dollarMathDisabledByDefault() {
        #expect(parse(#"가격 $a+b$ 이다"#).allMathSegments.isEmpty)
    }

    @Test func dollarInlineMathWhenEnabled() {
        let segments = parse(#"수식 $a+b$ 이다"#, dollar: true).allMathSegments
        #expect(segments.count == 1)
        #expect(segments.first?.kind == .inlineDollar)
        #expect(segments.first?.latex == "a+b")
    }

    @Test func currencyFiveDollarsStaysPlain() {
        #expect(parse("$5", dollar: true).allMathSegments.isEmpty)
    }

    @Test func currencyRangeStaysPlain() {
        #expect(parse("$5 and $10", dollar: true).allMathSegments.isEmpty)
    }

    @Test func closingDollarFollowedByDigitStaysPlain() {
        #expect(parse("$x$5", dollar: true).allMathSegments.isEmpty)
    }

    @Test func escapedDollarIsNotDelimiter() {
        #expect(parse(#"\$x\$"#, dollar: true).allMathSegments.isEmpty)
    }

    @Test func adjacentDollarDollarInlineStaysPlain() {
        #expect(parse("a $$b$$ c", dollar: true).allMathSegments.isEmpty)
    }

    @Test func wholeParagraphDollarDollarIsBlockMath() {
        let segments = parse("$$ x^2 $$", dollar: true).allMathSegments
        #expect(segments.count == 1)
        #expect(segments.first?.kind == .displayDollar)
        #expect(segments.first?.latex == "x^2")
    }

    @Test func openingDollarFollowedBySpaceStaysPlain() {
        #expect(parse("$ x$", dollar: true).allMathSegments.isEmpty)
    }

    @Test func closingDollarPrecededBySpaceStaysPlain() {
        #expect(parse("$x $", dollar: true).allMathSegments.isEmpty)
    }

    @Test func inlineDollarDoesNotCrossNewline() {
        #expect(parse("$a\nb$", dollar: true).allMathSegments.isEmpty)
    }

    // MARK: - Markdown 기호가 든 수식

    @Test func mathWithAsteriskSurvivesMarkdown() {
        let doc = parse(#"곱 \(a * b\) 과 \(c * d\)"#)
        #expect(doc.allMathSegments.map(\.latex) == ["a * b", "c * d"])
        #expect(!firstParagraphRuns(doc).contains { $0.italic || $0.bold })
    }

    @Test func mathWithUnderscoreBracketSurvivesMarkdown() {
        #expect(parse(#"첨자 \(x_[i]\) 이다"#).allMathSegments.map(\.latex) == ["x_[i]"])
    }

    @Test func linkLikeMathSourceSurvives() {
        #expect(parse(#"수식 \([a](b)\) 이다"#).allMathSegments.map(\.latex) == ["[a](b)"])
    }

    // MARK: - 금지 문맥 (code/HTML/link/image)

    @Test func inlineCodeProtectsDelimiters() {
        let doc = parse(#"코드 `\(x\)` 는 수식이 아니다"#)
        #expect(doc.allMathSegments.isEmpty)
        #expect(firstParagraphRuns(doc).contains {
            if case .code(#"\(x\)"#) = $0.content { return true } else { return false }
        })
    }

    @Test func fencedCodeBlockProtectsDelimiters() {
        let doc = parse("```\n\\(x\\)\n```")
        #expect(doc.allMathSegments.isEmpty)
        #expect(doc.blocks.contains {
            if case .codeBlock(_, #"\(x\)"#) = $0 { return true } else { return false }
        })
    }

    @Test func tildeFenceProtectsDelimiters() {
        #expect(parse("~~~\n\\(x\\)\n~~~").allMathSegments.isEmpty)
    }

    @Test func longBacktickFenceProtectsDelimiters() {
        #expect(parse("`````\n\\(x\\)\n`````").allMathSegments.isEmpty)
    }

    @Test func indentedCodeProtectsDelimiters() {
        #expect(parse("본문\n\n    \\(x\\)\n").allMathSegments.isEmpty)
    }

    @Test func htmlBlockProtectsDelimitersAndShowsLiteral() {
        let doc = parse("<div>\n\\(x\\)\n</div>")
        #expect(doc.allMathSegments.isEmpty)
        #expect(doc.blocks.contains { block in
            if case .paragraph(let runs) = block {
                return plainText(of: runs).contains("<div>")
            }
            return false
        })
    }

    @Test func linkInternalDelimiterProtected() {
        #expect(parse(#"[\(x\)](https://example.com)"#).allMathSegments.isEmpty)
    }

    @Test func imageAltOnlyAndInternalDelimiterProtected() {
        let doc = parse(#"![대체 \(x\) 텍스트](https://example.com/i.png)"#)
        #expect(doc.allMathSegments.isEmpty)
        let text = plainText(of: firstParagraphRuns(doc))
        #expect(text.contains("대체"))
        #expect(!text.contains("example.com"))
    }

    // MARK: - 링크 allowlist

    @Test(arguments: ["https://a.com", "http://a.com", "mailto:a@b.com"])
    func allowedSchemesBecomeLinks(destination: String) {
        let runs = firstParagraphRuns(parse("[라벨](\(destination))"))
        #expect(runs.contains {
            if case .link("라벨", _) = $0.content { return true } else { return false }
        })
    }

    @Test(arguments: ["ftp://a.com", "javascript:alert(1)", "/relative/path", "tel:12345"])
    func disallowedSchemeAndRelativeURLStayPlainText(destination: String) {
        let runs = firstParagraphRuns(parse("[라벨](\(destination))"))
        #expect(!runs.contains {
            if case .link = $0.content { return true } else { return false }
        })
        #expect(plainText(of: runs).contains("라벨"))
    }

    // MARK: - 다국어 UTF-8

    @Test func koreanEmojiCombiningRTLOffsets() {
        let markdown = "한글🙂 e\u{301} עברית \\(x+y\\) 뒤"
        let doc = parse(markdown)
        #expect(doc.allMathSegments.map(\.latex) == ["x+y"])
        #expect(plainText(of: firstParagraphRuns(doc)) == markdown)
    }

    // MARK: - 입력 제한

    @Test func oversizedInputIsTruncatedWithMarker() {
        let big = String(repeating: "한", count: 120_000) // 360,000 bytes > 256 KiB
        let doc = parse(big)
        #expect(doc.wasTruncated)
        let all = doc.blocks.compactMap { block -> String? in
            if case .paragraph(let runs) = block { return plainText(of: runs) }
            return nil
        }.joined()
        #expect(all.contains(InputLimits.truncationMarker))
    }

    @Test func deepMarkdownDoesNotCrash() {
        let deep = String(repeating: "> ", count: 64) + "깊다"
        #expect(!parse(deep).blocks.isEmpty)
    }

    @Test func manyNodesDoesNotCrash() {
        let many = Array(repeating: "- 항목 \\(x\\)", count: 500).joined(separator: "\n")
        #expect(!parse(many).blocks.isEmpty)
    }
}
