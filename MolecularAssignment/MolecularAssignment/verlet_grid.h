//
//  main.h
//  MolecularAssignment
//
//  Created by Cristian Ilea on 2/9/18.
//  Copyright © 2018 Cristian Ilea. All rights reserved.
//

#ifndef verlet_grid_h
#define verlet_grid_h

#ifdef __cplusplus
extern "C" {
#endif
  void c_run();
  void c_tabulate_forces();
  double c_force_for_distance(double dx, double dy);
  double x_for_particle_at(int i);
  double y_for_particle_at(int i);
  void rebuild_verlet_list_grid_optimization();
  void initialize_grid(int nr_of_particles, double systemSize);
  int c_verlet_length();
  int verlet_particle_pair1(int position);
  int verlet_particle_pair2(int position);
#ifdef __cplusplus
}


#endif

#endif /* verlet_grid_h */
