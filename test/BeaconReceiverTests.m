classdef BeaconReceiverTests < matlab.unittest.TestCase
 
    properties
        TestFigure
        TargetChannelFrequency = 5.765e9;
        BBFilename = 'IQData.bb';
        frameSize = 2^18;
        frames = 20;
        SampleRate = 20e6;
        EnableVisuals = false;
        ScopesToDisable = {'Constellation','Scope','Spectrum'};
    end
 
    methods(TestMethodSetup)
        function addSavedCaptures(~)
            addpath(genpath('captures'));
        end
    end
 
    methods(TestMethodTeardown)
%         function closeFigure(testCase)
%             close(testCase.TestFigure)
%         end
    end
 
    methods (Static)
        function DisableScopes(modelname,blocktypes)
            for block = blocktypes
                scopes = find_system(modelname,'CaseSensitive','off',...
                    'regexp','on','LookUnderMasks','all',...
                    'blocktype',block{:});
                delete_block(scopes);
            end
        end
    end
    
    methods
        
        function CollectRealWorldData(testCase)
            
            %% Capture WiFi Data
            rx = sdrrx('Pluto');
            rx.GainSource = 'AGC Fast Attack';
            %rx.GainSource= 'Manual';
            %rx.Gain = 60;
            rx.BasebandSampleRate = testCase.SampleRate;
            rx.CenterFrequency = testCase.TargetChannelFrequency;
            rx.SamplesPerFrame = testCase.frameSize;
            
            packets = complex(zeros(testCase.frameSize,testCase.frames,'int16'));
            log(testCase,sprintf('Capture duration %f seconds\n',...
                testCase.frameSize*testCase.frames/rx.BasebandSampleRate));
            
            rx();rx();rx();
            for frame = 1:testCase.frames
                packets(:,frame) = rx();
            end
            
            packets = reshape(packets,numel(packets),1);
            %% Write to file
            bb = comm.BasebandFileWriter;
            bb.Filename = testCase.BBFilename;
            bb.CenterFrequency = rx.CenterFrequency;
            bb.SampleRate = rx.BasebandSampleRate;
            bb(packets);
            %% Cleanup
            bb = []; %#ok<*NASGU>
            clear rx;
        end
        
        function numValidPackets = BaselineReceiver(testCase)
            
            basebandReader = comm.BasebandFileReader( ...
                'Filename', testCase.BBFilename, ...
                'SamplesPerFrame', 80*2); % Number of samples in 1 OFDM symbol at 20 MHz
            rxFrontEnd = nonHTFrontEnd('ChannelBandwidth', 'CBW20');
            rxFrontEnd.SymbolTimingThreshold = 0.7;
            cfgRec = wlanRecoveryConfig('EqualizationMethod', 'ZF');
            
            % Symbol-by-symbol streaming process
            numValidPackets = 0;
            while ~isDone(basebandReader)
                % Pull in one OFDM symbol, i.e. 80 samples
                data = basebandReader();
%                 data = resample(double(data),1,2);
                
                % Perform front-end processing and payload buffering
                [payloadFull, cfgNonHT, rxNonHTData, chanEst, noiseVar] = ...
                    rxFrontEnd(double(data));                
                if payloadFull
                    % Recover payload bits
                    rxNonHTData = rxNonHTData(1:(floor(length(rxNonHTData)/80)*80));
                    recBits = wlanNonHTDataRecover(rxNonHTData, chanEst, ...
                        noiseVar, cfgNonHT, cfgRec);
                    
                    % Evaluate recovered bits
%                     fprintf('MCS %d | PSDULength %d\n',cfgNonHT.MCS,cfgNonHT.PSDULength);
%                     if cfgNonHT.MCS==0
%                        fprintf('Found\n'); 
%                     end
                    [validBeacon, MPDU] = nonHTBeaconRxMPDUDecode(recBits); %#ok<*ASGLU>
                    if validBeacon
                        nonHTBeaconRxOutputDisplay(MPDU); % Display SSID
                        numValidPackets = numValidPackets + 1;
                    end
                end
            end
            log(testCase,[num2str(numValidPackets), ' Valid Beacon Packets Found']);
            %% Cleanup
            release(basebandReader);
            release(rxFrontEnd);
        end
        
        function SetModelBBFile(testCase,modelname,stopTime)
            % Set model parameters
            load_system(modelname);
            %open(modelname);
            % Disable linked libraries so we can remove scopes
            %set_param(gcb,'LinkStatus','none')
%             set_param([modelname,'/Baseband File Reader'],'LinkStatus','none')
            if ~testCase.EnableVisuals
                testCase.DisableScopes(modelname,testCase.ScopesToDisable);
            end
            %CloseAllScopes(modelname);
            set_param([modelname,'/Baseband File Reader'],...
                'InheritSampleTimeFromFile',1);
            set_param([modelname,'/Baseband File Reader'],...
                'Filename',testCase.BBFilename);
            set_param([modelname,'/Baseband File Reader'],...
                'SamplesPerFrame',num2str(2500));
%             stopTime = testCase.frameSize*testCase.frames/testCase.SampleRate;
            set_param(modelname,'StopTime',num2str(stopTime))
        end
        
        function results = RunModel(~,modelname)
            % Run receiver
            sim(modelname);
            % Close simulink
            close_system(modelname, false);
            bdclose('all');
            % Pack results
            results = struct('goodpackets',goodpackets(end),...
                'badpackets',badpackets(end));
            % Check results
            %testCase.checkResults(results);
        end
        
    end
    
    methods(Test)
        %%
%         function TestWLANFloatingReference(testCase)
%             % Set a good know data file
%             testCase.BBFilename = 'BeaconsCollins20MHzInt16.bb';
%             found = testCase.BaselineReceiver();
%             testCase.verifyEqual(found, 10, ...
%                 'Baseline received failed')
%         end
        %%
        function TestSimulinkFloatingPointReceiverLoopbackSig(testCase)
            import matlab.unittest.constraints.IsEqualTo;
            modelname = 'Baseline';
            % Set a good know data file
            testCase.BBFilename = 'BeaconsLoopbackInt16.bb';
            stopTime = 0.04;
            % Update model
            testCase.SetModelBBFile(modelname,stopTime);
            % Run model
            results = testCase.RunModel(modelname);
            % Check
            testCase.verifyThat(results.goodpackets, IsEqualTo(10), 'Incorrect packet count found');
        end
        %%
        function TestSimulinkFloatingPointReceiverRefSig(testCase)
            import matlab.unittest.constraints.IsEqualTo;
            modelname = 'Baseline';
            % Set a good know data file
            testCase.BBFilename = 'BeaconsReferenceInt16.bb';
            stopTime = 0.04;
            % Update model
            testCase.SetModelBBFile(modelname,stopTime);
            % Run model
            results = testCase.RunModel(modelname);
            % Check
            testCase.verifyThat(results.goodpackets, IsEqualTo(10), 'Incorrect packet count found');
        end
        %%
%         function TestSimulinkFixedPointReceiver(testCase)
%             modelname = 'FrameReceiverFixedPoint';
%             % Set a good know data file
%             testCase.BBFilename = 'collins13.bb';
%             % Update model
%             testCase.SetModelBBFile(modelname);
%             % Run model
%             results = testCase.RunModel(modelname);
%             % Check
%             testCase.verifyThat(results.goodpackets,...
%                 IsEqualTo(13,'Within',AbsoluteTolerance(2)));
%         end
        %%
%         function TestSimulinkFixedPointReceiverMultipleSources(testCase)
%             modelname = 'FrameReceiverFloatPoint_Auto';
%             
%             filenames = {'BeaconsCollins40MHzInt16.bb',...
%                 'BeaconsLoopbackInt16.bb','BeaconsReferenceInt16.bb'};
%             stopTime = [0.02,0.02,0.8];
%             
%             for k=1:length(filenames)
%                 % Set a good know data file
%                 testCase.BBFilename = filenames{k};
%                 % Update model
%                 testCase.SetModelBBFile(modelname, stopTime(k));
%                 % Run model
%                 results = testCase.RunModel(modelname);
%             end
%             % Check
% %             testCase.verifyThat(results.goodpackets,...
% %                 IsEqualTo(13,'Within',AbsoluteTolerance(2)));
%         end
        %%
%         function LiveDataTest(testCase)
% %             modelname = 'FrameReceiverFixedPoint';
%             modelname = 'Receiver';
%             % Set a good know data file
%             testCase.BBFilename = 'BeaconsLoopbackInt16.bb.bb';
%             tries = 10;
%             for t = 1:tries
%                 testCase.CollectRealWorldData();
%                 found = testCase.BaselineReceiver();
%                 if found<2
%                     log(testCase,['Capture too small (',num2str(found),') for test']);
%                     continue;
%                 end
%                 % Update model
%                 stopTime = testCase.frameSize*testCase.frames/testCase.SampleRate;
%                 testCase.SetModelBBFile(modelname,stopTime);
%                 % Run model
%                 results = testCase.RunModel(modelname);
%                 % Check
%                 testCase.verifyThat(results.goodpackets,...
%                 IsEqualTo(found,'Within',AbsoluteTolerance(2)));
%                 break;
%             end
%         end
        
    end
 
end