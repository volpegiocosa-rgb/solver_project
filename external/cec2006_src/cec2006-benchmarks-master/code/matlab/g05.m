function f = g05_objective(x)
% CEC 2006 g05 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, x3, x4]
%
% Returns:
% f: Objective function value

f = 3 * x(1) + 0.000001 * x(1)^3 + 2 * x(2) + 0.000002/3 * x(2)^3;

function g = g05_constraints(x)
% CEC 2006 g05 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, x3, x4]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(5, 1);
g(1) = -x(4) + x(3) + 0.55;
g(2) = -x(3) + x(4) + 0.55;
h1 = 1000 * sin(-x(3) - 0.25) + 1000 * sin(-x(4) - 0.25) + 894.8 - x(1);
h2 = 1000 * sin(x(3) - 0.25) + 1000 * sin(x(3) - x(4) - 0.25) + 1294.8 - x(2);
h3 = 1000 * sin(x(4) - 0.25) + 1000 * sin(x(4) - x(3) - 0.25) + 1294.8 - x(2);
g(3) = abs(h1);
g(4) = abs(h2);
g(5) = abs(h3);

function bounds = g05_bounds()
% Returns the bounds for g05 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = [0, 1200; 0, 1200; -0.55, 0.55; -0.55, 0.55];

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [679.945; 1026.067; 0.118; -0.396];
    f_opt = g05_objective(x_opt);
    g_opt = g05_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end