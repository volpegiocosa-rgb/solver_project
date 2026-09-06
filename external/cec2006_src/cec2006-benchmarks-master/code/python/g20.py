import numpy as np

def g20_objective(x):
    """
    CEC 2006 g20 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x24]
    
    Returns:
    float: Objective function value
    """
    c = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 3.0, 3.1, 3.2, 3.3]
    return sum(c[i] * x[i] for i in range(24))

def g20_constraints(x):
    """
    CEC 2006 g20 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x24]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(-sum(x) + 1)
    g.append(sum(xi**2 for xi in x) - 1/3)
    g.append(-np.prod(x) + 2.5e-5)
    g.append(sum(xi**3 for xi in x) - 2.5e-4)
    g.append(sum(xi**4 for xi in x) - 2.5e-5)
    g.append(sum(xi**5 for xi in x) - 2.5e-6)
    return g

def g20_bounds():
    """
    Returns the bounds for g20 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 10)] * 24

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [0.5] * 24  # Approximate
    f_opt = g20_objective(x_opt)
    g_opt = g20_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")