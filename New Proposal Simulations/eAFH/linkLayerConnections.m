classdef linkLayerConnections < handle
    %linkLayerConnections Create an object for modeling Bluetooth LE (low
    %energy) link layer connections
    %
    %   Note: This is an internal undocumented class and its API and/or
    %   functionality may change in subsequent releases.
    %
    %   LLCONNS = linkLayerConnections creates an object, LLCONNS, for modeling
    %   the connections at Bluetooth LE link layer between Bluetooth LE nodes
    %   (central and peripheral roles) with default values.
    %
    %   LLCONNS = linkLayerConnections(Name=Value) creates a Bluetooth LE LL
    %   connections object, LLCONNS, with the specified property Name set to
    %   the specified Value. You can specify additional name-value pair
    %   arguments in any order as (Name1=Value1, ..., NameN=ValueN).
    %
    %   linkLayerConnections properties:
    %
    %   Role               - Bluetooth LE device role in the piconet
    %   TransmitterPower   - Packet transmission power in dBm
    %   PeripheralCount    - Number of peripherals associated with the central
    %                        in the link layer

    %   Copyright 2021-2023 The MathWorks, Inc.

    properties
        %Role Bluetooth LE device role in the piconet
        %   Specify Bluetooth LE device role as one of "central" | "peripheral". It
        %   indicates the role of Bluetooth LE node at link layer. The default
        %   value is "central".
        Role = "central"

        %TransmitterPower Packet transmission power in dBm
        %   Specify the transmitter power as a scalar double value in the range
        %   [-20, 20]. Units are in dBm. The default value is 20 dBm.
        TransmitterPower = 20

        %PeripheralCount Number of peripherals associated with the Central node in
        %the link layer
        %   Specify the number of peripherals as a nonnegative integer representing
        %   the number of peripherals associated with the central in the link layer
        %   of the node. This property is applicable only when the Role is set to
        %   "central". The default value is 1.
        PeripheralCount = 1
    end

    properties (Hidden)
        % Maximum size of the link layer queue for each connection to store the
        % packets from the upper-layers
        MaxQueueSize = 32

        % Maximum size of the packet (upper-layer payload) to be stored in the
        % queue is 251 octets according to Bluetooth Core Specification v5.3 | Vol
        % 6, PART B, Section 2.4.
        MaxPacketSize = 251

        %NotificationFcn Function handle of the triggerEvent method of
        %bluetoothLENode object with dynamic event name and event data to update
        %the event information. Event data is a structure with the corresponding
        %fields based on the events.
        NotificationFcn
    end

    properties (Constant, Hidden)
        % States of the LL state machine
        STANDBY_STATE = 0
        TRANSMIT_STATE = 1
        RECEIVE_STATE = 2
        SLEEP_STATE = 3

        %MaxConnectionEventCount Maximum value for the connection event counter
        MaxConnectionEventCount = 65535

        % Time for inter frame space in microseconds. Time interval between
        % consecutive packets on the same channel index.
        TIFS = 150 % in microseconds
    end

    % Interface with PHY
    properties (SetAccess = private)
        %PacketReceptionEnded Structure containing metadata for
        %PacketReceptionEnded event
        PacketReceptionEnded = struct("NodeName", blanks(0), ...
            "NodeID", [], ...
            "CurrentTime",[],...
            "SourceNode",blanks(0),...
            "SourceID", 0,...
            "SuccessStatus",false,...
            "PDU",[],...
            "AccessAddress",blanks(0),...
            "PHYMode",blanks(0),...
            "ChannelIndex",[],...
            "PacketDuration", 0, ...
            "ReceivedPower",[],...
            "SINR",[]);

        %ChannelMapUpdated Structure containing metadata for ChannelMapUpdated
        %event
        ChannelMapUpdated = struct("NodeName", blanks(0), ...
            "NodeID", [], ...
            "CurrentTime",[],...
            "PeerNode",blanks(0),...
            "PeerID",[],...
            "UpdatedChannelList",zeros(0,1));

        %ConnectionEventEnded Structure containing the metadata for
        %ConnectionEventEnded event
        ConnectionEventEnded = struct("NodeName", blanks(0), ...
            "NodeID", [], ...
            "Counter", 0, ...
            "TransmittedPackets", 0, ...
            "ReceivedPackets", 0, ...
            "CRCFailedPackets", 0)

        %ConnectionStats Statistics of all the connections specified as a structure
        %or array of structures. Each structure represents the statistics of the
        %corresponding connection.
        ConnectionStats = struct( ...
            "PeerNodeName", "", ...                 % Name of the connected peer node
            "PeerNodeID", -1, ...                   % ID of the connected peer node
            "TransmissionTime", 0, ...              % Time taken for transmission, in microseconds
            "IdleTime", 0, ...                      % Total time the node was in idle, in microseconds
            "SleepTime", 0, ...                     % Total time the node was in sleep, in microseconds
            "ListenTime",0, ...                     % Time taken for reception, in microseconds
            "TransmittedPackets", 0, ...            % Total number of transmitted packets
            "TransmittedEmptyPackets", 0, ...       % Total number of transmitted empty packets
            "TransmittedDataPackets", 0, ...        % Total number of transmitted unique data packets
            "RetransmittedDataPackets", 0, ...      % Total number of retransmitted data packets
            "TransmittedControlPackets", 0, ...     % Total number of transmitted control packets
            "RetransmittedControlPackets", 0, ...   % Total number of retransmiited control packets
            "TransmitQueueOverflow", 0, ...         % Total number of times the queue overflowed
            "TransmittedBytes", 0, ...              % Total number transmitted bytes
            "TransmittedPayloadBytes", 0, ...       % Total number of transmitted unique payload bytes
            "AcknowledgedPackets", 0, ...           % Total number of acknowledged packets
            "ReceivedPackets", 0, ...               % Total number of received packets
            "ReceivedDataPackets", 0, ...           % Total number of received data packets
            "ReceivedControlPackets", 0, ...        % Total number of received control packets
            "ReceivedDuplicatePackets", 0, ...      % Total number of received duplicate packets
            "CRCFailedPackets", 0, ...              % Total number of CRC failed packets
            "ReceivedBytes", 0, ...                 % Total number of received bytes
            "ReceivedPayloadBytes", 0, ...          % Total number of received payload bytes
            "ReceivedEmptyPackets", 0, ...          % Total number of received empty packets
            "AveragePacketLatency", 0, ...          % Average packet latency, in microseconds
            "AverageRoundTripTime", 0)              % Average round trip time, in microseconds

        %ConnectionConfig Configuration for all central-peripheral connections
        %specified as an object or array of objects. Each object represents the
        %configuration of the corresponding connection.
        ConnectionConfigs = struct( ...
            "ConnectionInterval", 20000, ...            % Connection interval, in microseconds
            "AccessAddress", "5DA44270", ...            % Access address as a 4-octet hexadecimal
            "AccessAddressBin", ...                     % Access address in bits
            [0;0;0;0;1;1;1;0;0;1;0;0;0;0; ...
            1;0;0;0;1;0;0;1;0;1;1;0;1;1;1;0;1;0], ...
            "UsedChannels", 0:36, ...                   % Used channels for communication
            "Algorithm", 1, ...                         % Channel selection algorithm
            "HopIncrement", 5, ...                      % Hop increment count
            "CRCInitialization", "012345", ...          % CRC initialization
            "SupervisionTimeout", 1e6, ...              % Supervision timer in microseconds
            "PHYMode", "LE1M", ...                      % PHY mode
            "InstantOffset", 6, ...                     % Offset added to connection event counter for channel map
            "ConnectionOffset", 0, ...                  % Connection offset, in microseconds
            "ActivePeriod", 20000, ...                  % Active period of the connection, in microseconds
            "ChannelSelection",bleChannelSelection)     % Channel selection object

        %ConnectionContext Context required for each connection
        ConnectionContext = struct(...
            "OffsetExpired", false, ...           % Flag indicating connection offset has expired
            "State", 3, ...                       % Current state of the state machine
            "SequenceCounter", 0, ...             % Counter for sequence number
            "NextExpectedSequenceCounter", 0, ... % Counter for next expected sequence number
            "LastTransmittedPayload", [], ...     % Recently transmitted payload
            "LastTransmittedTimestamp", -1, ...   % Timestamp of the recently transmitted packet
            "SupervisionTimer", 0, ...            % Timer for supervision timeout
            "TxMoreData", false, ...              % Flag indicating if there is more data to transmit
            "RxMoreData", false, ...              % Flag indicating if there is more data to receive
            "MoreData", false, ...                % More Data bit
            "PHYRxFailed", false, ...             % Flag indicating of reception has failed at PHY
            "ModelTIFS",false, ...                % Flag indicating if TIFS has to be modelled
            "ConnectionEventCount", -1, ...       % Counter for the connection event
            "MaxPacketDuration", ...              % Max duration in LE1M PHY mode
            bluetoothPacketDuration("LE1M","Disabled", 251), ... 
            "ChannelsClassified", false, ...      % Flag to check whether the channels are classified or not
            "ClassificationSent", false, ...      % Flag to check whether the channel map update is sent or not
            "ChannelUpdateACK", false, ...        % Flag to check whether acknowledgment received for channel map update
            "NewChannelMap", ones(1, 37), ...     % Newly received channel map
            "SelectNewChannel", true, ...         % Flag to select a new channel for communication between central and peripheral.
            "Instant", 0, ...                     % Instant of the connection event counter to update new channel map
            "ChannelIndex", 0, ...                % Active channel index
            "ConsecutiveCRCFailCount", 0, ...     % Access address in binary format
            "CurrentRoundTripTime", -1, ...       % Round trip time for the recently transmitted packet, in microseconds
            "AppTimestamp", -1, ...               % Timestamp added by the application, in microseconds
            "UpdateInProgress", false)            % Flag to check channel map update is in progress or not

        %RxRequest Link layer receive request to PHY
        RxRequest = []

        %RxUpperLayerData Received upper layer data
        RxUpperLayerData = zeros(1,0)

        %RxUpperLayerTimestamp Originated timestamp of the upper layer data
        RxUpperLayerTimestamp

        %RxActiveConnectionIdx Index of the active connection out of all the
        %connection state-machines for the received upper layer data
        RxActiveConnectionIdx

        %CurrentTime Current simulation time in microseconds
        CurrentTime = 0
    end

    properties (Access=private)
        %pQueue Queue for upper-layer payloads
        pQueue = bluetooth.internal.queue(1,1)

        %pPDUCfg Link layer data PDU configuration object
        pPDUCfg = bleLLDataChannelPDUConfig

        %pIsCentral Flag to specify whether the role is "central" or not
        pIsCentral = false

        %pReceptionStartTime Start time of receiving a packet
        pReceptionStartTime

        %pNextInvokeTimes Time at which the link layer is to be invoked next for
        %each of the connection, in microseconds
        pNextInvokeTimes

        %pActiveConnections List of active connection indices in the node
        pActiveConnections

        %pNumActiveConnections Number of active connections in the node
        pNumActiveConnections = 0
    end

    methods
        function obj = linkLayerConnections(notificationFcn,varargin)
            %Constructor

            % Assign the events notification callback
            obj.NotificationFcn = notificationFcn;

            % Name-value pairs
            for idx = 1:2:nargin-1
                obj.(char(varargin{idx})) = varargin{idx+1};
            end

            if strcmp(obj.Role,"central")
                % Set the Central flag to true
                obj.pIsCentral = true;
            end
        end

        function init(obj)
            %init Initializes link layer with all the connections

            % Initialize the connection information and statistics
            peripheralCount = obj.PeripheralCount;
            obj.ConnectionContext = repmat(obj.ConnectionContext,obj.PeripheralCount,1);
            obj.ConnectionEventEnded = repmat(obj.ConnectionEventEnded,obj.PeripheralCount,1);
            obj.pNextInvokeTimes = zeros(1,peripheralCount);

            for idx = 1:peripheralCount
                % Configure channel selection algorithm
                obj.ConnectionConfigs(idx).ChannelSelection = bleChannelSelection( ...
                    "Algorithm", obj.ConnectionConfigs(idx).Algorithm, ...
                    "AccessAddress", obj.ConnectionConfigs(idx).AccessAddress, ...
                    "UsedChannels", obj.ConnectionConfigs(idx).UsedChannels, ...
                    "HopIncrement", obj.ConnectionConfigs(idx).HopIncrement);
                obj.ConnectionContext(idx).SupervisionTimer = obj.ConnectionConfigs(idx).SupervisionTimeout;
                obj.ConnectionContext(idx).ChannelsClassified = false;

                % Configure the queue
                obj.pQueue(idx) = bluetooth.internal.queue(obj.MaxQueueSize, obj.MaxPacketSize*8);

                % Maximum packet duration is calculated by considering the maximum link
                % layer PDU bytes (excluding the MIC). Maximum packet length = 2 bytes of
                % header + 251 bytes of payload.
                maxDuration = bluetoothPacketDuration(obj.ConnectionConfigs(idx).PHYMode, ...
                    "Disabled", obj.MaxPacketSize);

                % Check whether the connection interval is sufficient for at least one
                % packet exchange with maximum packet duration.
                minSufficientValue = (2*(maxDuration + obj.TIFS))*obj.PeripheralCount; % in microseconds
                coder.internal.errorIf(obj.ConnectionConfigs(idx).ConnectionInterval<minSufficientValue,...
                    "bluetooth:bluetoothLENode:InsufficientConnectionInterval",num2str(minSufficientValue/1e6),obj.PeripheralCount);

                % Update the maximum packet duration
                obj.ConnectionContext(idx).MaxPacketDuration = maxDuration;
            end

            % Initialize the active connections
            obj.pActiveConnections = 1:obj.PeripheralCount;
            obj.pNumActiveConnections = numel(obj.pActiveConnections);
        end

        function updateConnectionConfig(obj,connectionIdx,connectionConfig)
            %updateConnectionConfig Update the configuration of a specific connection
            %
            %   updateConnectionConfig(OBJ,CONNECTIONIDX,CONNECTIONCONFIG) updates
            %   the configuration of a specific connection, connectionIdx.
            %
            %   connectionIdx is a scalar positive integer specifying the index of the
            %   connection.
            %
            %   CONNECTIONCONFIG is an object of type bluetoothLEConnectionConfig. It
            %   specifies the configuration to be used for the specified connection.

            % Update the configuration for the specified connection
            obj.ConnectionConfigs(connectionIdx).CentralName = connectionConfig.CentralName;
            obj.ConnectionConfigs(connectionIdx).PeripheralName = connectionConfig.PeripheralName;
            obj.ConnectionConfigs(connectionIdx).CentralID = connectionConfig.CentralID;
            obj.ConnectionConfigs(connectionIdx).PeripheralID = connectionConfig.PeripheralID;
            obj.ConnectionConfigs(connectionIdx).ConnectionInterval = round(connectionConfig.ConnectionInterval*1e6,3); % in microseconds
            obj.ConnectionConfigs(connectionIdx).AccessAddress = connectionConfig.AccessAddress;
            obj.ConnectionConfigs(connectionIdx).AccessAddressBin = int2bit(hex2dec(connectionConfig.AccessAddress),32,0); % in bits
            obj.ConnectionConfigs(connectionIdx).UsedChannels = connectionConfig.UsedChannels;
            obj.ConnectionConfigs(connectionIdx).Algorithm = connectionConfig.Algorithm;
            obj.ConnectionConfigs(connectionIdx).HopIncrement = connectionConfig.HopIncrement;
            obj.ConnectionConfigs(connectionIdx).CRCInitialization = connectionConfig.CRCInitialization;
            obj.ConnectionConfigs(connectionIdx).PHYMode = connectionConfig.PHYMode;
            obj.ConnectionConfigs(connectionIdx).InstantOffset = connectionConfig.InstantOffset;
            obj.ConnectionConfigs(connectionIdx).ConnectionOffset = round(connectionConfig.ConnectionOffset*1e6,3); % in microseconds
            obj.ConnectionConfigs(connectionIdx).ActivePeriod = round(connectionConfig.ActivePeriod*1e6,3); % in microseconds
            obj.ConnectionConfigs(connectionIdx).SupervisionTimeout = round(connectionConfig.SupervisionTimeout*1e6,3); % in microseconds

            % Initialize and update the connection statistics
            obj.ConnectionStats(connectionIdx) = obj.ConnectionStats(1);
            if strcmp(obj.Role, "central")
                obj.ConnectionStats(connectionIdx).PeerNodeName = connectionConfig.PeripheralName;
                obj.ConnectionStats(connectionIdx).PeerNodeID = connectionConfig.PeripheralID;
            else
                obj.ConnectionStats(connectionIdx).PeerNodeName = connectionConfig.CentralName;
                obj.ConnectionStats(connectionIdx).PeerNodeID = connectionConfig.CentralID;
            end
            % Update the CRC in the PDU configuration
            obj.pPDUCfg.CRCInitialization = connectionConfig.CRCInitialization;
        end

        function isSuccess = pushUpperLayerPDU(obj,connectionIdx,upperLayerPDU,timestamp)
            %pushUpperLayerPDU Push the upper layer data PDU into the link layer queue
            %
            %   ISSUCCESS = pushUpperLayerPDU(OBJ,CONNECTIONIDX,UPPERLAYERPDU,
            %   TIMESTAMP) pushes the upper layer PDU into the link layer for the
            %   specified connection.
            %
            %   ISSUCCESS specifies whether the upper layer PDU, UPPERLAYERPDU is
            %   successfully en-queued into the specified connection for transmission.
            %   It is a scalar boolean value.
            %
            %   CONNECTIONIDX specifies the connection on which the upper layer PDU
            %   should be transmitted. It is specified as a scalar value in the range
            %   [1 PeripheralCount].
            %
            %   UPPERLAYERPDU specifies the PDU from the upper layers to be transmitted
            %   by the link layer. It is specified as a vector of decimal bytes in the
            %   range [0 255].
            %
            %   TIMESTAMP specifies the timestamp when the UPPERLAYERPDU is generated
            %   by the upper layers. It is specified as a scalar double value in
            %   microseconds.

            isSuccess = false;
            if ~isempty(upperLayerPDU)
                % Push the PDU to the queue
                isSuccess = enqueue(obj.pQueue(connectionIdx),[upperLayerPDU; timestamp]);
                if ~isSuccess
                    obj.ConnectionStats(connectionIdx).TransmitQueueOverflow = ...
                        obj.ConnectionStats(connectionIdx).TransmitQueueOverflow + 1;
                end
            end
        end

        function [nextInvokeTime,requestFromLL] = run(obj,elapsedTime,indicationToLL)
            %run Run the link layer connections
            %
            %   [NEXTINVOKETIME,REQUESTFROMLL] = run(OBJ,ELAPSEDTIME,INDICATIONTOLL) run
            %   the link layer connections by accepting the ELAPSEDTIME and return the
            %   time remaining for next event, NEXTINVOKETIME.
            %
            %   NEXTINVOKETIME is the remaining time (in microseconds) for the next
            %   event.
            %
            %   REQUESTFROMLL and INDICATIONTOLL are structures of type
            %   ble.internal.networkUtilities.linkLayerAndPHYInterface
            %
            %   ELAPSEDTIME is the time elapsed in microseconds between the previous
            %   and current call of this function.

            % Update the current simulation time
            obj.CurrentTime = obj.CurrentTime+elapsedTime;

            % Link layer has no active links to transmit or receive data
            if obj.pNumActiveConnections==0
                nextInvokeTime = Inf;
                requestFromLL = [];
                return;
            end

            % Run the state machine
            [requestFromLL,nextInvokeTime]= runStateMachine(obj,indicationToLL,elapsedTime);

            % Calculate after how much time the link layer needs to be invoked
            nextInvokeTime = nextInvokeTime-obj.CurrentTime;
        end

        function status = updateChannelList(obj,channelList,connectionIdx)
            %updateChannelMap Update the given channel map by initiating the channel
            %map update procedure
            %
            %   CHANNELLIST specifies the list of used channels to be used for further
            %   communication for the specified connection, connectionIdx. It is an
            %   integer vector with each element in the range [0, 36].
            %
            %   connectionIdx specifies connection to which the given channel map is
            %   used. It is specified as a scalar positive integer in the range [1
            %   PeripheralCount].
            %
            %   STATUS is a boolean flag indicating whether the newly received channel
            %   list is accepted for channel classification

            status = false;
            newUsedChannelList = unique(channelList);

            % Validate the list of channels
            if numel(newUsedChannelList)<2
                coder.internal.warning("bluetooth:bleLL:InvalidUsedChannels");
            elseif any(newUsedChannelList<0) || any(newUsedChannelList>36)
                coder.internal.warning("bluetooth:bleLL:InvalidUsedChannels");
            elseif obj.pIsCentral && ~obj.ConnectionContext(connectionIdx).UpdateInProgress
                % Channel map update procedure supported only at the central. Update the
                % channel map only when there is no update ongoing
                if ~isequal(obj.ConnectionConfigs(connectionIdx).ChannelSelection.UsedChannels, ...
                        newUsedChannelList)
                    % Update the channel map if the used and the new channels specified are
                    % different
                    status = true;
                    channelMap = zeros(1, 37);
                    channelMap(newUsedChannelList+1) = 1;
                    obj.ConnectionContext(connectionIdx).NewChannelMap = channelMap;
                    obj.ConnectionContext(connectionIdx).ChannelsClassified = true;
                end
            end
        end

        function connectionStats = statistics(obj)
            %statistics Get the statistics captured in the link layer connections
            %
            %   CONNECTIONSSTATISTICS is a structure with the fields in the
            %   ConnectionStats property. In case of multiple Peripherals, it is a
            %   structure array with the fields in the ConnectionStats property.

            connectionStats = obj.ConnectionStats;
            for idx = 1:obj.PeripheralCount
                % Fetch the statistics for each connection
                connectionStats(idx).TransmissionTime = connectionStats(idx).TransmissionTime/1e6; % In seconds
                connectionStats(idx).IdleTime = connectionStats(idx).IdleTime/1e6; % In seconds
                connectionStats(idx).ListenTime = connectionStats(idx).ListenTime/1e6; % In seconds
                connectionStats(idx).SleepTime = connectionStats(idx).SleepTime/1e6; % In seconds
                connectionStats(idx).PacketLossRatio = ...
                    (connectionStats(idx).TransmittedPackets-connectionStats(idx).AcknowledgedPackets)...
                    /connectionStats(idx).TransmittedPackets;
                connectionStats(idx).Throughput = (connectionStats(idx).TransmittedPayloadBytes*8*1e3/obj.CurrentTime); % In Kbps
                connectionStats(idx).AveragePacketLatency = ...
                    connectionStats(idx).AveragePacketLatency*1e-6/...
                    (connectionStats(idx).ReceivedPackets-connectionStats(idx).CRCFailedPackets); % In seconds
                connectionStats(idx).AverageRoundTripTime = ...
                    connectionStats(idx).AverageRoundTripTime*1e-6/connectionStats(idx).AcknowledgedPackets; % In seconds
            end
        end
    end

    methods (Access = private)
        function [requestFromLL, nextInvokeTime] = runStateMachine(obj,indicationToLL,elapsedTime)
            %runStateMachine Run the state machine of the LL, calculate the time at
            %which the link layer has to be invoked again, and return the request from
            %LL to PHY

            % Initialize
            obj.RxUpperLayerData = [];
            obj.RxRequest = [];
            txLLPacket = [];
            requestFromLL = [];

            % Run the state machine for all the active connections in the node
            for connectionIdx = obj.pActiveConnections
                % Get the connection context for the connection index
                connContext = obj.ConnectionContext(connectionIdx);

                % Update connection event timers and check for supervision timeout and
                % channel classification
                [status,connContext] = updateAndCheckTimers(obj,connContext,connectionIdx,elapsedTime);
                if ~status
                    obj.ConnectionContext(connectionIdx) = connContext;
                    continue;
                end

                % Process the current state of the link layer
                switch connContext.State
                    case obj.TRANSMIT_STATE
                        % Transmission is in progress or end of packet transmission
                        connContext = transmit(obj,connContext,connectionIdx,elapsedTime);

                    case obj.RECEIVE_STATE
                        % Expecting a reception or packet reception in progress or end of packet
                        % reception. State transition to Transmit state and return a packet or
                        % state transition to Sleep state.
                        [txLLPacket,connContext] = receive(obj,elapsedTime,indicationToLL,connContext,connectionIdx);

                    case obj.SLEEP_STATE
                        % Link layer is in sleep state. State transition to Transmit state and
                        % return a packet or state transition to Receive state.
                        [txLLPacket,connContext] = sleep(obj,elapsedTime,connContext,connectionIdx);
                end

                if ~isempty(txLLPacket)
                    requestFromLL = txLLPacket;
                end

                % Update the connection to know if there is more data
                if connContext.TxMoreData || connContext.RxMoreData
                    connContext.MoreData = true;
                else
                    connContext.MoreData = false;
                end
                obj.ConnectionContext(connectionIdx) = connContext;
            end

            % Calculate the minimum of next invoke times for all connections
            nextInvokeTime = min(obj.pNextInvokeTimes);
        end

        function connContext = transmit(obj,connContext,connectionIdx,elapsedTime)
            %transmit Process the transmit state. If the transmission is over change to
            %Receive or Sleep state.

            % Update the transmission time
            obj.ConnectionStats(connectionIdx).TransmissionTime = obj.ConnectionStats(connectionIdx).TransmissionTime+elapsedTime;

            if obj.CurrentTime >= obj.pNextInvokeTimes(connectionIdx)
                % Packet duration is completed, calculate the transmission and idle time
                obj.ConnectionStats(connectionIdx).TransmissionTime = obj.ConnectionStats(connectionIdx).TransmissionTime-obj.TIFS;
                obj.ConnectionStats(connectionIdx).IdleTime = obj.ConnectionStats(connectionIdx).IdleTime+obj.TIFS;

                if obj.pIsCentral
                    % At Central change to Receive state and request PHY to start listening
                    connContext.State = obj.RECEIVE_STATE;
                    connContext = requestToPHY(obj,connContext,connectionIdx);
                    obj.pNextInvokeTimes(connectionIdx) = connContext.MaxPacketDuration+obj.CurrentTime;
                    connContext.PHYRxFailed = false;
                else
                    connConfigs = obj.ConnectionConfigs(connectionIdx);
                    timeEnoughForCommunication = ((connConfigs.ActivePeriod-obj.CurrentTime+((connContext.ConnectionEventCount)*connConfigs.ConnectionInterval))+connConfigs.ConnectionOffset> ...
                        2*(connContext.MaxPacketDuration+obj.TIFS));
                    moreDataPresent = connContext.MoreData;
                    conexutive2CRCFailures = connContext.ConsecutiveCRCFailCount<=1;
                    if  timeEnoughForCommunication && moreDataPresent && conexutive2CRCFailures
                        % Continue the connection event by checking whether
                        % * Remaining time is sufficient for a packet exchange,
                        % * Additional data at central or peripheral, and
                        % * No more than one consecutive CRC failures
                        connContext.State = obj.RECEIVE_STATE;
                        connContext = requestToPHY(obj,connContext,connectionIdx);
                        obj.pNextInvokeTimes(connectionIdx) = connContext.MaxPacketDuration+obj.CurrentTime;
                        connContext.PHYRxFailed = false;
                    else
                        % Stay in sleep state until the beginning of new connection event. Refer
                        % Bluetooth Core Specification v5.3 | Vol 6, PART B, Section 4.5.6.
                        connContext.State = obj.SLEEP_STATE;
                        obj.pNextInvokeTimes(connectionIdx) = ((connContext.ConnectionEventCount+1)*connConfigs.ConnectionInterval)+connConfigs.ConnectionOffset;
                    end
                end

                % Update the per connection event statistics
                obj.ConnectionEventEnded(connectionIdx).TransmittedPackets = ...
                    obj.ConnectionEventEnded(connectionIdx).TransmittedPackets+1;
            end
        end

        function [txLLPacket,connContext] = receive(obj,elapsedTime,rxLLPacket,connContext,connectionIdx)
            %receive Process the receive state

            txLLPacket = [];
            % Update the Listen time
            obj.ConnectionStats(connectionIdx).ListenTime = obj.ConnectionStats(connectionIdx).ListenTime+elapsedTime;

            % Get the indication of PHY state
            rxEvent = -1;
            if ~isempty(rxLLPacket)
                rxEvent = rxLLPacket.RxEvent;
            end

            connConfigs = obj.ConnectionConfigs(connectionIdx);
            if connContext.ModelTIFS && obj.CurrentTime>=obj.pNextInvokeTimes(connectionIdx)
                % TIFS time needs to be modelled after reception is over
                connContext.ModelTIFS = false;

                % Calculate the reception time and idle time
                obj.ConnectionStats(connectionIdx).ListenTime = obj.ConnectionStats(connectionIdx).ListenTime-obj.TIFS;
                obj.ConnectionStats(connectionIdx).IdleTime = obj.ConnectionStats(connectionIdx).IdleTime+obj.TIFS;

                phyRxFailure = connContext.PHYRxFailed;
                if obj.pIsCentral
                    timeEnoughForCommunication = (connConfigs.ActivePeriod-obj.CurrentTime+((connContext.ConnectionEventCount)*connConfigs.ConnectionInterval))+connConfigs.ConnectionOffset > ...
                        (2*(connContext.MaxPacketDuration + obj.TIFS));
                    moreDataPresent = connContext.MoreData;
                    consecutive2CRCFail = connContext.ConsecutiveCRCFailCount<=1;
                    if  timeEnoughForCommunication && moreDataPresent && consecutive2CRCFail && ~phyRxFailure
                        % Continue the connection event and TRANSMIT by checking whether
                        % * Remaining time is sufficient for a packet exchange,
                        % * Additional data at central or peripheral,
                        % * No more than one consecutive CRC failures, and
                        % * PHY reception is valid
                        connContext.State = obj.TRANSMIT_STATE;

                        % Transmit the packet
                        [txLLPacket,connContext] = transmitPacket(obj,connContext,connectionIdx);

                        % Invoke the link layer after packet duration and TIFS time
                        obj.pNextInvokeTimes(connectionIdx) = txLLPacket.PacketDuration+obj.CurrentTime+obj.TIFS;
                    else
                        % Stay in the sleep state till the next connection event arrives
                        connContext.State = obj.SLEEP_STATE;

                        % Invoke the link layer at the beginning of next connection event
                        obj.pNextInvokeTimes(connectionIdx) = ((connContext.ConnectionEventCount+1)*connConfigs.ConnectionInterval)+connConfigs.ConnectionOffset;
                    end
                else
                    if ~phyRxFailure
                        % Continue the connection event if the PHY reception is valid and change to
                        % Transmit state
                        connContext.State = obj.TRANSMIT_STATE;

                        % Transmit the packet
                        [txLLPacket,connContext] = transmitPacket(obj,connContext,connectionIdx);

                        % Invoke the link layer after packet duration and TIFS time
                        obj.pNextInvokeTimes(connectionIdx) = txLLPacket.PacketDuration+obj.CurrentTime+obj.TIFS;
                    else
                        % Stay in sleep state until the beginning of new connection event. Refer
                        % Bluetooth Core Specification v5.3 | Vol 6, PART B, Section 4.5.6.
                        connContext.State = obj.SLEEP_STATE;

                        % Invoke the link layer at the beginning of next connection event
                        obj.pNextInvokeTimes(connectionIdx) = ((connContext.ConnectionEventCount+1)*connConfigs.ConnectionInterval)+connConfigs.ConnectionOffset;
                    end
                end
                return;
            end

            if rxEvent == ble.internal.networkUtilities.RX_START
                % Connection event should be closed before TIFS time. Keep listening till
                % the packet end received or the connection interval expires.
                obj.pReceptionStartTime = obj.CurrentTime;
                obj.pNextInvokeTimes(connectionIdx) = ((connContext.ConnectionEventCount+1)*connConfigs.ConnectionInterval)-obj.TIFS+connConfigs.ConnectionOffset;
            elseif rxEvent == ble.internal.networkUtilities.RX_END
                % Packet reception end indication received Update the per connection event
                % statistics and model TIFS
                connContext.ModelTIFS = true;
                obj.ConnectionEventEnded(connectionIdx).ReceivedPackets = ...
                    obj.ConnectionEventEnded(connectionIdx).ReceivedPackets+1;

                % Process the received packet at link layer
                connContext = processRx(obj,rxLLPacket,connContext,connectionIdx);

                % Invoke the link layer after TIFS time
                obj.pNextInvokeTimes(connectionIdx) = obj.TIFS+obj.CurrentTime;
            end

            if obj.CurrentTime>=obj.pNextInvokeTimes(connectionIdx)
                % Process the failed reception at link layer
                connContext = processRx(obj,rxLLPacket,connContext,connectionIdx);

                % Change to Sleep state as listen time expired
                connContext.State = obj.SLEEP_STATE;

                % Invoke the link layer at the beginning of next connection event
                obj.pNextInvokeTimes(connectionIdx) = ((connContext.ConnectionEventCount+1)*connConfigs.ConnectionInterval)+connConfigs.ConnectionOffset;
            end
        end

        function [txLLPacket,connContext] = sleep(obj,elapsedTime,connContext,connectionIdx)
            %sleep Process the sleep state

            txLLPacket = [];
            % Update the sleep time
            obj.ConnectionStats(connectionIdx).SleepTime = obj.ConnectionStats(connectionIdx).SleepTime+elapsedTime;

            if obj.CurrentTime>=obj.pNextInvokeTimes(connectionIdx)
                % Connection event is completed. Update the connection event count
                connContext.ConnectionEventCount = connContext.ConnectionEventCount+1;

                if connContext.ConnectionEventCount>0
                    % Trigger the ConnectionEventEnded event and reset counter
                    connContext = triggerConnectionEventStats(obj,connContext,connectionIdx);
                end

                % Check channel classification as connection event count is updated
                [status,connContext] = checkChannelClassification(obj,connContext,connectionIdx);
                if status
                    return;
                end

                if obj.pIsCentral
                    % Central transmits packet at the start of every connection event. Change
                    % to Transmit state for packet duration and transmit a packet
                    connContext.State = obj.TRANSMIT_STATE;
                    [txLLPacket,connContext] = transmitPacket(obj,connContext,connectionIdx);

                    % Invoke the link layer after the packet duration and TIFS time
                    obj.pNextInvokeTimes(connectionIdx) = txLLPacket.PacketDuration+obj.CurrentTime+obj.TIFS;
                else
                    % Peripheral listens for the packet at every start of the connection event.
                    % Change to Receive state and request PHY to start reception
                    connContext.State = obj.RECEIVE_STATE;

                    % Reset the flag for PHY reception failure and request PHY to listen for
                    % maximum packet duration
                    connContext.PHYRxFailed = false;
                    connContext = requestToPHY(obj,connContext,connectionIdx);

                    % Invoke the link layer after maximum packet duration
                    obj.pNextInvokeTimes(connectionIdx) = connContext.MaxPacketDuration+obj.CurrentTime;
                end
            end
        end

        function connContext = requestToPHY(obj,connContext,connectionIdx)
            %requestToPHY Update the data when a request needs to be sent to PHY

            % Update the channel index, access address and PHY mode
            connConfigs = obj.ConnectionConfigs(connectionIdx);
            obj.RxRequest = ble.internal.networkUtilities.llToPHYRxRequest;
            obj.RxRequest.RxOn = true;
            obj.RxRequest.PHYMode = connConfigs.PHYMode;
            obj.RxRequest.AccessAddress = connConfigs.AccessAddressBin;
            if connContext.SelectNewChannel
                obj.RxRequest.ChannelIndex = connConfigs.ChannelSelection();
                connContext.ChannelIndex = obj.RxRequest.ChannelIndex;
                connContext.SelectNewChannel = false;
            else
                obj.RxRequest.ChannelIndex = connContext.ChannelIndex;
            end
        end

        function connContext = triggerConnectionEventStats(obj,connContext,connectionIdx)
            %triggerConnectionEventStats Trigger the ConnectionEventEnded event

            connectionEventEnded = obj.ConnectionEventEnded(connectionIdx);
            obj.NotificationFcn("ConnectionEventEnded",connectionEventEnded);

            % Reset the per connection event statistics
            obj.ConnectionEventEnded(connectionIdx).Counter = mod(connContext.ConnectionEventCount,obj.MaxConnectionEventCount+1);
            obj.ConnectionEventEnded(connectionIdx).TransmittedPackets = 0;
            obj.ConnectionEventEnded(connectionIdx).ReceivedPackets = 0;
            obj.ConnectionEventEnded(connectionIdx).CRCFailedPackets = 0;

            % Reset the CRC failures. Select a new channel for a new connection event
            connContext.ConsecutiveCRCFailCount = 0;
            connContext.SelectNewChannel = true;
        end

        function connContext = processRx(obj,rxLLPacket,connContext,connectionIdx)
            %processRx Process the reception of a packet

            if ~isempty(rxLLPacket) && rxLLPacket.RxEvent == ble.internal.networkUtilities.RX_END
                if isequal(obj.ConnectionConfigs(connectionIdx).AccessAddressBin,rxLLPacket.AccessAddress)
                    % Access address check
                    connContext.PHYRxFailed = false;
                else
                    connContext.PHYRxFailed = true;
                end
                if ~isempty(rxLLPacket.LLPDU)
                    % Process the received LL packet and update the received packets count
                    [isFailed,connContext] = processRxPacket(obj,rxLLPacket,connContext,connectionIdx);
                    obj.ConnectionStats(connectionIdx).ReceivedPackets = obj.ConnectionStats(connectionIdx).ReceivedPackets+1;
                else
                    isFailed = true;
                end
                % Trigger packet reception event for successful and failed receptions
                packetRxEnded = obj.PacketReceptionEnded;
                packetRxEnded.SourceNode = obj.ConnectionStats(connectionIdx).PeerNodeName;
                packetRxEnded.SourceID = obj.ConnectionStats(connectionIdx).PeerNodeID;
                packetRxEnded.SuccessStatus = ~isFailed;
                packetRxEnded.PDU = rxLLPacket.LLPDU;
                packetRxEnded.AccessAddress = obj.ConnectionConfigs(connectionIdx).AccessAddress;
                packetRxEnded.ChannelIndex = rxLLPacket.ChannelIndex;
                packetRxEnded.PHYMode = rxLLPacket.PHYMode;
                packetRxEnded.ReceivedPower = rxLLPacket.ReceivedPower;
                packetRxEnded.SINR = rxLLPacket.SINR;
                packetRxEnded.PacketDuration = (obj.CurrentTime-obj.pReceptionStartTime)/1e6;
                obj.NotificationFcn("PacketReceptionEnded", packetRxEnded);
            else
                connContext.PHYRxFailed = true;
            end

            % Set request to PHY receiver to switch off reception
            obj.RxRequest = ble.internal.networkUtilities.llToPHYRxRequest;
            obj.RxRequest.RxOn = false;
            obj.pReceptionStartTime = [];
        end

        function [crcFailed,connContext] = processRxPacket(obj,rxLLPacket,connContext,connectionIdx)
            %processRxPacket Process the received link layer packet

            crcFailed = 0;
            % Decode the received packet
            [status, cfg, llPayload] = bleLLDataChannelPDUDecode(rxLLPacket.LLPDU, ...
                obj.ConnectionConfigs(connectionIdx).CRCInitialization);

            if status == blePacketDecodeStatus.CRCFailed
                % CRC failed packet
                crcFailed = 1;
                obj.ConnectionStats(connectionIdx).CRCFailedPackets = obj.ConnectionStats(connectionIdx).CRCFailedPackets+1;
                connContext.RxMoreData = true;
            else
                % Update the average packet latency
                packetLatency = obj.CurrentTime-rxLLPacket.LLTimestamp;
                obj.ConnectionStats(connectionIdx).AveragePacketLatency = ...
                    obj.ConnectionStats(connectionIdx).AveragePacketLatency+packetLatency;
                % Reset the supervision timeout
                connContext.SupervisionTimer = obj.ConnectionConfigs(connectionIdx).SupervisionTimeout+obj.CurrentTime;

                obj.ConnectionStats(connectionIdx).ReceivedBytes = obj.ConnectionStats(connectionIdx).ReceivedBytes+numel(rxLLPacket.LLPDU)/8;

                if isempty(llPayload) && ~strcmp(cfg.LLID,"Control")
                    % Data packets with empty payload
                    obj.ConnectionStats(connectionIdx).ReceivedEmptyPackets = obj.ConnectionStats(connectionIdx).ReceivedEmptyPackets + 1;
                end

                if connContext.NextExpectedSequenceCounter==cfg.SequenceNumber
                    % Verify the received packet sequence number with NESN
                    connContext.NextExpectedSequenceCounter = ~connContext.NextExpectedSequenceCounter;
                    if ~isempty(llPayload)
                        % Update data to be processed by the upper layers
                        obj.ConnectionStats(connectionIdx).ReceivedPayloadBytes = obj.ConnectionStats(connectionIdx).ReceivedPayloadBytes+numel(llPayload)/2;
                        obj.ConnectionStats(connectionIdx).ReceivedDataPackets = obj.ConnectionStats(connectionIdx).ReceivedDataPackets+1;
                        obj.RxUpperLayerData = hex2dec(llPayload);
                        obj.RxUpperLayerTimestamp = rxLLPacket.AppTimestamp;
                        obj.RxActiveConnectionIdx = connectionIdx;
                    end

                    if strcmp(cfg.LLID,"Control")
                        if strcmp(cfg.ControlConfig.Opcode,"Channel map indication")
                            % Channel map update packet is received
                            chMap = false(1, 37);
                            chMap(cfg.ControlConfig.UsedChannels+1) = true;
                            connContext.Instant = cfg.ControlConfig.Instant;
                            connContext.NewChannelMap = chMap;
                            connContext.ChannelUpdateACK = true;
                            obj.ConnectionStats(connectionIdx).ReceivedControlPackets = obj.ConnectionStats(connectionIdx).ReceivedControlPackets+1;
                        end
                    end
                else
                    % Received duplicate data at the link layer
                    obj.ConnectionStats(connectionIdx).ReceivedDuplicatePackets = obj.ConnectionStats(connectionIdx).ReceivedDuplicatePackets+1;
                end

                if cfg.NESN~=connContext.SequenceCounter
                    % Sequence counter matched with the received next expected sequence counter
                    connContext.LastTransmittedPayload = zeros(1, 0);
                    connContext.LastTransmittedTimestamp = -1;
                    obj.ConnectionStats(connectionIdx).AcknowledgedPackets = obj.ConnectionStats(connectionIdx).AcknowledgedPackets+1;
                    connContext.SequenceCounter = ~connContext.SequenceCounter;

                    if connContext.CurrentRoundTripTime ~= -1
                        % Received ACK for a data packet hence calculate the round trip time
                        connContext.CurrentRoundTripTime = ...
                            obj.CurrentTime - connContext.CurrentRoundTripTime;
                        obj.ConnectionStats(connectionIdx).AverageRoundTripTime = ...
                            obj.ConnectionStats(connectionIdx).AverageRoundTripTime+ ...
                            connContext.CurrentRoundTripTime;
                    end
                    connContext.CurrentRoundTripTime = 0;

                    if connContext.ClassificationSent
                        % Update the ACK for channel map update indication
                        connContext.ClassificationSent = false;
                        connContext.ChannelUpdateACK = true;
                    end
                end

                % Update the received more data bit
                connContext.RxMoreData = cfg.MoreData;
            end

            % Update the CRC status to the connection event module
            if crcFailed
                connContext.ConsecutiveCRCFailCount = connContext.ConsecutiveCRCFailCount+1;
                obj.ConnectionEventEnded(connectionIdx).CRCFailedPackets = ...
                    obj.ConnectionEventEnded(connectionIdx).CRCFailedPackets+1;
            else
                connContext.ConsecutiveCRCFailCount = 0;
            end
        end

        function [status,connContext] = updateAndCheckTimers(obj,connContext,connectionIdx,elapsedTime)
            %updateAndCheckTimers Update connection event timers and check for
            %supervision timeout and channel classification.

            status = true;
            % Check if the connection has crossed the supervision time and if there
            % are any channel classification to be done.
            if checkSupervisionTimer(obj,connContext,connectionIdx,elapsedTime) || checkChannelClassification(obj,connContext,connectionIdx)
                connContext = obj.ConnectionContext(connectionIdx);
                % If any check fails return to standby state and end the connection
                status = false;
                return;
            end
            connContext = obj.ConnectionContext(connectionIdx);

            if ~connContext.OffsetExpired
                % Connection offset has not expired
                if obj.CurrentTime>=obj.ConnectionConfigs(connectionIdx).ConnectionOffset
                    % Connection event has ended and a new connection event starts
                    obj.ConnectionEventEnded(connectionIdx).Counter = connContext.ConnectionEventCount;
                    connContext.OffsetExpired = true;
                else
                    % Connection offset is not yet expired, update the statistics and next invoke time
                    obj.ConnectionStats(connectionIdx).SleepTime = obj.ConnectionStats(connectionIdx).SleepTime+elapsedTime;
                    obj.pNextInvokeTimes(connectionIdx) = obj.ConnectionConfigs(connectionIdx).ConnectionOffset;
                    status = false;
                end
            end
        end

        function status = checkSupervisionTimer(obj,connContext,connectionIdx,elapsedTime)
            %checkSupervisionTimer Check and updates the supervision timers of each
            %connection

            status = false;
            if connContext.SupervisionTimer<=obj.CurrentTime
                % Supervision timer has timed out. Close the connection and change to
                % STANDBY state.
                obj.ConnectionStats(connectionIdx).SleepTime = obj.ConnectionStats(connectionIdx).SleepTime+elapsedTime;
                status = true;
                obj.pNextInvokeTimes(connectionIdx) = Inf;
                obj.ConnectionContext(connectionIdx).State = obj.STANDBY_STATE;
                coder.internal.warning("bluetooth:bluetoothLENode:DisconnectionDueToSupervision", ...
                    obj.ConnectionConfigs(connectionIdx).CentralName,obj.ConnectionConfigs(connectionIdx).PeripheralName);

                % Update the active connections
                obj.pActiveConnections(obj.pActiveConnections==connectionIdx) = [];
                obj.pNumActiveConnections = obj.pNumActiveConnections-1;
            end
        end

        function [status,connContext] = checkChannelClassification(obj,connContext,connectionIdx)
            %checkChannelClassification Check whether the channel classification is
            %sent or acknowledged

            status = false;
            if connContext.ClassificationSent || connContext.ChannelUpdateACK
                % Connection event reached the instant
                if connContext.ConnectionEventCount==connContext.Instant
                    connectionConfig = obj.ConnectionConfigs(connectionIdx);
                    % Update the new channel map
                    if connContext.ChannelUpdateACK
                        connectionConfig.ChannelSelection.UsedChannels = find(connContext.NewChannelMap)-1;
                        connContext.ChannelUpdateACK = false;
                        % Set channel map update trigger
                        channelMapUpdated = obj.ChannelMapUpdated;
                        if strcmpi(obj.Role,"peripheral")
                            channelMapUpdated.PeerNode = connectionConfig.CentralName;
                            channelMapUpdated.PeerID = connectionConfig.CentralID;
                        else
                            channelMapUpdated.PeerNode = connectionConfig.PeripheralName;
                            channelMapUpdated.PeerID = connectionConfig.PeripheralID;
                        end
                        channelMapUpdated.UpdatedChannelList = connectionConfig.ChannelSelection.UsedChannels;
                        obj.NotificationFcn("ChannelMapUpdated",channelMapUpdated);
                        connContext.UpdateInProgress = false;
                    else
                        % Terminate the connection as failed to receive the ACK for channel map
                        % update indication and change to standby state
                        coder.internal.warning("bluetooth:bluetoothLENode:DisconnectionDueToUpdateFailure", ...
                            connectionConfig.CentralName,connectionConfig.PeripheralName);
                        obj.pNextInvokeTimes(connectionIdx) = Inf;
                        connContext.State = obj.STANDBY_STATE;
                        obj.pActiveConnections(obj.pActiveConnections==connectionIdx) = [];
                        obj.pNumActiveConnections = obj.pNumActiveConnections-1;
                        status = true;
                    end
                end
            end
        end

        function [txLLPacket,connContext] = transmitPacket(obj,connContext,connectionIdx)
            %transmitPacket Transmit the link layer packet

            % Initialize
            llPayload = zeros(1, 0);
            isData = true;
            txLLPacket = ble.internal.networkUtilities.linkLayerAndPHYInterface;

            % Check if channels are classified
            [status,connContext] = checkChannelClassification(obj,connContext,connectionIdx);
            if status
                return;
            end

            connectionConfig = obj.ConnectionConfigs(connectionIdx);
            % Check for any previous PDU for retransmission
            if ~isempty(connContext.LastTransmittedPayload)
                isData = true;
                llPayload = connContext.LastTransmittedPayload;
                obj.ConnectionStats(connectionIdx).RetransmittedDataPackets = obj.ConnectionStats(connectionIdx).RetransmittedDataPackets+1;
            elseif connContext.ChannelsClassified || ...
                    (connContext.ClassificationSent && ~connContext.ChannelUpdateACK)
                % Transmit the channel map update PDU with the classified channel map
                isData = false;
                if connContext.ClassificationSent&&~connContext.ChannelUpdateACK
                    obj.ConnectionStats(connectionIdx).RetransmittedControlPackets = obj.ConnectionStats(connectionIdx).RetransmittedControlPackets+1;
                else
                    obj.ConnectionStats(connectionIdx).TransmittedControlPackets = obj.ConnectionStats(connectionIdx).TransmittedControlPackets+1;
                end
                connContext.ChannelsClassified = false;
                connContext.ChannelUpdateACK = false;
                connContext.AppTimestamp = -1; % Not applicable for control messages
                connContext.UpdateInProgress = true;
            elseif ~isEmpty(obj.pQueue(connectionIdx))
                % Fetch the new data from the queue for transmission
                isData = true;
                [~, llPayload] = dequeue(obj.pQueue(connectionIdx));
                % Fetch the timestamp of the application packet
                connContext.AppTimestamp = llPayload(end);
                llPayload = llPayload(1:end-1);
                obj.ConnectionStats(connectionIdx).TransmittedDataPackets = obj.ConnectionStats(connectionIdx).TransmittedDataPackets+1;
                obj.ConnectionStats(connectionIdx).TransmittedPayloadBytes = obj.ConnectionStats(connectionIdx).TransmittedPayloadBytes+numel(llPayload);
            end

            % Update the previous link layer PDU
            connContext.LastTransmittedPayload = llPayload;

            % Generate the data packet with the given link layer payload
            [llPDU,connContext] = generatePacket(obj,isData,llPayload,connContext,connectionIdx);

            % Update the Tx packet for transmission
            txLLPacket.LLPDU = llPDU;
            txLLPacket.AccessAddress = obj.ConnectionConfigs(connectionIdx).AccessAddressBin;
            txLLPacket.PHYMode = connectionConfig.PHYMode;
            txLLPacket.TransmitterPower = obj.TransmitterPower;
            if connContext.SelectNewChannel
                channelSelection = obj.ConnectionConfigs(connectionIdx).ChannelSelection;
                txLLPacket.ChannelIndex = channelSelection();
                connContext.ChannelIndex = txLLPacket.ChannelIndex;
                connContext.SelectNewChannel = false;
            else
                txLLPacket.ChannelIndex = connContext.ChannelIndex;
            end

            % Update the link layer timestamp
            if connContext.LastTransmittedTimestamp~=-1
                txLLPacket.LLTimestamp = connContext.LastTransmittedTimestamp;
            else
                txLLPacket.LLTimestamp = obj.CurrentTime;
            end

            % Update the application timestamp
            txLLPacket.AppTimestamp = connContext.AppTimestamp;

            % Calculate the transmission time in microseconds
            [txDuration, txPacketLen] = bluetoothPacketDuration(txLLPacket.PHYMode, ...
                "Disabled", numel(llPayload));
            txLLPacket.PacketLength = txPacketLen;
            txLLPacket.PacketDuration = txDuration;

            % Update the statistics and timestamps
            obj.ConnectionStats(connectionIdx).TransmittedPackets = obj.ConnectionStats(connectionIdx).TransmittedPackets+1;
            obj.ConnectionStats(connectionIdx).TransmittedBytes = obj.ConnectionStats(connectionIdx).TransmittedBytes+numel(txLLPacket.LLPDU)/8;
            if isempty(llPayload) && isData
                obj.ConnectionStats(connectionIdx).TransmittedEmptyPackets = obj.ConnectionStats(connectionIdx).TransmittedEmptyPackets+1;
                connContext.CurrentRoundTripTime = -1;
            else
                connContext.CurrentRoundTripTime = txLLPacket.LLTimestamp;
            end
            connContext.LastTransmittedTimestamp = txLLPacket.LLTimestamp;
        end

        function [llPDU,connContext] = generatePacket(obj,isData,llPayload,connContext,connectionIdx)
            %generatePacket Generate the link layer packet

            % Create link layer data PDU configuration object and update
            cfg = obj.pPDUCfg;

            if isData
                if isempty(llPayload)
                    % Empty link-layer packet
                    cfg.LLID = "Data (continuation fragment/empty)";
                else % Link-layer packet
                    cfg.LLID = "Data (start fragment/complete)";
                end
            else
                % Channel update packet
                chanMap = connContext.NewChannelMap;
                if ~connContext.ClassificationSent
                    % Update the instant value
                    connContext.Instant = ...
                        connContext.ConnectionEventCount+obj.ConnectionConfigs(connectionIdx).InstantOffset;
                    connContext.ClassificationSent = true;
                end

                % Create the channel map PDU configuration
                controlCfg = bleLLControlPDUConfig("Opcode","Channel map indication", ...
                    "UsedChannels",(find(chanMap)-1), ...
                    "Instant",connContext.Instant);
                cfg.LLID = "Control";
                cfg.ControlConfig = controlCfg;
            end
            cfg.SequenceNumber = connContext.SequenceCounter;
            cfg.NESN = connContext.NextExpectedSequenceCounter;
            cfg.MoreData = ~isEmpty(obj.pQueue(connectionIdx));
            connContext.TxMoreData = cfg.MoreData;

            % Generate the PDU
            llPDU = bleLLDataChannelPDU(cfg, llPayload);
        end
    end
    % LocalWords:  CRC PHY RTT ACK LLPDU PDU NESN LLID SINR
end