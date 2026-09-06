function f = g21_objective(x)
% CEC 2006 g21 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x7]
%
% Returns:
% f: Objective function value

f = prod(x);

function g = g21_constraints(x)
% CEC 2006 g21 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x7]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = sum(x) - 1;

function bounds = g21_bounds()
% Returns the bounds for g21 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([0, 10], 7, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = 0.1 * ones(7, 1);
    f_opt = g21_objective(x_opt);
    g_opt = g21_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end