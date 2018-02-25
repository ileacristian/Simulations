//
//  File.swift
//  MolecularAssignment
//
//  Created by Cristian Ilea on 2/9/18.
//  Copyright © 2018 Cristian Ilea. All rights reserved.
//

import UIKit

let systemSizeX: CGFloat = 35
let systemSizeY: CGFloat = 35

let numberOfParticles: Int = 450
let timeStepSize: CGFloat = 0.002
let totalTimesteps: Int = 5_000
let snapshotInterval: Int = 1
let gridSize: Int = 3

var gridCell: [[Int]] = []
var particles: [Particle] = []

// we don't write it to file, we just store it in memory (didn't have time to serialize)
// a "movie" consists of snapshots (frames)
// a frame is an array of particles at a specific moment
// frames are added to the "movie" after each timestep
var movie: [[Particle]] = []


var verletList: [(p1: Particle, p2: Particle)] = []

var shouldRebuildVerletList: Bool = false

var cachedForces: [CGFloat] = []

class Particle {
  var drx_so_far: CGFloat
  var dry_so_far: CGFloat
  var x: CGFloat
  var y: CGFloat
  var fx: CGFloat
  var fy: CGFloat
  var color: UIColor

  init(particle: Particle) {
    self.x = particle.x
    self.y = particle.y
    self.fx = particle.fx
    self.fy = particle.fy
    self.drx_so_far = particle.drx_so_far
    self.dry_so_far = particle.dry_so_far
    self.color = particle.color
  }

  convenience init() {
    self.init(x: rand() * systemSizeX, y: rand() * systemSizeY)
  }

  init(x: CGFloat, y: CGFloat) {
    drx_so_far = 0
    dry_so_far = 0
    fx = 0
    fy = 0
    color = rand() < 0.5 ? .red : .blue
    self.x = x
    self.y = y
  }

  func move() {
    let deltaX = fx * timeStepSize
    let deltaY = fy * timeStepSize

    x += deltaX
    y += deltaY
    drx_so_far += deltaX
    dry_so_far += deltaY

    if (drx_so_far*drx_so_far + dry_so_far*dry_so_far) >= 0.4 {
      shouldRebuildVerletList = true
    }

    if x > systemSizeX { x -= systemSizeX }
    if y > systemSizeY { y -= systemSizeY }
    if x < 0.0 { x += systemSizeX }
    if y < 0.0 { y += systemSizeY }

    fx = 0.0
    fy = 0.0
  }

  func distanceTo(particle: Particle) -> CGFloat {
    var dx = x - particle.x
    var dy = y - particle.y

    if dx > (systemSizeX / 2.0) { dx -= systemSizeX }
    if dx < (-systemSizeX / 2.0) { dx += systemSizeX }
    if dy > (systemSizeY / 2.0) { dy -= systemSizeY }
    if dy < (-systemSizeY / 2.0) { dy += systemSizeY }

    let distanceSquared = dx*dx + dy*dy
    let distance = sqrt(distanceSquared)
    return distance
  }

  func overlaps(particle: Particle) -> Bool {
    return distanceTo(particle: particle) <= 0.2
  }

  class func getNonOverlappingParticle() -> Particle {
    var overlap = false
    var newParticle: Particle

    repeat {
      overlap = false
      newParticle = Particle()

      for particle in particles {
        if newParticle.overlaps(particle: particle) {
          overlap = true
          print("overlap")
          break;
        }
      }
    } while (overlap)

    return newParticle
  }
}

func initializeParticles() {
  for _ in 0..<numberOfParticles {
    let newParticle = Particle.getNonOverlappingParticle()
    particles.append(newParticle)
  }
}


func moveParticles() {
  for particle in particles {
    particle.move()
  }
}

func calculatePairwiseForces() {
  for pair in verletList {
    let p1 = pair.p1
    let p2 = pair.p2

//    let d = p1.distanceTo(particle: p2)
//    let f: CGFloat

    var dx = p1.x - p2.x
    var dy = p1.y - p2.y

    if dx > (systemSizeX / 2.0) { dx -= systemSizeX }
    if dx < (-systemSizeX / 2.0) { dx += systemSizeX }
    if dy > (systemSizeY / 2.0) { dy -= systemSizeY }
    if dy < (-systemSizeY / 2.0) { dy += systemSizeY }

    let f = CGFloat(c_force_for_distance(Double(dx), Double(dy)))
    let fx = f * dx
    let fy = f * dy

//    if d < 0.3 {
//      // problem - why did we end up here?
//      f = 0.1  //97.53 - in the prof.'s code he uses 97. seems high after some tests?
//    } else {
//      f = 1.0 / (d) //* exp(-0.25 * d)
//    }
//    let fx = f * (p1.x - p2.x) / d
//    let fy = f * (p1.y - p2.y) / d


    p1.fx += fx
    p1.fy += fy

    p2.fx -= fx
    p2.fy -= fy
  }
}

func calculatePairwiseForcesWithVerletGrid() {
//  print("calculate \(c_verlet_length())")
  for i in 0..<c_verlet_length() {
    let p1 = particles[Int(verlet_particle_pair1(i))]
    let p2 = particles[Int(verlet_particle_pair2(i))]

    var dx = p1.x - p2.x
    var dy = p1.y - p2.y

    if dx > (systemSizeX / 2.0) { dx -= systemSizeX }
    if dx < (-systemSizeX / 2.0) { dx += systemSizeX }
    if dy > (systemSizeY / 2.0) { dy -= systemSizeY }
    if dy < (-systemSizeY / 2.0) { dy += systemSizeY }

    let f = CGFloat(c_force_for_distance(Double(dx), Double(dy)))
    let fx = f * dx
    let fy = f * dy

    p1.fx += fx
    p1.fy += fy

    p2.fx -= fx
    p2.fy -= fy
  }
}

func calculateExternalForces() {
  for particle in particles {
    particle.fx += particle.color == .red ? 1 : -1
  }
}

func rebuildVerletListNoGrid() -> [(p1: Particle, p2: Particle)] {
  var newVerletList:[(p1: Particle, p2: Particle)] = []
  for i in 0..<particles.count {
    for j in (i+1)..<particles.count {
      let d = particles[i].distanceTo(particle: particles[j])
      if d < 6.0 {
        newVerletList.append((p1: particles[i], p2: particles[j]))
      }
    }
  }
  return newVerletList
}

// TODO: this should have used the verlet grid optimization
func rebuildVerletListWithGrid() {
//  let list: [(p1: Particle, p2: Particle)] = []
//
//  let cellSizeX = systemSizeX / CGFloat(gridSize)
//  let cellSizeY = systemSizeX / CGFloat(gridSize)
//
//  for i in 0..<gridSize {
//    for j in 0..<gridSize {
//      //
//    }
//  }
}

func writeMovie() {
  var currentFrame: [Particle] = []

  for particle in particles {
    currentFrame.append(Particle(particle: particle))
  }

  movie.append(currentFrame)
}

func rand() -> CGFloat {
  return CGFloat(arc4random_uniform(UInt32.max)) / CGFloat(UInt32.max)
}

func averageMovement() -> CGFloat {
  var distancesAfter1Timestep: [CGFloat] = []
  for i  in 0..<particles.count {
    if movie.count < 2 {
      return 0.0
    }
    let previous_x = movie[movie.count - 2][i].x
    let previous_y = movie[movie.count - 2][i].y
    let last_x = movie[movie.count - 1][i].x
    let last_y = movie[movie.count - 1][i].y
    let dx = last_x - previous_x
    let dy = last_y - previous_y

    let distance = sqrt(dx*dx + dy*dy)

    distancesAfter1Timestep.append(distance)
  }
  print(distancesAfter1Timestep.max())
  return distancesAfter1Timestep.reduce(0, +) / CGFloat(distancesAfter1Timestep.count)
}

@_silgen_name("x_for_particle_at")
public func x_for_particle_at(i: Int) -> Double {
  return Double(particles[i].x)
}

@_silgen_name("y_for_particle_at")
public func y_for_particle_at(i: Int) -> Double {
  return Double(particles[i].y)
}

func run(progress: (_ percent:CGFloat)->Void ) -> [[Particle]] {
  c_tabulate_forces()

  //initialize_grid(Int32(numberOfParticles), Double(systemSizeX))
  initializeParticles()
  //rebuild_verlet_list_grid_optimization()

  verletList = rebuildVerletListNoGrid()

  var start = DispatchTime.now()

  for t in 0..<totalTimesteps {
//    calculatePairwiseForcesWithVerletGrid()
    calculatePairwiseForces()
    calculateExternalForces()
    moveParticles()

    if shouldRebuildVerletList {
//      rebuild_verlet_list_grid_optimization()
//      for p in particles {
//        p.drx_so_far = 0
//        p.dry_so_far = 0
//      }
      verletList = rebuildVerletListNoGrid()
    }

    if t % snapshotInterval == 0 {
      writeMovie()
    }



    if t % 500 == 0 {
      let end = DispatchTime.now()
      let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
      let timeInterval = Double(nanoTime) / 1_000_000_000
      print("currently at t: \(t) --- took: \(timeInterval)")
      print("general movement: \(averageMovement())")
      progress(CGFloat(t)/CGFloat(totalTimesteps))
      start = DispatchTime.now()
    }
  }
  progress(1.0)
  return movie
}
