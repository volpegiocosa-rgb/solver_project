function f = g23_objective(x)
% CEC 2006 g23 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x9]
%
% Returns:
% f: Objective function value

f = 9 * sum(x);

function g = g23_constraints(x)
% CEC 2006 g23 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x9]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(2, 1);
g(1) = -sum(x) + 1;
g(2) = sum(x.^2) - 1/3;

function bounds = g23_bounds()
% Returns the bounds for g23 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([0, 10], 9, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = 0.1 * ones(9, 1);
    f_opt = g23_objective(x_opt);
    g_opt = g23_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end