function f = g06_objective(x)
% CEC 2006 g06 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2]
%
% Returns:
% f: Objective function value

f = (x(1) - 10)^3 + (x(2) - 20)^3;

function g = g06_constraints(x)
% CEC 2006 g06 constraints.
%
% Parameters:
% x: Decision variables [x1, x2]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(2, 1);
g(1) = -(x(1) - 5)^2 - (x(2) - 5)^2 + 100;
g(2) = (x(1) - 6)^2 + (x(2) - 5)^2 - 82.81;

function bounds = g06_bounds()
% Returns the bounds for g06 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = [13, 100; 0, 100];

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [14.095; 0.84296];
    f_opt = g06_objective(x_opt);
    g_opt = g06_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end