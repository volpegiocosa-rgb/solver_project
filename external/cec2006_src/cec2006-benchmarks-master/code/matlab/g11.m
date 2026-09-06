function f = g11_objective(x)
% CEC 2006 g11 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2]
%
% Returns:
% f: Objective function value

f = x(1)^2 + (x(2) - 1)^2;

function g = g11_constraints(x)
% CEC 2006 g11 constraints.
%
% Parameters:
% x: Decision variables [x1, x2]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = x(2) - x(1)^2;

function bounds = g11_bounds()
% Returns the bounds for g11 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = [-1, 1; -1, 1];

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [1; 1];
    f_opt = g11_objective(x_opt);
    g_opt = g11_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end