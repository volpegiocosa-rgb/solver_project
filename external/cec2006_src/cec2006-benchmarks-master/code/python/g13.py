import numpy as np

def g13_objective(x):
    """
    CEC 2006 g13 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x5]
    
    Returns:
    float: Objective function value
    """
    return np.exp(x[0] * x[1] * x[2] * x[3] * x[4])

def g13_constraints(x):
    """
    CEC 2006 g13 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x5]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(sum(xi**2 for xi in x) - 10)  # Equality as inequality
    g.append(x[1] * x[2] - 5 * x[3] * x[4])  # Equality as inequality
    g.append(x[0]**3 + x[1]**3 + 1)  # Equality as inequality
    return g

def g13_bounds():
    """
    Returns the bounds for g13 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(-2.3, 2.3), (-2.3, 2.3), (-3.2, 3.2), (-3.2, 3.2), (-3.2, 3.2)]

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [-1.717143, 1.595709, 1.827247, -0.7636413, -0.7636450]  # Approximate
    f_opt = g13_objective(x_opt)
    g_opt = g13_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")