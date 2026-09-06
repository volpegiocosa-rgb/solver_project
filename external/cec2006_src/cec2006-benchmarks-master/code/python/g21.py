import numpy as np

def g21_objective(x):
    """
    CEC 2006 g21 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x7]
    
    Returns:
    float: Objective function value
    """
    return np.prod(x)

def g21_constraints(x):
    """
    CEC 2006 g21 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x7]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(sum(x) - 1)
    return g

def g21_bounds():
    """
    Returns the bounds for g21 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 10)] * 7

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [0.1] * 7  # Approximate
    f_opt = g21_objective(x_opt)
    g_opt = g21_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")