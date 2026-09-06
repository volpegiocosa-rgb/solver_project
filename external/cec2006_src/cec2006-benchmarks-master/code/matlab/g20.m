function f = g20_objective(x)
% CEC 2006 g20 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x24]
%
% Returns:
% f: Objective function value

c = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 3.0, 3.1, 3.2, 3.3];
f = sum(c .* x);

function g = g20_constraints(x)
% CEC 2006 g20 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x24]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(6, 1);
g(1) = -sum(x) + 1;
g(2) = sum(x.^2) - 1/3;
g(3) = -prod(x) + 2.5e-5;
g(4) = sum(x.^3) - 2.5e-4;
g(5) = sum(x.^4) - 2.5e-5;
g(6) = sum(x.^5) - 2.5e-6;

function bounds = g20_bounds()
% Returns the bounds for g20 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([0, 10], 24, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = 0.5 * ones(24, 1);
    f_opt = g20_objective(x_opt);
    g_opt = g20_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end