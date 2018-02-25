#include "verlet_grid.h"
#include <cmath>
#include <stdlib.h>
#include <cstdio>

using namespace std;

double *tabulated_f_per_r;
int N_tabulated;
double tabulalt_start, tabulalt_lepes;

void c_tabulate_forces()
{
    int i;
    double x_min,x_max;
    double x2,x;
    double f;
    
    x_min = 0.1;
    x_max = 6.0;
    
    N_tabulated = 50000;
    tabulated_f_per_r = (double *) malloc(N_tabulated*sizeof(double));
    for(i=0;i<N_tabulated;i++)
    {
        x2 = i*(x_max*x_max-x_min*x_min)/(N_tabulated-1.0) + x_min*x_min;
        x = sqrt(x2);
        f = 1/x2 * exp(-0.25*x);
        tabulated_f_per_r[i] = f/x;
    }


    tabulalt_start = x_min * x_min;
    tabulalt_lepes = (x_max*x_max-x_min*x_min)/(N_tabulated-1.0);
}

double c_force_for_distance(double dx, double dy)
{
  double dr2 = dx*dx+dy*dy;

  int tab_index = (int)floor((dr2-tabulalt_start)/(tabulalt_lepes));
  if ((tab_index>=N_tabulated))
  {
    return 0.0;
  }
  else
  {
    return tabulated_f_per_r[tab_index];
  }
}

typedef struct cell_t {
  int *ps;
  int n;
} cell;

cell **grid;
const int cell_size = 2;
int grid_cells_per_axis;

int *vlist1 = NULL;
int *vlist2 = NULL;
int N_vlist;
int N;
double SX, SY;
double SX2, SY2;

int flag_to_rebuild_Verlet;


int c_verlet_length()
{
  return N_vlist;
}

int verlet_particle_pair1(int position)
{
  return vlist1[position];
}

int verlet_particle_pair2(int position)
{
  return vlist2[position];
}

void initialize_grid(int nr_of_particles, double systemSize) {
  N = nr_of_particles;
  SX = systemSize;
  SY = systemSize;
  SX2 = SX / 2.0;
  SY2 = SY / 2.0;
  grid_cells_per_axis = (int) ceil(SX / (double) cell_size);

  grid = (cell **) malloc(grid_cells_per_axis * sizeof(cell *));
  for (int i = 0; i < grid_cells_per_axis; i++) {
    grid[i] = (cell *) malloc(grid_cells_per_axis * sizeof(cell));
  }

  for (int i = 0; i < grid_cells_per_axis; i++)
    for (int j = 0; j < grid_cells_per_axis; j++) {
      grid[i][j].ps = (int *) malloc(N * sizeof(int));
      grid[i][j].n = 0;
    }
}

void clear_grid() {
  for (int i = 0; i < grid_cells_per_axis; i++)
    for (int j = 0; j < grid_cells_per_axis; j++) {
      grid[i][j].n = 0;
    }
}

void compute_cell_position(int p, int *x, int *y) {
  double particle_x = x_for_particle_at(p);
  double particle_y = y_for_particle_at(p);

  *x = (int) floor(particle_x / cell_size);
  *y = (int) floor(particle_y / cell_size);
}

int is_cell_out_of_bound(int x, int y) {
  if ((x >= grid_cells_per_axis) ||
      (x < 0) ||
      (y >= grid_cells_per_axis) ||
      (y < 0)) {
    return 1;
  } else {
    return 0;
  }
}

void get_neighbour_cells(int x, int y, int *ret_cells_x, int *ret_cells_y, int *ret_n) {
  int x_offsets[5] = {0, 0, 1, 1, 1};
  int y_offsets[5] = {0, 1, -1, 0, 1};
  int n = 0;
  for (int i = 0; i < 5; i++) {
    int new_x = x + x_offsets[i];
    int new_y = y + y_offsets[i];
    if (is_cell_out_of_bound(new_x, new_y) == 0) {
      ret_cells_x[n] = new_x;
      ret_cells_y[n] = new_y;
      n += 1;
    }
  }
  *ret_n = n;
}

void add_to_grid(int p) {
  int x, y;
  compute_cell_position(p, &x, &y);

  int n = grid[x][y].n;
  if (n > N) {
    printf("e bai mare");

  }
  grid[x][y].ps[n] = p;
  grid[x][y].n += 1;
}

void rebuild_grid() {
  clear_grid();

  for (int i = 0; i < N; i++) {
    add_to_grid(i);
  }
}



void rebuild_verlet_list_grid_optimization() {
  int i, j, ix;
  double dx, dy, dr2;

  N_vlist = 0;
  vlist1 = (int *) realloc(vlist1, N_vlist * sizeof(int));
  vlist2 = (int *) realloc(vlist2, N_vlist * sizeof(int));
  rebuild_grid();

  int neighbour_cells_x[5];
  int neighbour_cells_y[5];
  int neighbour_cell_count;
  for (i = 0; i < N; i++) {
    int cell_x, cell_y;
    compute_cell_position(i, &cell_x, &cell_y);
    get_neighbour_cells(cell_x, cell_y, neighbour_cells_x, neighbour_cells_y, &neighbour_cell_count);
    for (int cell_i = 0; cell_i < neighbour_cell_count; cell_i++) {
      cell current_cell = grid[neighbour_cells_x[cell_i]][neighbour_cells_y[cell_i]];
      for (ix = 0; ix < current_cell.n; ix++) {
        j = current_cell.ps[ix];
        dx = x_for_particle_at(i) - x_for_particle_at(j);
        dy = y_for_particle_at(i) - y_for_particle_at(j);

        //PBC check
        //(maybe the neighbor cell copy is closer)

        if (dx > SX2) dx -= SX;
        if (dx < -SX2) dx += SX;
        if (dy > SY2) dy -= SY;
        if (dy < -SY2) dy += SY;

        dr2 = dx * dx + dy * dy;
        if (dr2 <= 36.0) //instead of 4*4 I will take 6*6
        {
//          printf("%d", N_vlist);
          N_vlist += 2;
          vlist1 = (int *) realloc(vlist1, N_vlist * sizeof(int));
          vlist2 = (int *) realloc(vlist2, N_vlist * sizeof(int));
          vlist1[N_vlist - 2] = i;
          vlist1[N_vlist - 1] = j;
          vlist2[N_vlist - 2] = j;
          vlist2[N_vlist - 1] = i;
        }
      }
    }
  }

  //once I rebuilt the Verlet list,
  //I can start counting the distances again
//  for (i = 0; i < nr_of_particles; i++) {
//    particles[i].drx_so_far = 0.0;
//    particles[i].dry_so_far = 0.0;
//  }
//  flag_to_rebuild_Verlet = 0;
}
