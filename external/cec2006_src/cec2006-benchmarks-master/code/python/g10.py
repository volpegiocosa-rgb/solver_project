import numpy as np

def g10_objective(x):
    """
    CEC 2006 g10 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x8]
    
    Returns:
    float: Objective function value
    """
    return x[0] + x[1] + x[2]

def g10_constraints(x):
    """
    CEC 2006 g10 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x8]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(-1 + 0.0025*(x[3] + x[5]))
    g.append(-1 + 0.0025*(x[4] + x[6] - x[3]))
    g.append(-1 + 0.01*(x[7] - x[4]))
    g.append(-x[0]*x[5] + 833.33252*x[3] + 100*x[0] - 83333.333)
    g.append(-x[1]*x[6] + 1250*x[4] + x[1]*x[3] - 1250*x[3])
    g.append(-x[2]*x[7] + 1250000 + x[2]*x[4] - 2500*x[4])
    return g

def g10_bounds():
    """
    Returns the bounds for g10 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(100, 10000), (1000, 10000), (1000, 10000), (10, 1000), (10, 1000), (10, 1000), (10, 1000), (10, 1000)]

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [579.3167, 1359.943, 5110.071, 182.0174, 295.5985, 217.9799, 286.4162, 395.5979]  # Approximate
    f_opt = g10_objective(x_opt)
    g_opt = g10_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")