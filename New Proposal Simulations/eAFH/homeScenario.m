rng(1, 'twister');

networkSimulator = wirelessNetworkSimulator.init();

%% Bluetooth LE nodes
centralNode = bluetoothLENodeeFH("central", ...
    Name="Laptop", ...
    Position=[15 6 3], ...
    TransmitterPower=-5, InterferenceFidelity=1);

peripheralNode = bluetoothLENodeeFH("peripheral", ...
    Name="Headset", ...
    Position=[15 7 3.5], ...
    TransmitterPower=-5, InterferenceFidelity=1);

% Connection configuration
connectionConfig = bluetoothLEConnectionConfig;
connectionConfig.Algorithm = 1;
connectionConfig.ConnectionInterval = 0.01;
connectionConfig.ActivePeriod = 0.01;
connectionConfig.ConnectionOffset = 0;
connectionConfig.AccessAddress = '487647F2';
configureConnection(connectionConfig,centralNode,peripheralNode);

% Configure traffic
central2PeripheralTrafficSource = networkTrafficOnOff(...
    OnTime=Inf,OffTime=0, ...
    DataRate=150, PacketSize=50, ...
    GeneratePacket=true);
addTrafficSource(centralNode,central2PeripheralTrafficSource, DestinationNode=peripheralNode.Name);

peripheral2CentralTrafficSource = networkTrafficOnOff(...
    OnTime=Inf,OffTime=0, ...
    DataRate=150, PacketSize=25, ...
    GeneratePacket=true);
addTrafficSource(peripheralNode,peripheral2CentralTrafficSource, ...
    DestinationNode=centralNode.Name);

bluetoothLENodes = [centralNode, peripheralNode];
%% Home Wi-Fi Nodes
wlanChannel = 6;
deviceCfg = wlanDeviceConfig(Mode="AP", ...
    BandAndChannel=[2.4 wlanChannel], ...
    TransmissionFormat="HT-Mixed", ...% Most commonly used so far
    TransmitPower=20); 
apNode = wlanNode( ...
    DeviceConfig=deviceCfg, Position=[5, 10, 5], ...
    MACFrameAbstraction=false, PHYAbstractionMethod="none");

staPositions = [[2 8 1]; [5, 0, 0]; [10 5 2]; [15 6 3]];
% Set band and channel
deviceCfg = wlanDeviceConfig(Mode="STA", ...
    BandAndChannel=[2.4 wlanChannel], ...
    TransmissionFormat="HT-Mixed", ...% Most commonly used so far
    TransmitPower=20);
% Create an array of 3 STA node objects
staNodes = wlanNode( ...
    Position=staPositions, DeviceConfig=deviceCfg, Name=["Tablet", "PC", "Mobile", "Laptop"], ...
    MACFrameAbstraction=false, PHYAbstractionMethod="none");

associateStations(apNode, staNodes, "FullBufferTraffic","on"); % Configure continuous data between wlan devices

%% Outside Home Wi-Fi nodes with lesser power
numOutsideNodes = 5;
outsideNodePositions = [[50 8 1]; [45, 0, 0]; [60 5 2]; [55 6 3]; [40 6 3]];
outsideNodes=[];
for idx=1:numOutsideNodes
    wlanChannel = randi([1, 8], 1, 1);
    deviceCfg = wlanDeviceConfig(Mode="AP", ...
        BandAndChannel=[2.4 wlanChannel], ...
        TransmissionFormat="HT-Mixed", ...% Most commonly used so far
        TransmitPower=0);
    outsideAP = wlanNode( ...
        DeviceConfig=deviceCfg, Position=[40, 10, 5], ...
        MACFrameAbstraction=false, PHYAbstractionMethod="none");


    % Set band and channel
    deviceCfg = wlanDeviceConfig(Mode="STA", ...
        BandAndChannel=[2.4 wlanChannel], ...
        TransmissionFormat="HT-Mixed", ...% Most commonly used so far
        TransmitPower=0);
    % Create an array of 3 STA node objects
    outsidestaNode = wlanNode( ...
        Position=[outsideNodePositions(idx,:)], DeviceConfig=deviceCfg, ...
        MACFrameAbstraction=false, PHYAbstractionMethod="none");

    associateStations(outsideAP, outsidestaNode, "FullBufferTraffic","on"); % Configure continuous data between wlan devices

    outsideNodes=[outsideNodes outsideAP, outsidestaNode]; %#ok<AGROW>
end

wlanNodes = [apNode staNodes outsideNodes];
%% Model Home environment Channnel conditions
pathlossCfg = bluetoothPathLossConfig(Environment='Home');
pathlossHandle = @(rxInfo,txData) updatePathLoss(rxInfo,txData,pathlossCfg); % Path loss function
addChannelModel(networkSimulator,pathlossHandle);

%% Configure Channel Classification and add callbacks
% Classify channels as bad in initial Training period if PDR is less than 50%
% TrainingPeriod = 5;
% LoggingPeriod = 20; % Log the performance every 100 connection events
% classifierObj = hMyAlgo(centralNode,peripheralNode,PDRThreshold=50);
% classifyFcn = @(varargin) classifierObj.classifyChannels;
% userData = [];
% callAt = TrainingPeriod;
% periodicity = LoggingPeriod*connectionConfig.ConnectionInterval;
% 
% scheduleAction(networkSimulator,classifyFcn,userData,callAt,periodicity); % Schedule channel classification

%% Simulation
simulationTime = 20; % seconds
% Add MATLAB helper to view packet transmissions
coexistenceVisualization = helperVisualizeCoexistence(simulationTime,bluetoothLENodes);

% Add the created nodes to simulator
networkSimulator.addNodes(bluetoothLENodes);
networkSimulator.addNodes(wlanNodes);


% Run the simulation
run(networkSimulator, simulationTime);

% Get the bluetooth statistics
bluetoothLEChannelStats = classificationStatistics(coexistenceVisualization,centralNode,peripheralNode);
centralStats = statistics(centralNode);
peripheralStats = statistics(peripheralNode);


function rxData = updatePathLoss(rxInfo,txData,pathlossCfg)
    % Apply pathloss and update output signal
    % persistent powerGraph;
    % if isempty(powerGraph)
    %     fig = figure;
    %     powerGraph=axes(fig);
    %     hold on;
    % end
    rxData = txData;

    % Calculate distance between transmitter and receiver in meters
    distance = norm(rxData.TransmitterPosition - rxInfo.Position);
    pathloss = bluetoothPathLoss(distance,pathlossCfg);
    rxData.Power = rxData.Power - pathloss;
    scale = 10.^(-pathloss/20);
    [numSamples, ~] = size(rxData.Data);
    rxData.Data(1:numSamples,:) = rxData.Data(1:numSamples,:)*scale;

    % xTime=rxData.StartTime:1e-6:rxData.StartTime+rxData.Duration;
    % yTime=(rxData.Power).*ones(1, numel(xTime));
    % plot(powerGraph, xTime, yTime);    
end