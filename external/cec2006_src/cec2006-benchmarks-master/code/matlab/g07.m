function f = g07_objective(x)
% CEC 2006 g07 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x10]
%
% Returns:
% f: Objective function value

f = (x(1)^2 + x(2)^2 + x(1)*x(2) - 14*x(1) - 16*x(2) + ...
     (x(3) - 10)^2 + 4*(x(4) - 5)^2 + (x(5) - 3)^2 + ...
     2*(x(6) - 1)^2 + 5*x(7)^2 + 7*(x(8) - 11)^2 + ...
     2*(x(9) - 10)^2 + (x(10) - 7)^2 + 45);

function g = g07_constraints(x)
% CEC 2006 g07 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x10]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(8, 1);
g(1) = 105 - 4*x(1) - 5*x(2) + 3*x(7) + 9*x(8);
g(2) = 10*x(1) - 8*x(2) - 17*x(7) + 2*x(8);
g(3) = -8*x(1) + 2*x(2) + 5*x(9) - 2*x(10) - 12;
g(4) = 3*(x(1) - 2)^2 + 4*(x(2) - 3)^2 + 2*x(3)^2 - 7*x(4) - 120;
g(5) = 5*x(1)^2 + 8*x(2) + (x(3) - 6)^2 - 2*x(4) - 40;
g(6) = x(1)^2 + 2*(x(2) - 2)^2 - 2*x(1)*x(2) + 14*x(5) - 6*x(6);
g(7) = 0.5*(x(1) - 8)^2 + 2*(x(2) - 4)^2 + 3*x(5)^2 - x(6) - 30;
g(8) = -3*x(1) + 6*x(2) + 12*(x(9) - 8)^2 - 7*x(10);

function bounds = g07_bounds()
% Returns the bounds for g07 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([-10, 10], 10, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [2.171996; 2.363683; 8.773926; 5.095984; 0.9906548; 1.430574; 1.321644; 9.828726; 8.280092; 8.375927];
    f_opt = g07_objective(x_opt);
    g_opt = g07_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end