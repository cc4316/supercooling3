function [t_sec, elapsed_used, ok, t_dt] = local_pick_timevec(useTime, ok_ts, t_sec_ts, dt_ts, ok_el, t_sec_el)
t_sec = []; elapsed_used = ''; ok = false; t_dt = [];
prefer_ts = strcmp(useTime, 'timestamps') || strcmp(useTime, 'auto');
prefer_el = strcmp(useTime, 'elapsed')    || strcmp(useTime, 'auto');
if prefer_ts && ok_ts
    t_sec = t_sec_ts; t_dt = dt_ts; ok = true; elapsed_used = 'timestamps'; return;
end
if prefer_el && ok_el
    t_sec = t_sec_el; t_dt = []; ok = true; elapsed_used = 'elapsed+offset'; return;
end
% 둘 다 안 되면 사용 가능한 것 아무거나
if ok_ts
    t_sec = t_sec_ts; t_dt = dt_ts; ok = true; elapsed_used = 'timestamps'; return;
elseif ok_el
    t_sec = t_sec_el; t_dt = []; ok = true; elapsed_used = 'elapsed+offset'; return;
end
end

