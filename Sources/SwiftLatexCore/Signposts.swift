import os

/// MainActor에서 CPU parse/raster가 실행되지 않는지 Instruments로 검증하기 위한
/// signpost (DEVELOPMENT.md §8 비동기/cache 테스트).
/// os_signpost 구간을 Time Profiler의 Main Thread와 겹쳐 보면 stall 여부가 드러난다.
package enum SwiftLatexSignposts {
    package static let parse = OSSignposter(subsystem: "dev.swiftlatex", category: "parse")
    package static let raster = OSSignposter(subsystem: "dev.swiftlatex", category: "raster")
}
