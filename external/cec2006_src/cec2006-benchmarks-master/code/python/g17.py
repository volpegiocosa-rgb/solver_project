import numpy as np

def g17_objective(x):
    """
    CEC 2006 g17 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x6]
    
    Returns:
    float: Objective function value
    """
    c = [1, 1.1, 1.2, 1.3, 1.4, 1.5]
    return sum(c[i] * x[i] for i in range(6))

def g17_constraints(x):
    """
    CEC 2006 g17 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x6]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(-sum(x) + 1)
    g.append(sum(xi**2 for xi in x) - 1/3)
    g.append(-np.prod(x) + 2.5e-5)
    g.append(sum(xi**3 for xi in x) - 2.5e-4)
    return g

def g17_bounds():
    """
    Returns the bounds for g17 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 10)] * 6

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [0.5] * 6  # Approximate
    f_opt = g17_objective(x_opt)
    g_opt = g17_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")