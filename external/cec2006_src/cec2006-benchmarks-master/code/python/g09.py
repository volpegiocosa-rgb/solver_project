import numpy as np

def g09_objective(x):
    """
    CEC 2006 g09 constrained optimization problem objective function.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x7]
    
    Returns:
    float: Objective function value
    """
    return ((x[0] - 10)**2 + 5*(x[1] - 12)**2 + x[2]**4 + 3*(x[3] - 11)**2 + 
            10*x[4]**6 + 7*x[5]**2 + x[6]**4 - 4*x[5]*x[6] - 10*x[5] - 8*x[6])

def g09_constraints(x):
    """
    CEC 2006 g09 constraints.
    
    Parameters:
    x (array-like): Decision variables [x1, x2, ..., x7]
    
    Returns:
    list: Constraint values (should be <= 0 for feasible)
    """
    g = []
    g.append(-127 + 2*x[0]**2 + 3*x[1]**4 + x[2] + 4*x[3]**2 + 5*x[4])
    g.append(-282 + 7*x[0] + 3*x[1] + 10*x[2]**2 + x[3] - x[4])
    g.append(-196 + 23*x[0] + x[1]**2 + 6*x[5]**2 - 8*x[6])
    g.append(4*x[0]**2 + x[1]**2 - 3*x[0]*x[1] + 2*x[2]**2 + 5*x[5] - 11*x[6])
    return g

def g09_bounds():
    """
    Returns the bounds for g09 problem.
    
    Returns:
    list: [(lower, upper), ...] for each variable
    """
    return [(-10, 10)] * 7

# Example usage
if __name__ == "__main__":
    # Example solution (best known)
    x_opt = [2.330499, 1.951372, -0.4775414, 4.365726, -0.6244870, 1.038131, 1.594227]  # Approximate
    f_opt = g09_objective(x_opt)
    g_opt = g09_constraints(x_opt)
    
    print(f"Objective value: {f_opt}")
    print(f"Constraints: {g_opt}")
    print(f"All constraints satisfied: {all(g <= 0 for g in g_opt)}")