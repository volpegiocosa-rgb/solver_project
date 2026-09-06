# CEC 2006 Constrained Benchmarks

This repository provides comprehensive documentation and reference implementations for the 24 constrained optimization problems (g01-g24) from the CEC 2006 Special Session on Constrained Real-Parameter Optimization.

## Overview

The CEC 2006 benchmark suite consists of 24 constrained optimization problems designed to test the performance of optimization algorithms on problems with various types of constraints. These problems were introduced in the technical report:

> Liang, J. J., Runarsson, T. P., Mezura-Montes, E., Clerc, M., Suganthan, P. N., Coello Coello, C. A., & Deb, K. (2006). Problem definitions and evaluation criteria for the CEC 2006 special session on constrained real-parameter optimization. Journal of Applied Mechanics, 41(8), 8-31.

## Features

- **Complete Documentation**: Detailed mathematical formulations for all 24 problems
- **Reference Implementations**: Python and MATLAB code for each problem
- **Best Known Values**: Reported optimal solutions from the literature
- **GitHub Pages Site**: Easy-to-navigate web interface
- **Research Ready**: Suitable for benchmarking metaheuristic algorithms

## Repository Structure

```
cec2006-benchmarks/
├── _config.yml          # Jekyll configuration
├── index.md            # Main page
├── about.md            # About page
├── problems/           # Individual problem pages
│   ├── g01.md
│   ├── g02.md
│   └── ...
├── code/               # Reference implementations
│   ├── python/
│   └── matlab/
├── assets/             # CSS and other assets
└── README.md           # This file
```

## Usage

### For Researchers
1. Browse the [problem documentation](/problems/) to understand each benchmark
2. Use the reference implementations as starting points for your algorithms
3. Compare your results against the best known values

### For Students
1. Study the mathematical formulations and constraints
2. Implement your own versions of the problems
3. Test optimization algorithms on these benchmarks

## Implementation Details

Each problem implementation includes:
- Objective function evaluation
- Constraint function evaluation
- Variable bounds
- Example usage with best known solution

## Citation

If you use these benchmarks in your research, please cite the original technical report:

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

## Contributing

Contributions are welcome! Please feel free to:
- Report errors in implementations
- Suggest improvements to documentation
- Add implementations in other programming languages
- Propose new benchmark variants

## License

This project is released under the MIT License. The CEC 2006 benchmark problems are in the public domain.

## Contact

For questions or suggestions, please open an issue on GitHub.