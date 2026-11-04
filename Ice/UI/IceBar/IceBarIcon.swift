//
//  IceBarIcon.swift
//  Ice
//

import SwiftUI

/// Adapts only confidently monochrome captures; other consumers keep the original pixels.
struct IceBarIcon: View {
    let image: CGImage
    let monochromeMask: CGImage?
    let scale: CGFloat

    var body: some View {
        let size = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        if let monochromeMask {
            Image(nsImage: NSImage(cgImage: monochromeMask, size: size))
                .renderingMode(.template)
                .foregroundStyle(.primary)
        } else {
            Image(nsImage: NSImage(cgImage: image, size: size))
                .renderingMode(.original)
        }
    }
}
