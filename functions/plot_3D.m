function plot_3D(X,Y,Z)

figure("Color",[1 1 1]);
surface(X,Y,Z,EdgeColor="none");
grid
xlabel("Frequency, GHz");
ylabel("Ice Thickness, mm")
set(gcf,"Position",[2348 338 416 284]);
colorbar
colormap jet