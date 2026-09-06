function f = g18_objective(x)
% CEC 2006 g18 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x9]
%
% Returns:
% f: Objective function value

f = -0.5 * sum(x .* (1 + cos(2 * pi * x)));

function g = g18_constraints(x)
% CEC 2006 g18 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x9]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(3, 1);
g(1) = sum(x) - 1;
g(2) = prod(x) - 0.75;
g(3) = sum(x.^2) - 7.5;

function bounds = g18_bounds()
% Returns the bounds for g18 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([0, 10], 9, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = 0.2 * ones(9, 1);
    f_opt = g18_objective(x_opt);
    g_opt = g18_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end