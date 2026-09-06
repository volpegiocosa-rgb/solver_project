import numpy as np

def g08_objective(x):
    """
    CEC 2006 g08 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2]
    
    Returns:
    float: Objective function value
    """
    return -np.sin(2*np.pi*x[0])**3 * np.sin(2*np.pi*x[1]) / (x[0]**3 * (x[0] + x[1]))

def g08_constraints(x):
    """
    CEC 2006 g08 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(x[0]**2 - x[1] + 1)
    g.append(1 - x[0] + (x[1] - 4)**2)
    return g

def g08_bounds():
    """
    Returns the bounds for g08 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 10), (0, 10)]

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [1.2279713, 4.2453733]  # Approximate
    f_opt = g08_objective(x_opt)
    g_opt = g08_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")