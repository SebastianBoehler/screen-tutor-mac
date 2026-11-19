import CoreGraphics

enum LiveOverlayTracking {
    static func refreshed(
        _ source: OverlayScene,
        resolve: (NativeOverlayAnchor) -> CGRect?
    ) -> OverlayScene {
        var scene = source
        scene.marks = source.marks.compactMap { mark in
            guard let anchor = mark.anchor else { return mark }
            guard let rect = resolve(anchor), !rect.isNull, !rect.isEmpty,
                  [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite)
            else { return nil }
            var updated = mark
            updated.rect = rect
            return updated
        }
        return scene
    }
}
