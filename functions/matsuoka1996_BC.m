function [B, C] = matsuoka1996_BC(T, useMinor)
% MATSUOKA1996_BC  Matsuoka (1996) Table II-based B(T), C(T) interpolation
%   [B, C] = matsuoka1996_BC(T, useMinor)
% Inputs:
%   T        - Temperature [K], scalar or vector
%   useMinor - If true, use B_JC, C_JC in 248–265 K (minor relaxation);
%              below 248 K falls back to main Debye BD, CD. Default false.
% Outputs:
%   B, C     - For eps'' = A/f + B * f.^C  (f in GHz)
%
% Reference: Matsuoka, Fujita & Mae (1996), J. Appl. Phys. 80(10), 5884–5890.
%            Table II: Temperature(K) | BD(×1e-5) BJC(×1e-5) | CD  CJC

    if nargin < 2, useMinor = false; end

    % ----- Table II data -----
    Tgrid = [190 200 220 240 248 253 258 263 265];
    BD_x1e5  = [1.537 1.747 2.469 3.495 4.006 4.380 4.696 5.277 5.646];
    CD_      = [1.175 1.168 1.129 1.088 1.073 1.062 1.056 1.038 1.024];

    % minor relaxation (248–265 K only)
    BJC_x1e5 = [NaN   NaN   NaN   NaN   3.330 3.725 3.924 4.220 4.396];
    CJC_     = [NaN   NaN   NaN   NaN   1.125 1.108 1.107 1.101 1.096];

    % ----- Vectorize & clamp input -----
    T = T(:).';                       % row vector
    Tclip = min(max(T, 190), 265);    % clamp to table bounds

    % ----- Main Debye values -----
    B_D = 1e-5 * interp1(Tgrid, BD_x1e5, Tclip, 'linear');
    C_D =        interp1(Tgrid, CD_,     Tclip, 'linear');

    if ~useMinor
        B = B_D;  C = C_D;
        return;
    end

    % ----- Minor relaxation where defined; fall back elsewhere -----
    hiMask = Tclip >= 248; % JC-defined range

    Tgrid_JC = Tgrid(5:end);
    BJC_vals = BJC_x1e5(5:end);
    CJC_vals = CJC_(5:end);

    B = B_D;  C = C_D;
    if any(hiMask)
        B(hiMask) = 1e-5 * interp1(Tgrid_JC, BJC_vals, Tclip(hiMask), 'linear', 'extrap');
        C(hiMask) =        interp1(Tgrid_JC, CJC_vals, Tclip(hiMask), 'linear', 'extrap');
    end
end

