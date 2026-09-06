function f = g02_objective(x)
% CEC 2006 g02 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x20]
%
% Returns:
% f: Objective function value

term1 = sum(cos(x).^4);
term2 = 2 * prod(cos(x).^2);
term3 = sqrt(sum((1:20)' .* x.^2));
f = -abs((term1 - term2) / term3);

function g = g02_constraints(x)
% CEC 2006 g02 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x20]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(2, 1);
g(1) = 0.75 - prod(x);
g(2) = sum(x) - 7.5 * 20;

function bounds = g02_bounds()
% Returns the bounds for g02 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([0, 10], 20, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = zeros(20, 1);
    f_opt = g02_objective(x_opt);
    g_opt = g02_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end