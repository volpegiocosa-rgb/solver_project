import numpy as np

def g02_objective(x):
    """
    CEC 2006 g02 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x20]
    
    Returns:
    float: Objective function value
    """
    term1 = sum(np.cos(xi)**4 for xi in x)
    term2 = 2 * np.prod(np.cos(xi)**2 for xi in x)
    term3 = np.sqrt(sum(i * xi**2 for i, xi in enumerate(x, 1)))
    return -abs((term1 - term2) / term3)

def g02_constraints(x):
    """
    CEC 2006 g02 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x20]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(0.75 - np.prod(x))
    g.append(sum(x) - 7.5 * 20)
    return g

def g02_bounds():
    """
    Returns the bounds for g02 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 10)] * 20

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [0] * 20  # Approximate
    f_opt = g02_objective(x_opt)
    g_opt = g02_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")