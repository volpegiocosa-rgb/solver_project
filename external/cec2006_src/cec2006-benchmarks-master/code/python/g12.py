import numpy as np

def g12_objective(x):
    """
    CEC 2006 g12 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, x3]
    
    Returns:
    float: Objective function value
    """
    return -(100 - (x[0] - 5)**2 - (x[1] - 5)**2 - (x[2] - 5)**2) / 100

def g12_constraints(x):
    """
    CEC 2006 g12 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, x3]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append((x[0] - 5)**2 + (x[1] - 5)**2 + (x[2] - 5)**2 - 25)  # Equality as inequality
    return g

def g12_bounds():
    """
    Returns the bounds for g12 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 10), (0, 10), (0, 10)]

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [5, 5, 5]
    f_opt = g12_objective(x_opt)
    g_opt = g12_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")