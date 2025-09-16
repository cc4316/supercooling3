function [t_sec_ts, ok_ts, dt_ts] = local_try_timestamps(target)
ok_ts = false; t_sec_ts = []; dt_ts = [];
if isfield(target, 'Timestamps') && ~isempty(target.Timestamps)
    try
        dt_ts = target.Timestamps(:);
        t_sec_ts = posixtime(dt_ts);
        ok_ts = true;
    catch
        ok_ts = false;
    end
end
end

