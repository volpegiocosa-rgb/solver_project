function f = g24_objective(x)
% CEC 2006 g24 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2]
%
% Returns:
% f: Objective function value

f = -x(1) - x(2);

function g = g24_constraints(x)
% CEC 2006 g24 constraints.
%
% Parameters:
% x: Decision variables [x1, x2]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(2, 1);
g(1) = -2*x(1)^4 + 8*x(1)^3 - 8*x(1)^2 + x(2) - 2;
g(2) = -4*x(1)^4 + 32*x(1)^3 - 88*x(1)^2 + 96*x(1) + x(2) - 36;

function bounds = g24_bounds()
% Returns the bounds for g24 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = [0, 3; 0, 4];

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [2.329520197; 3.178493074];
    f_opt = g24_objective(x_opt);
    g_opt = g24_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end