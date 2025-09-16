function [t_sec_el, ok_el] = local_try_elapsed(target)
ok_el = false; t_sec_el = [];
if isfield(target, 'TimeElapsed') && ~isempty(target.TimeElapsed)
    try
        t_sec_el = seconds(target.TimeElapsed(:));
        ok_el = true;
    catch
        ok_el = false;
    end
end
end

