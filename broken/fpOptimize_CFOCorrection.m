

model = 'Receiver';
sud = [model,'/HDL_DUT/CFOCorrection'];
open_system(model);

opt = fxpOptimizationOptions();

tol = 0.1;
addTolerance(opt, [model,'/HDL_DUT/out'], 1, 'RelTol', tol);
tol = 0.1;
addTolerance(opt, [model,'/HDL_DUT/out_freq'], 1, 'RelTol', tol);
%opt.AllowableWordLengths = 10:18;
result = fxpopt(model, sud, opt);
