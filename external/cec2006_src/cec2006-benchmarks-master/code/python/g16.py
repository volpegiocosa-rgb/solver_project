import numpy as np

def g16_objective(x):
    """
    CEC 2006 g16 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x5]
    
    Returns:
    float: Objective function value
    """
    return 0.0001 * (x[0] - 1)**2 + (x[0] - x[1])**2 + (x[1] - x[2])**3 + (x[2] - x[3])**4 + (x[3] - x[4])**4

def g16_constraints(x):
    """
    CEC 2006 g16 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x5]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(x[0] + x[1]**2 + x[2]**3 - 3)
    g.append(x[1] - x[2]**2 + x[3] + 1)
    g.append(x[0] * x[4] - 1)
    g.append(x[0] + x[1] + x[2] + x[3] + x[4] - 5)
    return g

def g16_bounds():
    """
    Returns the bounds for g16 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 16)] * 5

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [0.5, 0.5, 0.5, 0.5, 0.5]  # Approximate
    f_opt = g16_objective(x_opt)
    g_opt = g16_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")