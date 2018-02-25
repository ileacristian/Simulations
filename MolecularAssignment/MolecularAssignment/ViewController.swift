//
//  ViewController.swift
//  MolecularAssignment
//
//  Created by Cristian Ilea on 2/8/18.
//  Copyright © 2018 Cristian Ilea. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

  @IBOutlet weak var canvas: Canvas!
  var movie: [[Particle]] = []

  @IBOutlet weak var progressView: UIProgressView!
  
  @IBOutlet weak var slider: UISlider!
  @IBOutlet weak var loadingLabel: UILabel!
  override func viewDidLoad() {
    super.viewDidLoad()
    self.canvas.transform = CGAffineTransform(scaleX: 5.5, y: 5.5) // 5.5x larger than the original size of the box
    self.slider.maximumValue = Float(totalTimesteps / snapshotInterval) - 1

    DispatchQueue.global(qos: .userInitiated).async {
      self.movie = run(progress:{progress in
        DispatchQueue.main.async {
          self.progressView.progress = Float(progress)
          if(progress == 1.0) {
            self.loadingLabel.text = "Done"
          }
        }
      })
    }

  }
  @IBAction func didChangeSlider(_ sender: UISlider) {
    let currentFrame = Int(sender.value)
    self.canvas.particles = self.movie[currentFrame]
    self.canvas.setNeedsDisplay()
  }
}

