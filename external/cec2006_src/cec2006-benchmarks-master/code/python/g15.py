import numpy as np

def g15_objective(x):
    """
    CEC 2006 g15 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, x3]
    
    Returns:
    float: Objective function value
    """
    return 1000 - 1/(0.1 + sum(xi**2 for xi in x)) - 1/(0.1 + sum((xi - 1)**2 for xi in x))

def g15_constraints(x):
    """
    CEC 2006 g15 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, x3]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(sum(xi**2 for xi in x) - 0.6)  # Equality as inequality
    g.append(sum((xi - 1)**2 for xi in x) - 0.6)  # Equality as inequality
    return g

def g15_bounds():
    """
    Returns the bounds for g15 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 10), (0, 10), (0, 10)]

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [0.5, 0.5, 0.5]  # Approximate
    f_opt = g15_objective(x_opt)
    g_opt = g15_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")