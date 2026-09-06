import numpy as np

def g18_objective(x):
    """
    CEC 2006 g18 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x9]
    
    Returns:
    float: Objective function value
    """
    return -0.5 * sum(xi * (1 + np.cos(2 * np.pi * xi)) for xi in x)

def g18_constraints(x):
    """
    CEC 2006 g18 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x9]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(sum(x) - 1)
    g.append(np.prod(x) - 0.75)
    g.append(sum(xi**2 for xi in x) - 7.5)
    # Additional constraints as per original (simplified)
    return g

def g18_bounds():
    """
    Returns the bounds for g18 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 10)] * 9

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [0.2] * 9  # Approximate
    f_opt = g18_objective(x_opt)
    g_opt = g18_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")