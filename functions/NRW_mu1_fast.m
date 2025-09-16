
function [eps_r, freq] = NRW_mu1_fast(Sobj, band, ref_port)
    freq = Sobj.Frequencies; freq = freq(:);
    S = Sobj.Parameters;

    S11 = S(1,1,:); S11 = S11(:);
    S21 = S(2,1,:); S21 = S21(:);
    S12 = S(1,2,:); S12 = S12(:);
    S22 = S(2,2,:); S22 = S22(:);

    c0  = physconst('LightSpeed');
    lambda0 = c0./freq;
    if band == 'K'
        fc  = 14.051e9;   % for K-band
    else
        fc  = 6.557e9; % for X-band
    end
    lambdac = c0/fc;
    
    if ref_port == 1
        X = (S11.^2 - S21.^2 + 1)./(2.*S11);
    elseif ref_port == 2
        X = (S22.^2 - S12.^2 + 1)./(2.*S22);
    else
        error('Invalid reference port');
    end

    Gamma = X + sign(real(X)).*sqrt(X.^2 - 1);              
    G = (1 - Gamma)./(1 + Gamma);                           
    zero_c = lambda0.^2/lambdac.^2;
    eps_r = G.^2 .* (1 - zero_c) + zero_c;            
end
