function f = g10_objective(x)
% CEC 2006 g10 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x8]
%
% Returns:
% f: Objective function value

f = x(1) + x(2) + x(3);

function g = g10_constraints(x)
% CEC 2006 g10 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x8]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(6, 1);
g(1) = -1 + 0.0025*(x(4) + x(6));
g(2) = -1 + 0.0025*(x(5) + x(7) - x(4));
g(3) = -1 + 0.01*(x(8) - x(5));
g(4) = -x(1)*x(6) + 833.33252*x(4) + 100*x(1) - 83333.333;
g(5) = -x(2)*x(7) + 1250*x(5) + x(2)*x(4) - 1250*x(4);
g(6) = -x(3)*x(8) + 1250000 + x(3)*x(5) - 2500*x(5);

function bounds = g10_bounds()
% Returns the bounds for g10 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = [100, 10000; 1000, 10000; 1000, 10000; 10, 1000; 10, 1000; 10, 1000; 10, 1000; 10, 1000];

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [579.3167; 1359.943; 5110.071; 182.0174; 295.5985; 217.9799; 286.4162; 395.5979];
    f_opt = g10_objective(x_opt);
    g_opt = g10_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end