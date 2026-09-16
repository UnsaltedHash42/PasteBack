#!/usr/bin/env swift

import AppKit
import CoreGraphics

// Draws the placeholder app icon (1024x1024 clipboard on a blue rounded
// square) and writes it as PNG to the path given as the first argument.

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

let size = 1024.0
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let context = NSGraphicsContext.current!.cgContext

let canvas = CGRect(x: 0, y: 0, width: size, height: size)

// Background: blue rounded square with a subtle vertical gradient.
let backgroundPath = CGPath(
    roundedRect: canvas.insetBy(dx: 64, dy: 64),
    cornerWidth: 180,
    cornerHeight: 180,
    transform: nil
)
let colors = [
    CGColor(red: 0.16, green: 0.42, blue: 0.92, alpha: 1),
    CGColor(red: 0.10, green: 0.30, blue: 0.78, alpha: 1),
]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
context.addPath(backgroundPath)
context.saveGState()
context.clip()
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: size / 2, y: size),
    end: CGPoint(x: size / 2, y: 0),
    options: []
)
context.restoreGState()

// Clipboard body.
let bodyRect = CGRect(x: 292, y: 216, width: 440, height: 520)
let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 48, cornerHeight: 48, transform: nil)
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.addPath(bodyPath)
context.fillPath()

// Clipboard clip.
let clipOuter = CGRect(x: 432, y: 688, width: 160, height: 96)
context.setFillColor(CGColor(red: 0.82, green: 0.85, blue: 0.90, alpha: 1))
context.addPath(CGPath(roundedRect: clipOuter, cornerWidth: 40, cornerHeight: 40, transform: nil))
context.fillPath()
let clipInner = CGRect(x: 466, y: 724, width: 92, height: 60)
context.setFillColor(CGColor(red: 0.16, green: 0.42, blue: 0.92, alpha: 1))
context.addPath(CGPath(roundedRect: clipInner, cornerWidth: 24, cornerHeight: 24, transform: nil))
context.fillPath()

// Text lines.
context.setFillColor(CGColor(red: 0.55, green: 0.60, blue: 0.68, alpha: 1))
for index in 0..<4 {
    let y = 596.0 - Double(index) * 92.0
    let width = index == 3 ? 220.0 : 316.0
    let line = CGRect(x: 348, y: y, width: width, height: 34)
    context.addPath(CGPath(roundedRect: line, cornerWidth: 17, cornerHeight: 17, transform: nil))
    context.fillPath()
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("PNG encode failed\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: outputURL)
