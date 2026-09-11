function v = giano_stage_vec(val, n)
% GIANO_STAGE_VEC  Espande uno scalare (budget costante per stadio) o un
%   vettore (budget per-stadio, esteso con l'ultimo valore se piu' corto
%   di n) a un vettore 1xn. Porting 1:1 di
%   real_case/run_continuation.m::local_stage_vec.
%
%   INPUT  : val   scalare o vettore
%            n     numero di stadi
%   OUTPUT : v     1xn

    if isscalar(val)
        v = val * ones(1, n);
    else
        v = val(:)';
        if numel(v) < n
            v = [v, v(end) * ones(1, n - numel(v))];
        end
        v = v(1:n);
    end

end
