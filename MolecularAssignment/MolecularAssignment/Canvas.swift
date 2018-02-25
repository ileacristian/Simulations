//
//  Canvas.swift
//  MolecularAssignment
//
//  Created by Cristian Ilea on 2/9/18.
//  Copyright © 2018 Cristian Ilea. All rights reserved.
//

import UIKit

class Canvas: UIView {

  var particles: [Particle] = []

  override func draw(_ rect: CGRect) {

    for particle in particles {
      let particleSize = CGSize(width: 1, height: 1)
      let particlePosition = CGPoint(x: (particle.x / systemSizeX) * rect.width, y: (particle.y / systemSizeY) * rect.height)

      let path = UIBezierPath(ovalIn: CGRect(origin: particlePosition, size: particleSize))
      particle.color.setFill()
      path.fill()
    }
  }
}
