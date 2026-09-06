import numpy as np

def g11_objective(x):
    """
    CEC 2006 g11 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2]
    
    Returns:
    float: Objective function value
    """
    return x[0]**2 + (x[1] - 1)**2

def g11_constraints(x):
    """
    CEC 2006 g11 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(x[1] - x[0]**2)  # Equality constraint as inequality
    return g

def g11_bounds():
    """
    Returns the bounds for g11 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(-1, 1), (-1, 1)]

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [1, 1]  # Approximate
    f_opt = g11_objective(x_opt)
    g_opt = g11_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")