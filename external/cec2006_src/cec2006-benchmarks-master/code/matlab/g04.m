function f = g04_objective(x)
% CEC 2006 g04 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, x3, x4, x5]
%
% Returns:
% f: Objective function value

f = 5.3578547 * x(3)^2 + 0.8356891 * x(1) * x(5) + 37.293239 * x(1) - 40792.141;

function g = g04_constraints(x)
% CEC 2006 g04 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, x3, x4, x5]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(6, 1);
g(1) = 85.334407 + 0.0056858 * x(2) * x(5) + 0.0006262 * x(1) * x(4) - 0.0022053 * x(3) * x(5) - 92;
g(2) = -85.334407 - 0.0056858 * x(2) * x(5) - 0.0006262 * x(1) * x(4) + 0.0022053 * x(3) * x(5);
g(3) = 80.51249 + 0.0071317 * x(2) * x(5) + 0.0029955 * x(1) * x(2) + 0.0021813 * x(3)^2 - 110;
g(4) = -80.51249 - 0.0071317 * x(2) * x(5) - 0.0029955 * x(1) * x(2) - 0.0021813 * x(3)^2 + 90;
g(5) = 9.300961 + 0.0047026 * x(3) * x(5) + 0.0012547 * x(1) * x(3) + 0.0019085 * x(3) * x(4) - 25;
g(6) = -9.300961 - 0.0047026 * x(3) * x(5) - 0.0012547 * x(1) * x(3) - 0.0019085 * x(3) * x(4) + 20;

function bounds = g04_bounds()
% Returns the bounds for g04 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = [78, 102; 33, 45; 27, 45; 27, 45; 27, 45];

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [78; 33; 29.995; 45; 36.776];
    f_opt = g04_objective(x_opt);
    g_opt = g04_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end