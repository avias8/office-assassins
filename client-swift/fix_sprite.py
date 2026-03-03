with open("Sources/OfficeAssassinslient/OfficeAssassinsSprites.swift", "r") as f:
    text = f.read()

target = """        // If we have a Game Center profile image, draw the TV-body character
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

        switch model {"""

replacement = """        // Draw the base character
        switch model {"""

target2 = """        }
    }

    private func drawOperatorLite("""

replacement2 = """        }
        
        // If we have a Game Cenwith open("Sources/OfficeAsss     text = f.read()

target = """        // If we have a Game Center profile imagze
target = """                if let profileCGImage {
            // Fall back to standard drawing with the piRe            // Fall back to stiz            drawPlayerSprite(
                in: &ctx,
                cen
                 in: &ctx,
  ra                center:                   direction: dirtB                isMoving: isMoving,
                  hitFlash: hitFlash t                t: t,
             *                scalsc                model: modeld:                baseColor: b))                lowHealth: lowHealthRe                profileCGImage: prof:             )
            return
        }

 ba          lineWidth: 2 * scale)


          
replacement = """      ge
        switch model {"""

target2 = """        }
= 
target2 = """        }
t,     }

    private fudt
    * 
replacement2 = """        }
                  
        // If we          mg
target = """        // If we have a Game Center profile imagze
target = """    n: target = """                if let profileCGImage {
         ""            // Fall back to standard drawing with te                in: &ctx,
                cen
                 in: &ctx,
  ra                center:                          ite(text)

