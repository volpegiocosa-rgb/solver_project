function f = g15_objective(x)
% CEC 2006 g15 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, x3]
%
% Returns:
% f: Objective function value

f = 1000 - 1/(0.1 + sum(x.^2)) - 1/(0.1 + sum((x - 1).^2));

function g = g15_constraints(x)
% CEC 2006 g15 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, x3]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(2, 1);
g(1) = sum(x.^2) - 0.6;
g(2) = sum((x - 1).^2) - 0.6;

function bounds = g15_bounds()
% Returns the bounds for g15 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([0, 10], 3, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [0.5; 0.5; 0.5];
    f_opt = g15_objective(x_opt);
    g_opt = g15_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end