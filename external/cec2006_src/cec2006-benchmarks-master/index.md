---
layout: default
title: "CEC 2006 Constrained Benchmarks"
---

# CEC 2006 Constrained Optimization Benchmarks

This repository provides comprehensive documentation and reference implementations for the 24 constrained optimization problems (g01-g24) from the CEC 2006 Special Session on Constrained Real-Parameter Optimization.

## Overview

The CEC 2006 benchmark suite consists of 24 constrained optimization problems designed to test the performance of optimization algorithms on problems with various types of constraints. These problems were introduced in the technical report:

> Liang, J. J., Runarsson, T. P., Mezura-Montes, E., Clerc, M., Suganthan, P. N., Coello Coello, C. A., & Deb, K. (2006). Problem definitions and evaluation criteria for the CEC 2006 special session on constrained real-parameter optimization. Journal of Applied Mechanics, 41(8), 8-31.

## Problem Summary

| Problem | Variables (n) | Type | Constraints | Best Known Value |
|---------|---------------|------|-------------|------------------|
| [g01](/problems/g01/) | 13 | Quadratic | 9 | -15.000000 |
| [g02](/problems/g02/) | 20 | Nonlinear | 2 | -0.803619 |
| [g03](/problems/g03/) | 10 | Polynomial | 1 | -1.000500 |
| [g04](/problems/g04/) | 5 | Quadratic | 6 | -30665.539 |
| [g05](/problems/g05/) | 4 | Cubic | 2 | 5126.498 |
| [g06](/problems/g06/) | 2 | Cubic | 2 | -6961.814 |
| [g07](/problems/g07/) | 10 | Quadratic | 8 | 24.306209 |
| [g08](/problems/g08/) | 2 | Nonlinear | 2 | 0.095825 |
| [g09](/problems/g09/) | 7 | Polynomial | 4 | 680.630057 |
| [g10](/problems/g10/) | 8 | Linear | 6 | 7049.331 |
| [g11](/problems/g11/) | 2 | Quadratic | 1 | 0.749900 |
| [g12](/problems/g12/) | 3 | Quadratic | 1 | -1.000000 |
| [g13](/problems/g13/) | 5 | Nonlinear | 3 | 0.053942 |
| [g14](/problems/g14/) | 10 | Nonlinear | 3 | -47.764888 |
| [g15](/problems/g15/) | 3 | Quadratic | 2 | 961.715022 |
| [g16](/problems/g16/) | 5 | Nonlinear | 4 | -1.905155 |
| [g17](/problems/g17/) | 6 | Nonlinear | 4 | 8853.539674 |
| [g18](/problems/g18/) | 9 | Quadratic | 13 | -0.866025 |
| [g19](/problems/g19/) | 15 | Nonlinear | 5 | 32.655592 |
| [g20](/problems/g20/) | 24 | Linear | 6 | 0.204979 |
| [g21](/problems/g21/) | 7 | Linear | 1 | 193.724510 |
| [g22](/problems/g22/) | 22 | Linear | 19 | 236.431221 |
| [g23](/problems/g23/) | 9 | Linear | 2 | -400.055100 |
| [g24](/problems/g24/) | 2 | Linear | 2 | -5.508013 |

## Usage

Each problem page contains:
- Mathematical formulation
- Variable bounds and constraints
- Best known solution value
- Reference implementations in Python and MATLAB

## Reference Implementations

- [Python implementations](/code/python/)
- [MATLAB implementations](/code/matlab/)

## Citation

If you use these benchmarks in your research, please cite:

```
@article{liang2006problem,
  title={Problem definitions and evaluation criteria for the CEC 2006 special session on constrained real-parameter optimization},
  author={Liang, JJ and Runarsson, TP and Mezura-Montes, E and Clerc, M and Suganthan, PN and Coello Coello, CA and Deb, K},
  journal={Journal of Applied Mechanics},
  volume={41},
  number={8},
  pages={8--31},
  year={2006}
}
```