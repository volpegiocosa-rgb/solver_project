function f = g16_objective(x)
% CEC 2006 g16 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x5]
%
% Returns:
% f: Objective function value

f = 0.0001 * (x(1) - 1)^2 + (x(1) - x(2))^2 + (x(2) - x(3))^3 + (x(3) - x(4))^4 + (x(4) - x(5))^4;

function g = g16_constraints(x)
% CEC 2006 g16 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x5]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(4, 1);
g(1) = x(1) + x(2)^2 + x(3)^3 - 3;
g(2) = x(2) - x(3)^2 + x(4) + 1;
g(3) = x(1) * x(5) - 1;
g(4) = x(1) + x(2) + x(3) + x(4) + x(5) - 5;

function bounds = g16_bounds()
% Returns the bounds for g16 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([0, 16], 5, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [0.5; 0.5; 0.5; 0.5; 0.5];
    f_opt = g16_objective(x_opt);
    g_opt = g16_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end