function f = g13_objective(x)
% CEC 2006 g13 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x5]
%
% Returns:
% f: Objective function value

f = exp(x(1) * x(2) * x(3) * x(4) * x(5));

function g = g13_constraints(x)
% CEC 2006 g13 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x5]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(3, 1);
g(1) = sum(x.^2) - 10;
g(2) = x(2) * x(3) - 5 * x(4) * x(5);
g(3) = x(1)^3 + x(2)^3 + 1;

function bounds = g13_bounds()
% Returns the bounds for g13 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([-2.3, 2.3], 2, 1);
bounds = [bounds; repmat([-3.2, 3.2], 3, 1)];

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [-1.717143; 1.595709; 1.827247; -0.7636413; -0.7636450];
    f_opt = g13_objective(x_opt);
    g_opt = g13_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end