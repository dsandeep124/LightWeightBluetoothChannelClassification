rng(1, 'twister');

networkSimulator = wirelessNetworkSimulator.init();

%% Bluetooth LE nodes
centralNode = bluetoothLENode("central", ...
    Name="Laptop", ...
    Position=[15 6 3], ...
    TransmitterPower=-5, InterferenceFidelity=0);

peripheralNode = bluetoothLENode("peripheral", ...
    Name="Headset", ...
    Position=[15 7 3.5], ...
    TransmitterPower=-5, InterferenceFidelity=0);

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
%% Wi-Fi Nodes randomly changing the channel between [1, 8] every 5 second
wlanChannel = 6;
apNode = helperInterferingWLANNode(...
            WaveformSource='BasebandFile', ...
            Position=[5, 10, 5], ...
            Name="WLAN node", ...
            TransmitterPower=20, ...
            CenterFrequency=wlanChannelFrequency(wlanChannel, 2.4), ...
            Bandwidth = 20e6, ...
            SignalPeriodicity=0.0029);

staPositions = [[2 8 1]; [5, 0, 0]; [10 5 2]; [15 6 3]];
% Create an array of 3 STA node objects
for idx=1:4
    staNodes(idx)   = helperInterferingWLANNode(...
        WaveformSource='BasebandFile', ...
        Position=staPositions(idx,:), ...
        Name="WLAN node", ...
        TransmitterPower=20, ...
        CenterFrequency=wlanChannelFrequency(wlanChannel, 2.4), ...
        Bandwidth = 20e6, ...
        SignalPeriodicity=0.0029);
end
% staNodes = wlanNode( ...
%     Position=staPositions, DeviceConfig=deviceCfg, Name=["Tablet", "PC", "Mobile", "Laptop"], ...
%     MACFrameAbstraction=false, PHYAbstractionMethod="none");
% 
% associateStations(apNode, staNodes, "FullBufferTraffic","on"); % Configure continuous data between wlan devices
%% Outside Wi-Fi nodes with lesser power
numOutsideNodes = 5;
outsideNodePositions = [[50 8 1]; [45, 0, 0]; [60 5 2]; [55 6 3]; [40 6 3]];
outsideNodes=[];
for idx=1:numOutsideNodes
    wlanChannel = randi([1, 8], 1, 1);
    outsideAP = helperInterferingWLANNode(...
        WaveformSource='BasebandFile', ...
        Position=[5, 10, 5], ...
        Name="WLAN node", ...
        TransmitterPower=0, ...
        CenterFrequency=wlanChannelFrequency(wlanChannel, 2.4), ...
        Bandwidth = 20e6, ...
        SignalPeriodicity=0.0029);


    outsideSTA = helperInterferingWLANNode(...
        WaveformSource='BasebandFile', ...
        Position=[5, 10, 5], ...
        Name="WLAN node", ...
        TransmitterPower=0, ...
        CenterFrequency=wlanChannelFrequency(wlanChannel, 2.4), ...
        Bandwidth = 20e6, ...
        SignalPeriodicity=0.0029);

    outsideNodes=[outsideNodes outsideAP, outsideSTA]; %#ok<AGROW>
end

wlanNodes = [apNode staNodes outsideNodes];
%% Outside Bluetooth LE Nodes
numNodes = 10;
xPositions = randi([-50, 50], numNodes/2, 1);
yPositions = xPositions+randi([-2, 2], numNodes/2, 1);
zPositions = randi([-5, 5], numNodes/2, 1);

outdoorBluetoothNodesPositions = [xPositions yPositions zPositions];

outsideCentrals=[];outsidePeripherals=[];
for idx=1:numNodes/2
    c=bluetoothLENode('central', Position=[outdoorBluetoothNodesPositions(idx,:)],TransmitterPower=0);
    p=bluetoothLENode('peripheral', Position=[outdoorBluetoothNodesPositions(idx,:)], TransmitterPower=0);

    % Connection configuration
    connectionConfig = bluetoothLEConnectionConfig(AccessAddress=hgenerateValidAccessAddress('hex'));
    configureConnection(connectionConfig,c,p);

    % Configure traffic
    central2PeripheralTrafficSource = networkTrafficOnOff(...
        OnTime=Inf,OffTime=0, ...
        DataRate=100, PacketSize=50, ...
        GeneratePacket=true);
    addTrafficSource(c,central2PeripheralTrafficSource, DestinationNode=p.Name);

    peripheral2CentralTrafficSource = networkTrafficOnOff(...
        OnTime=Inf,OffTime=0, ...
        DataRate=100, PacketSize=50, ...
        GeneratePacket=true);
    addTrafficSource(p,peripheral2CentralTrafficSource, ...
        DestinationNode=c.Name);

    outsideCentrals    = [outsideCentrals    c];
    outsidePeripherals = [outsidePeripherals p];
end
outdoorBluetoothLENodes = [outsideCentrals outsidePeripherals];

%% Model Large indoor conditions
pathlossCfg = bluetoothPathLossConfig(Environment='Office');
pathlossHandle = @(rxInfo,txData) updatePathLoss(rxInfo,txData,pathlossCfg); % Path loss function
addChannelModel(networkSimulator,pathlossHandle);

%% Configure Channel Classification and add callbacks
% Classify channels as bad in initial Training period if PDR is less than 50%
classifierObj = helperBluetoothChannelClassification(centralNode,peripheralNode);
classifyFcn = @(varargin) classifierObj.classifyChannels;
userData = [];
callAt = 0;
periodicity = 2;

scheduleAction(networkSimulator,classifyFcn,userData,callAt,periodicity); % Schedule channel classification

%% Add callback to update bluetooth node position
% Classify channels as bad in initial Training period if PDR is less than 50%
classifyFcn = @(varargin) updateBluetoothNodesPositions;
userData = [];
callAt = 0;
periodicity = 1;
scheduleAction(networkSimulator,classifyFcn,userData,callAt,periodicity); % Schedule node position update

%% Simulation
simulationTime = 20; % seconds
% Add MATLAB helper to view packet transmissions
coexistenceVisualization = helperVisualizeCoexistence(simulationTime,bluetoothLENodes);

% Add the created nodes to simulator
networkSimulator.addNodes(bluetoothLENodes);
networkSimulator.addNodes(outdoorBluetoothLENodes);
networkSimulator.addNodes(wlanNodes);


% Run the simulation
run(networkSimulator, simulationTime);

% Get the bluetooth statistics
bluetoothLEChannelStats = classificationStatistics(coexistenceVisualization,centralNode,peripheralNode);
centralStats = statistics(centralNode);
peripheralStats = statistics(peripheralNode);

function updateBluetoothNodesPositions()
netsim = wirelessNetworkSimulator.getInstance();
netsimNodes = netsim.Nodes;
reqCentralNode = netsimNodes{cellfun(@(x) strcmp(x.Name, "Laptop"), netsimNodes)};
reqPeripheralNode = netsimNodes{cellfun(@(x) strcmp(x.Name, "Headset"), netsimNodes)};

% Set position to next meter along x-axis
reqCentralNode.Position(1) = reqCentralNode.Position(1)+1;
reqPeripheralNode.Position(1) = reqPeripheralNode.Position(1)+1;
end

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