

model = 'Receiver';
sud = [model,'/HDL_DUT/PacketDetect/PD_Numeric'];
open_system(model);

opt = fxpOptimizationOptions();

tol = 1000;
addTolerance(opt, [model,'/HDL_DUT/PacketDetect/out'], 1, 'AbsTol', tol);
tol = 1000;
addTolerance(opt, [model,'/HDL_DUT/PacketDetect/out1'], 1, 'AbsTol', tol);
tol = 1000;
addTolerance(opt, [model,'/HDL_DUT/PacketDetect/out2'], 1, 'AbsTol', tol);

opt.AllowableWordLengths = 10:16;
result = fxpopt(model, sud, opt);
