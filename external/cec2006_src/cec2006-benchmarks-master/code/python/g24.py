import numpy as np

def g24_objective(x):
    """
    CEC 2006 g24 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2]
    
    Returns:
    float: Objective function value
    """
    return -x[0] - x[1]

def g24_constraints(x):
    """
    CEC 2006 g24 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(-2*x[0]**4 + 8*x[0]**3 - 8*x[0]**2 + x[1] - 2)
    g.append(-4*x[0]**4 + 32*x[0]**3 - 88*x[0]**2 + 96*x[0] + x[1] - 36)
    return g

def g24_bounds():
    """
    Returns the bounds for g24 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 3), (0, 4)]

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [2.329520197, 3.178493074]  # Approximate
    f_opt = g24_objective(x_opt)
    g_opt = g24_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")