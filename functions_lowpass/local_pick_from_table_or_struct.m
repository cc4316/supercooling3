function [t, s] = local_pick_from_table_or_struct(X)
t = [];
s = [];

if istable(X)
    vnames = X.Properties.VariableNames;
    % time 후보
    tidx = find(contains(lower(vnames), 'time') | contains(lower(vnames), 'timestamp'), 1, 'first');
    % s11 후보
    sidx = find(contains(lower(vnames), 's11'), 1, 'first');
    if ~isempty(tidx)
        t = X{:, tidx};
    end
    if ~isempty(sidx)
        s = X{:, sidx};
        if isnumeric(s) && size(s,2) == 2
            s = complex(s(:,1), s(:,2));
        end
    end
elseif isstruct(X)
    fns = fieldnames(X);
    % time
    timeLike = fns(contains(lower(fns), 'time'));
    if ~isempty(timeLike)
        t = X.(timeLike{1});
    end
    % s11
    sLike = fns(contains(lower(fns), 's11'));
    if ~isempty(sLike)
        s = X.(sLike{1});
        if isnumeric(s) && size(s,2) == 2
            s = complex(s(:,1), s(:,2));
        end
    end
end
end

