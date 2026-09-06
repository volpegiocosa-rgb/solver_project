import numpy as np

def g05_objective(x):
    """
    CEC 2006 g05 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, x3, x4]
    
    Returns:
    float: Objective function value
    """
    return 3 * x[0] + 0.000001 * x[0]**3 + 2 * x[1] + 0.000002/3 * x[1]**3

def g05_constraints(x):
    """
    CEC 2006 g05 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, x3, x4]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(-x[3] + x[2] + 0.55)
    g.append(-x[2] + x[3] + 0.55)
    h1 = 1000 * np.sin(-x[2] - 0.25) + 1000 * np.sin(-x[3] - 0.25) + 894.8 - x[0]
    h2 = 1000 * np.sin(x[2] - 0.25) + 1000 * np.sin(x[2] - x[3] - 0.25) + 1294.8 - x[1]
    h3 = 1000 * np.sin(x[3] - 0.25) + 1000 * np.sin(x[3] - x[2] - 0.25) + 1294.8 - x[1]
    g.append(abs(h1))  # Equality as inequality
    g.append(abs(h2))
    g.append(abs(h3))
    return g

def g05_bounds():
    """
    Returns the bounds for g05 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 1200), (0, 1200), (-0.55, 0.55), (-0.55, 0.55)]

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [679.945, 1026.067, 0.118, -0.396]  # Approximate
    f_opt = g05_objective(x_opt)
    g_opt = g05_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")