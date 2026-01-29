import Cocoa
import WebKit

// Usage: swift convert_icon.swift input.svg output.png size

guard CommandLine.arguments.count == 4 else {
    print("Usage: convert_icon.swift <input.svg> <output.png> <size>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let size = Double(CommandLine.arguments[3]) ?? 1024.0

let fileURL = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputPath)

// We use NSImage which handles SVG on modern macOS
if let image = NSImage(contentsOf: fileURL) {
    let newSize = NSSize(width: size, height: size)
    let newImage = NSImage(size: newSize)
    
    newImage.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: newSize),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)
    newImage.unlockFocus()
    
    if let tiffData = newImage.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        try? pngData.write(to: outputURL)
        print("Converted \(inputPath) to \(outputPath)")
        exit(0)
    }
}

print("Failed to convert")
exit(1)
