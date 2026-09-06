function f = g03_objective(x)
% CEC 2006 g03 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x10]
%
% Returns:
% f: Objective function value

f = -sqrt(10) * sum(x .* (1 + cos((1:10)' * pi .* x)));

function g = g03_constraints(x)
% CEC 2006 g03 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x10]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = sum(x.^2) - 1;

function bounds = g03_bounds()
% Returns the bounds for g03 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([0, 1], 10, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = 0.5 * ones(10, 1);
    f_opt = g03_objective(x_opt);
    g_opt = g03_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end