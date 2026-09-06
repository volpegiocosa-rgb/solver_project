import numpy as np

def g06_objective(x):
    """
    CEC 2006 g06 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2]
    
    Returns:
    float: Objective function value
    """
    return (x[0] - 10)**3 + (x[1] - 20)**3

def g06_constraints(x):
    """
    CEC 2006 g06 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(-(x[0] - 5)**2 - (x[1] - 5)**2 + 100)
    g.append((x[0] - 6)**2 + (x[1] - 5)**2 - 82.81)
    return g

def g06_bounds():
    """
    Returns the bounds for g06 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(13, 100), (0, 100)]

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [14.095, 0.84296]  # Approximate
    f_opt = g06_objective(x_opt)
    g_opt = g06_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")