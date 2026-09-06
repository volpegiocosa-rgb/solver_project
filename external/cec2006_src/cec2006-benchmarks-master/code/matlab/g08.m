function f = g08_objective(x)
% CEC 2006 g08 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2]
%
% Returns:
% f: Objective function value

f = -sin(2*pi*x(1))^3 * sin(2*pi*x(2)) / (x(1)^3 * (x(1) + x(2)));

function g = g08_constraints(x)
% CEC 2006 g08 constraints.
%
% Parameters:
% x: Decision variables [x1, x2]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(2, 1);
g(1) = x(1)^2 - x(2) + 1;
g(2) = 1 - x(1) + (x(2) - 4)^2;

function bounds = g08_bounds()
% Returns the bounds for g08 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = [0, 10; 0, 10];

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [1.2279713; 4.2453733];
    f_opt = g08_objective(x_opt);
    g_opt = g08_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end