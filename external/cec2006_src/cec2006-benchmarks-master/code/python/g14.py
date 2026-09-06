import numpy as np

def g14_objective(x):
    """
    CEC 2006 g14 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x10]
    
    Returns:
    float: Objective function value
    """
    c = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9]
    return sum(c[i] * x[i] for i in range(10))

def g14_constraints(x):
    """
    CEC 2006 g14 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x10]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(-sum(x) + 1)
    g.append(sum(xi**2 for xi in x) - 1/3)
    g.append(-np.prod(x) + 2.5e-5)
    return g

def g14_bounds():
    """
    Returns the bounds for g14 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(0, 10)] * 10

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [0.0406684, 0.1477213, 0.7832057, 0.0014144, 0.4852937, 0.0006932, 0.0274052, 0.0179506, 0.0373262, 0.0968844]  # Approximate
    f_opt = g14_objective(x_opt)
    g_opt = g14_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")