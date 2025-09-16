function v = local_fetch_if_exist(S, key)
v = [];
if isfield(S, key)
    v = S.(key);
elseif isfield(S, lower(key))
    v = S.(lower(key));
elseif isfield(S, upper(key))
    v = S.(upper(key));
end
end

