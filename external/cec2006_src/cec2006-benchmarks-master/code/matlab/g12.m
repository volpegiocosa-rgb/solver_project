function f = g12_objective(x)
% CEC 2006 g12 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, x3]
%
% Returns:
% f: Objective function value

f = -(100 - (x(1) - 5)^2 - (x(2) - 5)^2 - (x(3) - 5)^2) / 100;

function g = g12_constraints(x)
% CEC 2006 g12 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, x3]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = (x(1) - 5)^2 + (x(2) - 5)^2 + (x(3) - 5)^2 - 25;

function bounds = g12_bounds()
% Returns the bounds for g12 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = [0, 10; 0, 10; 0, 10];

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [5; 5; 5];
    f_opt = g12_objective(x_opt);
    g_opt = g12_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end