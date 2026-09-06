import numpy as np

def g01_objective(x):
    """
    CEC 2006 g01 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x13]
    
    Returns:
    float: Objective function value
    """
    return 5 * sum(x[:4]) - 5 * sum(xi**2 for xi in x[:4]) - sum(x[4:])

def g01_constraints(x):
    """
    CEC 2006 g01 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x13]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(2*x[0] + 2*x[1] + x[9] + x[10] - 10)
    g.append(2*x[0] + 2*x[2] + x[9] + x[11] - 10)
    g.append(2*x[1] + 2*x[2] + x[10] + x[11] - 10)
    g.append(-8*x[0] + x[9])
    g.append(-8*x[1] + x[10])
    g.append(-8*x[2] + x[11])
    g.append(-2*x[3] - x[4] + x[9])
    g.append(-2*x[5] - x[6] + x[10])
    g.append(-2*x[7] - x[8] + x[11])
    return g

def g01_bounds():
    """
    Returns the bounds for g01 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    bounds = [(0, 1)] * 9 + [(0, 100)] * 3 + [(0, 1)]
    return bounds

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 3, 3, 1]
    f_opt = g01_objective(x_opt)
    g_opt = g01_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")