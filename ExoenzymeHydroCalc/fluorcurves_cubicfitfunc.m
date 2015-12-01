function out=fluorcurves_cubicfitfunc(x,p)
out = p(1)*x.^3 + p(2)*x.^2 + p(3)*x + p(4);