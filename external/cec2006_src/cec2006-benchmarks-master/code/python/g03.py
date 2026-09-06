import numpy as np

def g03_objective(x):
    """
    CEC 2006 g03 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x10]
    
    Returns:
    float: Objective function value
    """
    return -np.sqrt(10) * sum(xi * (1 + np.cos(i * np.pi * xi)) for i, xi in enumerate(x, 1))

def g03_constraints(x):
    """
    CEC 2006 g03 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x10]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(sum(xi**2 for xi in x) - 1)
    return g

def g03_bounds():
    """
    Returns the bounds for g03 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 1)] * 10

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [0.5] * 10  # Approximate
    f_opt = g03_objective(x_opt)
    g_opt = g03_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")