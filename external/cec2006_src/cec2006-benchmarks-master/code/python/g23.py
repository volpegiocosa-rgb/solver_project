import numpy as np

def g23_objective(x):
    """
    CEC 2006 g23 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x9]
    
    Returns:
    float: Objective function value
    """
    return 9 * sum(x)

def g23_constraints(x):
    """
    CEC 2006 g23 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x9]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(-sum(x) + 1)
    g.append(sum(xi**2 for xi in x) - 1/3)
    return g

def g23_bounds():
    """
    Returns the bounds for g23 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 10)] * 9

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [0.1] * 9  # Approximate
    f_opt = g23_objective(x_opt)
    g_opt = g23_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")