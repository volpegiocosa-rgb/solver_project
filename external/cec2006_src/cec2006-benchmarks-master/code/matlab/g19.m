function f = g19_objective(x)
% CEC 2006 g19 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x15]
%
% Returns:
% f: Objective function value

c = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0, 2.1, 2.2, 2.3, 2.4];
f = sum(c .* x);

function g = g19_constraints(x)
% CEC 2006 g19 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x15]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(5, 1);
g(1) = -sum(x) + 1;
g(2) = sum(x.^2) - 1/3;
g(3) = -prod(x) + 2.5e-5;
g(4) = sum(x.^3) - 2.5e-4;
g(5) = sum(x.^4) - 2.5e-5;

function bounds = g19_bounds()
% Returns the bounds for g19 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([0, 10], 15, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = 0.5 * ones(15, 1);
    f_opt = g19_objective(x_opt);
    g_opt = g19_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end