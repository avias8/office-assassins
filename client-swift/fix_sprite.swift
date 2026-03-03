import Foundation

let path = "Sources/OfficeAssassinsClient/OfficeAssassinsSprites.swift"
var text = try! String(contentsOfFile: path)

let target = """
        if let profileCGImage {
            // Fall back to standard drawing with the picture overlay on top
            drawPlayerSprite(
                in: &ctx,
                center: center,
                direction: direction,
                isMoving: isMoving,
                hitFlash: hitFlash,
                t: t,
                scale: scale,
                model: model,
                baseColor: baseColor,
                lowHealth: lowHealth,
                profileCGImage: profileCGImage
            )
            return
        }
"""

let replacement = """
        var finalImage: CGImage? = profileCGImage
        
        // Let's just pass this down since the individual draw functions can handle it
        // Or if we need an overarching draw function, we can inline the switch and then add TV
"""

