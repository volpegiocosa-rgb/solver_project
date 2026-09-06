import numpy as np

def g07_objective(x):
    """
    CEC 2006 g07 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x10]
    
    Returns:
    float: Objective function value
    """
    return (x[0]**2 + x[1]**2 + x[0]*x[1] - 14*x[0] - 16*x[1] + 
            (x[2] - 10)**2 + 4*(x[3] - 5)**2 + (x[4] - 3)**2 + 
            2*(x[5] - 1)**2 + 5*x[6]**2 + 7*(x[7] - 11)**2 + 
            2*(x[8] - 10)**2 + (x[9] - 7)**2 + 45)

def g07_constraints(x):
    """
    CEC 2006 g07 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x10]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(105 - 4*x[0] - 5*x[1] + 3*x[6] + 9*x[7])
    g.append(10*x[0] - 8*x[1] - 17*x[6] + 2*x[7])
    g.append(-8*x[0] + 2*x[1] + 5*x[8] - 2*x[9] - 12)
    g.append(3*(x[0] - 2)**2 + 4*(x[1] - 3)**2 + 2*x[2]**2 - 7*x[3] - 120)
    g.append(5*x[0]**2 + 8*x[1] + (x[2] - 6)**2 - 2*x[3] - 40)
    g.append(x[0]**2 + 2*(x[1] - 2)**2 - 2*x[0]*x[1] + 14*x[4] - 6*x[5])
    g.append(0.5*(x[0] - 8)**2 + 2*(x[1] - 4)**2 + 3*x[4]**2 - x[5] - 30)
    g.append(-3*x[0] + 6*x[1] + 12*(x[8] - 8)**2 - 7*x[9])
    return g

def g07_bounds():
    """
    Returns the bounds for g07 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(-10, 10)] * 10

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [2.171996, 2.363683, 8.773926, 5.095984, 0.9906548, 1.430574, 1.321644, 9.828726, 8.280092, 8.375927]  # Approximate
    f_opt = g07_objective(x_opt)
    g_opt = g07_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")