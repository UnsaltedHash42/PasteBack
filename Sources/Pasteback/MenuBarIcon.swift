import AppKit

/// Template status-item glyph: clipboard + return clip, the same mark as the app icon.
enum MenuBarIcon {
    static func image() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let line = max(1.25, rect.width / 14)
            let clipRadius = rect.width * 0.175
            let clipCenter = NSPoint(x: rect.midX, y: rect.maxY - clipRadius - 0.35)

            let boardTop = clipCenter.y - clipRadius * 0.25
            let side = rect.width * 0.13
            let board = NSRect(
                x: rect.minX + side,
                y: rect.minY + rect.height * 0.05,
                width: rect.width - side * 2,
                height: boardTop - (rect.minY + rect.height * 0.05)
            )
            let boardPath = NSBezierPath(roundedRect: board, xRadius: 2.3, yRadius: 2.3)
            boardPath.lineWidth = line
            boardPath.lineJoinStyle = .round
            boardPath.stroke()

            let clipBox = NSRect(
                x: clipCenter.x - clipRadius,
                y: clipCenter.y - clipRadius,
                width: clipRadius * 2,
                height: clipRadius * 2
            )
            NSBezierPath(ovalIn: clipBox).fill()

            if let context = NSGraphicsContext.current {
                context.saveGraphicsState()
                context.compositingOperation = .destinationOut
                let arrow = returnArrow(center: clipCenter, radius: clipRadius)
                NSColor.black.setStroke()
                arrow.stroke()
                context.restoreGraphicsState()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Pasteback"
        return image
    }

    private static func returnArrow(center: NSPoint, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineWidth = max(1.05, radius * 0.38)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let left = center.x - radius * 0.42
        let right = center.x + radius * 0.38
        let midY = center.y - radius * 0.06
        let topY = center.y + radius * 0.28

        path.move(to: NSPoint(x: right, y: midY - radius * 0.22))
        path.line(to: NSPoint(x: right, y: midY))
        path.curve(
            to: NSPoint(x: left, y: topY),
            controlPoint1: NSPoint(x: right, y: midY + radius * 0.42),
            controlPoint2: NSPoint(x: center.x + radius * 0.08, y: topY)
        )

        let head = radius * 0.32
        path.move(to: NSPoint(x: left + head, y: topY + head * 0.7))
        path.line(to: NSPoint(x: left, y: topY))
        path.line(to: NSPoint(x: left + head, y: topY - head * 0.7))
        return path
    }
}
