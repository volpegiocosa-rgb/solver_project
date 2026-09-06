function f = g01_objective(x)
% CEC 2006 g01 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x13]
%
% Returns:
% f: Objective function value

f = 5 * sum(x(1:4)) - 5 * sum(x(1:4).^2) - sum(x(5:13));

function g = g01_constraints(x)
% CEC 2006 g01 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x13]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(9, 1);
g(1) = 2*x(1) + 2*x(2) + x(10) + x(11) - 10;
g(2) = 2*x(1) + 2*x(3) + x(10) + x(12) - 10;
g(3) = 2*x(2) + 2*x(3) + x(11) + x(12) - 10;
g(4) = -8*x(1) + x(10);
g(5) = -8*x(2) + x(11);
g(6) = -8*x(3) + x(12);
g(7) = -2*x(4) - x(5) + x(10);
g(8) = -2*x(6) - x(7) + x(11);
g(9) = -2*x(8) - x(9) + x(12);

function bounds = g01_bounds()
% Returns the bounds for g01 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = [repmat([0, 1], 9, 1); repmat([0, 100], 3, 1); [0, 1]];

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 3, 3, 1]';
    f_opt = g01_objective(x_opt);
    g_opt = g01_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end