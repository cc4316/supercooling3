function [X,Y,Z] = hfss_3d2xyz(file)

data = readmatrix(file);
Xdata = unique(data(:,1));
Ydata = unique(data(:,2));
Zdata = data(:,3);

[Y, X] = meshgrid(Ydata, Xdata);
Z = reshape(Zdata, numel(Xdata),[]);