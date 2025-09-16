function A = A_Matsuoka1996(T)
% A_Matsuoka1996  A(T) term from Matsuoka et al. (1996)
%   T in K (scalar or array)
%   Returns A for eps''(f,T) = A(T)/f + B(T)*f.^C(T), with f in GHz.
%
%   Based on Curie–Weiss and Arrhenius relations:
%     b = 23700, T0 = 15 (Eq.5)
%     t0 = 5.33e-16, R = 8.314 (Eq.6)
%     E = 55.3e3 J/mol for T >= 223 K; else 22.6e3 J/mol
%     tau = t0 * exp(E/(R*T))
%     fr  = 1/(2*pi*tau)
%     A   = (b/(T - T0)) * fr  (Eq.4)-(5)

    b = 23700;  T0 = 15;              % Curie–Weiss (Eq.5)
    t0 = 5.33e-16; R = 8.314;         % (Eq.6)
    E = (T>=223).*55.3e3 + (T<223).*22.6e3; % J/mol
    tau = t0 .* exp(E./(R*T));        % Arrhenius \tau
    fr  = 1./(2*pi*tau);              % fr = 1/(2\pi\tau)
    A   = (b./(T - T0)) .* fr;        % (Eq.4)-(5)
end

