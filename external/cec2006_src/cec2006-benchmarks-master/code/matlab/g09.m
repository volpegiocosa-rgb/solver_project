function f = g09_objective(x)
% CEC 2006 g09 constrained optimization problem objective function.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x7]
%
% Returns:
% f: Objective function value

f = ((x(1) - 10)^2 + 5*(x(2) - 12)^2 + x(3)^4 + 3*(x(4) - 11)^2 + ...
     10*x(5)^6 + 7*x(6)^2 + x(7)^4 - 4*x(6)*x(7) - 10*x(6) - 8*x(7));

function g = g09_constraints(x)
% CEC 2006 g09 constraints.
%
% Parameters:
% x: Decision variables [x1, x2, ..., x7]
%
% Returns:
% g: Constraint values (should be <= 0 for feasible)

g = zeros(4, 1);
g(1) = -127 + 2*x(1)^2 + 3*x(2)^4 + x(3) + 4*x(4)^2 + 5*x(5);
g(2) = -282 + 7*x(1) + 3*x(2) + 10*x(3)^2 + x(4) - x(5);
g(3) = -196 + 23*x(1) + x(2)^2 + 6*x(6)^2 - 8*x(7);
g(4) = 4*x(1)^2 + x(2)^2 - 3*x(1)*x(2) + 2*x(3)^2 + 5*x(6) - 11*x(7);

function bounds = g09_bounds()
% Returns the bounds for g09 problem.
%
% Returns:
% bounds: [lower, upper] for each variable

bounds = repmat([-10, 10], 7, 1);

% Example usage
if ~exist('x', 'var')
    % Example solution (best known)
    x_opt = [2.330499; 1.951372; -0.4775414; 4.365726; -0.6244870; 1.038131; 1.594227];
    f_opt = g09_objective(x_opt);
    g_opt = g09_constraints(x_opt);
    
    fprintf('Objective value: %f\n', f_opt);
    fprintf('Constraints: ');
    disp(g_opt');
    fprintf('All constraints satisfied: %d\n', all(g_opt <= 0));
end