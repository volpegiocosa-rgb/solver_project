function f = g14_objective(x)
% CEC 2006 g14 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x10]
%
% Returns:
% f: Objective function value

c = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9];
f = sum(c .* x);

function g = g14_constraints(x)
% CEC 2006 g14 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x10]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(3, 1);
g(1) = -sum(x) + 1;
g(2) = sum(x.^2) - 1/3;
g(3) = -prod(x) + 2.5e-5;

function bounds = g14_bounds()
% Returns the bounds for g14 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([0, 10], 10, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [0.0406684; 0.1477213; 0.7832057; 0.0014144; 0.4852937; 0.0006932; 0.0274052; 0.0179506; 0.0373262; 0.0968844];
    f_opt = g14_objective(x_opt);
    g_opt = g14_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end