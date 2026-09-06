import numpy as np

def g04_objective(x):
    """
    CEC 2006 g04 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, x3, x4, x5]
    
    Returns:
    float: Objective function value
    """
    return 5.3578547 * x[2]**2 + 0.8356891 * x[0] * x[4] + 37.293239 * x[0] - 40792.141

def g04_constraints(x):
    """
    CEC 2006 g04 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, x3, x4, x5]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(85.334407 + 0.0056858 * x[1] * x[4] + 0.0006262 * x[0] * x[3] - 0.0022053 * x[2] * x[4] - 92)
    g.append(-85.334407 - 0.0056858 * x[1] * x[4] - 0.0006262 * x[0] * x[3] + 0.0022053 * x[2] * x[4])
    g.append(80.51249 + 0.0071317 * x[1] * x[4] + 0.0029955 * x[0] * x[1] + 0.0021813 * x[2]**2 - 110)
    g.append(-80.51249 - 0.0071317 * x[1] * x[4] - 0.0029955 * x[0] * x[1] - 0.0021813 * x[2]**2 + 90)
    g.append(9.300961 + 0.0047026 * x[2] * x[4] + 0.0012547 * x[0] * x[2] + 0.0019085 * x[2] * x[3] - 25)
    g.append(-9.300961 - 0.0047026 * x[2] * x[4] - 0.0012547 * x[0] * x[2] - 0.0019085 * x[2] * x[3] + 20)
    return g

def g04_bounds():
    """
    Returns the bounds for g04 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(78, 102), (33, 45), (27, 45), (27, 45), (27, 45)]

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [78, 33, 29.995, 45, 36.776]  # Approximate
    f_opt = g04_objective(x_opt)
    g_opt = g04_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")