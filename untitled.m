clear variables;
dataDir = '/MATLAB Drive/supercooling3/expdata/2025-08-25 - K-band_patch/sParam/2025-08-25  08-10-43.s2p';
sparam = sparameters(dataDir);

rfplot(sparam);
ylim([-40 0]);
legend off;