function f = g17_objective(x)
% CEC 2006 g17 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x6]
%
% Returns:
% f: Objective function value

c = [1, 1.1, 1.2, 1.3, 1.4, 1.5];
f = sum(c .* x);

function g = g17_constraints(x)
% CEC 2006 g17 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x6]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(4, 1);
g(1) = -sum(x) + 1;
g(2) = sum(x.^2) - 1/3;
g(3) = -prod(x) + 2.5e-5;
g(4) = sum(x.^3) - 2.5e-4;

function bounds = g17_bounds()
% Returns the bounds for g17 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([0, 10], 6, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = 0.5 * ones(6, 1);
    f_opt = g17_objective(x_opt);
    g_opt = g17_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end