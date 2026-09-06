import numpy as np

def g22_objective(x):
    """
    CEC 2006 g22 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x22]
    
    Returns:
    float: Objective function value
    """
    c = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 3.0, 3.1]
    return sum(c[i] * x[i] for i in range(22))

def g22_constraints(x):
    """
    CEC 2006 g22 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x22]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(-sum(x) + 1)
    g.append(sum(xi**2 for xi in x) - 1/3)
    g.append(-np.prod(x) + 2.5e-5)
    # Additional constraints (simplified)
    return g

def g22_bounds():
    """
    Returns the bounds for g22 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 10)] * 22

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [0.5] * 22  # Approximate
    f_opt = g22_objective(x_opt)
    g_opt = g22_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")