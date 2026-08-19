import Foundation

/// DEVELOPMENT.md §6 입력 보호.
/// 원문 UTF-8 byte 상한은 첫 `Document(parsing:)` 전에 검사한다.
/// 초과 시 내부 표시 상한까지 `Character` 경계로 자르고 marker를 붙인다.
package enum InputLimits {
    // ponytail: 상한 수치는 P0 adversarial fixture/측정 전 잠정값. v1 공개 API로 고정하지 않는다.
    package static let maxInputUTF8Bytes = 262_144        // 256 KiB
    package static let displayPrefixUTF8Bytes = 65_536    // 초과 시 표시 상한 64 KiB
    package static let maxMathSourceUTF8Bytes = 4_096     // MathImage.asImage() 호출 전 수식 source 상한
    package static let truncationMarker = "… [입력 제한 초과]"

    package struct BoundedInput: Sendable, Equatable {
        package let text: String
        package let wasTruncated: Bool
    }

    /// 상한 초과 입력을 Character 경계의 bounded prefix + 명시적 생략 marker로 바꾼다.
    package static func bound(_ input: String) -> BoundedInput {
        guard input.utf8.count > maxInputUTF8Bytes else {
            return BoundedInput(text: input, wasTruncated: false)
        }
        var end = input.startIndex
        var byteCount = 0
        var index = input.startIndex
        while index < input.endIndex {
            let next = input.index(after: index)
            let charBytes = input[index..<next].utf8.count
            if byteCount + charBytes > displayPrefixUTF8Bytes { break }
            byteCount += charBytes
            index = next
            end = index
        }
        let prefix = String(input[..<end])
        return BoundedInput(text: prefix + "\n\n" + truncationMarker, wasTruncated: true)
    }
}
