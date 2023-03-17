classdef bluetoothLENodeeFH < comm.internal.ConfigBase & wirelessnetwork.internal.wirelessNode
%bluetoothLENode Bluetooth LE node
%   LENODE = bluetoothLENode(ROLE) creates a default Bluetooth(R) low
%   energy (LE) node object for the specified role, ROLE.
%
%   LENODE = bluetoothLENode(ROLE, Name=Value) creates a Bluetooth LE node
%   object, LENODE, with the specified property Name set to the specified
%   Value. You can specify additional name-value arguments in any order as
%   (Name1=Value1, ..., NameN=ValueN).
%
%   ROLE specifies the role of the created Bluetooth LE node. Set this
%   value as one of "central", "peripheral", "isochronous-broadcaster",
%   "synchronized-receiver" or "broadcaster-observer".
%
%   bluetoothLENode properties (configurable):
%
%   Name                 - Node name
%   Position             - Node position
%   TransmitterPower     - Signal transmission power in dBm
%   TransmitterGain      - Transmitter antenna gain in dB
%   ReceiverRange        - Packet reception range of the node in meters
%   ReceiverGain         - Receiver antenna gain in dB
%   ReceiverSensitivity  - Receiver sensitivity in dBm
%   NoiseFigure          - Noise figure in dB
%   InterferenceFidelity - Fidelity level to model interference
%   AdvertisingInterval  - Advertising interval in seconds
%   RandomAdvertising    - Random advertising channel selection
%   ScanInterval         - Scan interval in seconds
%   MeshConfig           - Bluetooth mesh configuration object for
%                         "broadcaster-observer" role
%
%   bluetoothLENode properties (read-only):
%
%   ID                  - Node identifier
%   Role                - Role of the Bluetooth LE node
%   ConnectionConfig    - Connection configuration object for "central" and
%                         "peripheral" roles
%   PeripheralCount     - Number of peripherals associated with the central
%   BIGConfig           - BIG configuration object for
%                         "isochronous-broadcaster" and
%                         "synchronized-receiver" roles
%   FriendshipConfig    - Friendship configuration object for a Friend and
%                         low power node (LPN)
%
%   bluetoothLENode methods:
%
%   runNode                - Run Bluetooth LE node
%   addTrafficSource       - Add data traffic source to Bluetooth LE node
%   pushChannelData        - Push data from channel to reception buffer
%   channelInvokeDecision  - Return flag to indicate whether channel has to
%                            be applied on incoming signal
%   updateChannelList      - Provide the updated channel list to node
%   statistics             - Get the statistics of the node
%
%   bluetoothLENode events:
%
%   PacketTransmissionStarted - Event to notify the start of a signal
%                               transmission
%   PacketReceptionEnded      - Event to notify the end of a signal 
%                               reception
%   ChannelMapUpdated         - Event to notify the enforcement of new 
%                               channel map
%   AppDataReceived           - Event to notify the reception of 
%                               application data
%   MeshAppDataReceived       - Event to notify the reception of mesh
%                               application data
%   ConnectionEventEnded      - Event to notify the end of a ConnectionEvent
%
%   Example 1: Create, Configure, and Simulate Bluetooth LE Network
%   <a
%   href="matlab:helpview('bluetooth','bluetoothLEPiconetTutorial')">Create, Configure, and Simulate Bluetooth LE Network</a>.
%
%   Example 2: Create, Configure, and Simulate Bluetooth LE Broadcast Audio Network
%   <a
%   href="matlab:helpview('bluetooth','bluetoothLEBroadcastAudioNetworkTutorial')">Create, Configure, and Simulate Bluetooth LE Broadcast Audio Network</a>.
%
%   Example 3: Create, Configure, and Simulate Bluetooth Mesh Network
%   <a
%   href="matlab:helpview('bluetooth','bluetoothLEMeshNetworkTutorial')">Create, Configure, and Simulate Bluetooth Mesh Network</a>.
%
%   Example 4: Establish Friendship Between Friend Node and LPN in Bluetooth Mesh Network
%   <a
%   href="matlab:helpview('bluetooth','bluetoothLEMeshFriendshipTutorial')">Establish Friendship Between Friend Node and LPN in Bluetooth Mesh Network</a>.
%
%   See also bluetoothLEBIGConfig, bluetoothMeshProfileConfig,
%   bluetoothMeshFriendshipConfig, bluetoothLEConnectionConfig.

%   Copyright 2021-2023 The MathWorks, Inc.

properties % Configuration parameters
    %TransmitterPower Signal transmission power in dBm
    %   Specify the transmit power as a scalar in the range [-20, 20].
    %   Units are in dBm. This value specifies the average power that the
    %   transmitter applies on the signal before sending it to the antenna.
    %   The default value is 20 dBm.
    TransmitterPower (1,1) {mustBeNumeric, ...
        mustBeGreaterThanOrEqual(TransmitterPower,-20), ...
        mustBeLessThanOrEqual(TransmitterPower,20)} = 20

    %TransmitterGain Transmitter antenna gain in dB
    %   Specify the transmitter antenna gain as a finite numeric scalar.
    %   Units are in dB. The default value is 0 dB.
    TransmitterGain (1,1) {mustBeNumeric, mustBeFinite} = 0

    %ReceiverRange Packet reception range of the node in meters
    %   Specify this property as a finite positive scalar. Units are in
    %   meters. If an incoming signal is received from a node present
    %   beyond this value, the node drops this signal. Set this property to
    %   reduce the processing complexity of the simulation. The default
    %   value is 100 meters.
    ReceiverRange (1,1) {mustBePositive, mustBeFinite} = 100

    % ReceiverGain Receiver antenna gain in dB
    %   Specify the receiver antenna gain as a finite numeric scalar. Units
    %   are in dB. The default value is 0 dB.
    ReceiverGain (1,1) {mustBeNumeric, mustBeFinite} = 0

    %ReceiverSensitivity Receiver sensitivity in dBm
    %   Specify the receiver sensitivity as a finite numeric scalar. Units
    %   are in dBm. This property sets the minimum reception power to
    %   detect the incoming signal. If the received power of an incoming
    %   signal is below this value, the node considers the signal as
    %   invalid. The default value is -100 dBm.
    ReceiverSensitivity (1,1) {mustBeNumeric, mustBeFinite} = -100

    %NoiseFigure Noise figure in dB
    %   Specify the noise figure as a nonnegative finite scalar. Units are
    %   in dB. The object uses this value to apply thermal noise on the
    %   received signal. The default value is 0 dB.
    NoiseFigure (1,1) {mustBeNumeric, mustBeNonnegative, mustBeFinite} = 0

    %InterferenceFidelity Fidelity level to model interference
    %   Specify the fidelity level to model interference as 0 or 1. If you
    %   set this value to 0, the object considers packets overlapping in
    %   both time and frequency as interference. If you set this value to
    %   1, the object considers all the packets overlapping in time as
    %   interference, irrespective of frequency overlap. The default value
    %   is 0.
    InterferenceFidelity (1, 1) {mustBeInteger, mustBeMember(InterferenceFidelity, [0, 1])} = 0

    %AdvertisingInterval Advertising interval in seconds
    %   Specify advertising interval as a scalar in the range [0.02,
    %   10485.759375]. Units are in seconds. This value specifies the
    %   interval of an advertising event during which the transmission of
    %   advertising packets occurs. Set this value as an integer multiple
    %   of 0.625 milliseconds. The default value is 0.02 seconds.
    AdvertisingInterval = 0.02

    %RandomAdvertising Random advertising channel selection
    %   Specify the random advertising channel selection flag as 1 (true)
    %   or 0 (false). If you set this value to 1 (true), the object models
    %   the random selection of advertising channels. If you set this value
    %   to 0 (false), the object disables the random selection of
    %   advertising channels. The default value is 0 (false).
    RandomAdvertising (1,1) logical = false

    %ScanInterval Scan interval in seconds
    %   Specify scan interval as a scalar in the range [0.005, 40.960].
    %   Units are in seconds. This value specifies the interval in which
    %   the node listens for the advertising packets. Set this value as an
    %   integer multiple of 0.625 milliseconds. The default value is 0.005
    %   seconds.
    ScanInterval = 0.005

    %MeshConfig Bluetooth mesh configuration object for
    %"broadcaster-observer" role
    %   Specify mesh config as an object of type <a
    %   href="matlab:help('bluetoothMeshProfileConfig')">bluetoothMeshProfileConfig</a>.
    %   This value is used when the <a
    %   href="matlab:help('bluetoothLENode.Role')">Role</a> is set to
    %   "broadcaster-observer". The default value is an object of type
    %   "bluetoothMeshProfileConfig" with all properties set to their
    %   default values.
    MeshConfig = bluetoothMeshProfileConfig
end

properties (Constant, Hidden)
    % Allowed role values
    Role_Values = ["central", "peripheral", "isochronous-broadcaster", ...
        "synchronized-receiver", "broadcaster-observer"]

    %ReceiveBufferSize Maximum number of frames that can be stored at the
    %receiver buffer of the node
    ReceiveBufferSize = 10

    % Invoke channel if signal lies in the 2.4 GHz band. The 2.4 GHz band
    % for Bluetooth LE starts at 2.4e9 Hz and ends at 2.4835e9 Hz.
    BluetoothLEStartBand = 2.4e9 % in Hz
    BluetoothLEEndBand = 2.4835e9 % in Hz
end

properties (SetAccess = private)
    %Role Role of the Bluetooth LE node. The role is specified as any one
    %of "central", "peripheral", "isochronous-broadcaster",
    %"synchronized-receiver" or "broadcaster-observer"
    Role

    %ConnectionConfig Connection configuration object for "central" and
    %"peripheral" roles. Specify this property as an object or array of
    %objects of type <a
    %href="matlab:help('bluetoothLEConnectionConfig')">bluetoothLEConnectionConfig</a>.
    ConnectionConfig = bluetoothLEConnectionConfig

    %PeripheralCount Number of peripherals associated with the central.
    %This property is applicable only when the Role is "central". This
    %property is specified as a scalar nonnegative integer.
    PeripheralCount = 0
    
    %BIGConfig BIG configuration object for "isochronous-broadcaster" and
    %"synchronized-receiver" roles. Specify this property as an object of
    %type <a
    %href="matlab:help('bluetoothLEBIGConfig')">bluetoothLEBIGConfig</a>.
    BIGConfig = bluetoothLEBIGConfig

    %FriendshipConfig Friendship configuration object for a Friend and low
    %power node. Specify this property as an object of type <a
    %href="matlab:help('bluetoothMeshFriendshipConfig')">bluetoothMeshFriendshipConfig</a>.
    FriendshipConfig = bluetoothMeshFriendshipConfig

    %TransmitBuffer Buffer containing the data to be transmitted from the
    %node. Specify the property as a structure of the format <a
    %href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>.
    TransmitBuffer
end

properties (SetAccess = private, GetAccess = public, Hidden)
    %NumConnections Specifies the number of active connections in this
    %node. This property is applicable only for central and peripheral
    %roles.
    NumConnections = 0

    %CurrentTime Current time of the simulation in seconds. This value gets
    %updated for every call of the runNode.
    CurrentTime = 0

    %FriendshipEstablished Specifies whether friendship is already
    %established for this node
    FriendshipEstablished (1,1) logical = false
end

properties (Access = private)
    %pLinkLayer Link layer object based on the specified role
    pLinkLayer

    %pPHYTransmitter PHY transmitter object
    pPHYTransmitter

    %pPHYReceiver PHY receiver object
    pPHYReceiver

    %pMesh Bluetooth mesh profile object
    pMesh

    %pTrafficManager Traffic manager object
    pTrafficManager

    %pCurrentTimeInMicroseconds Current time in microseconds
    pCurrentTimeInMicroseconds = 0

    %pConnectedNodes Vector of node names which are associated with this
    %node
    pConnectedNodes = ""

    %pIsInitialized Flag to check whether the node is initialized or not
    pIsInitialized = false

    %pAppStatistics Statistics captured at the application on top of the
    %link layer
    pAppStatistics

    %pMeshAppStatistics Statistics captured at the application on top of
    %the mesh profile
    pMeshAppStatistics

    %pMeshAppStatisticsList Vector of pMeshAppStatistics storing mesh
    %application statistics
    pMeshAppStatisticsList

    %pMeshAppSize Size of pMeshAppStatisticsList
    pMeshAppSize = 0

    %pAppDataReceived Structure containing metadata for application data
    %reception event
    pAppDataReceived = struct("NodeName", blanks(0), ...
        "NodeID", [], ...
        "CurrentTime",[],...
        "ReceivedData", [], ...
        "SourceNode",blanks(0))

    %pMeshAppDataReceived Structure containing metadata for mesh
    %application data reception event
    pMeshAppDataReceived = struct("NodeName", blanks(0), ...
        "NodeID", [], ...
        "CurrentTime",[],...
        "Message", [], ...
        "SourceAddress", blanks(0), ...
        "DestinationAddress", blanks(0))
end

events
    %PacketTransmissionStarted is triggered when the node starts
    %transmitting a packet. PacketTransmissionStarted passes the event
    %notification along with this structure to the registered callback:
    %   NodeName         - Node name. The field value is a string scalar.
    %   NodeID           - Unique node identifier. The field value is a
    %                      scalar positive integer.
    %   CurrentTime      - Current simulation time in seconds. The field
    %                      value is a nonnegative numeric scalar.
    %   PDU              - PDU bits to be transmitted. The field value is a
    %                      binary column vector.
    %   AccessAddress    - Access address of the packet. The field value is
    %                      a string scalar representing 4-octet hexadecimal
    %                      number.
    %   ChannelIndex     - Channel index for transmission. The field is an
    %                      integer in the range [0, 39].
    %   PHYMode          - PHY transmission mode. The field value is one of
    %                      "LE1M", "LE2M", "LE500K" or "LE125K"
    %   TransmittedPower - Transmit power in dBm. The field value is a
    %                      scalar value.
    %   PacketDuration   - Packet duration in seconds. The field value is a 
    %                      positive numeric scalar.
    PacketTransmissionStarted

    %PacketReceptionEnded is triggered when a packet reception ends.
    %PacketReceptionEnded passes the event notification along with this
    %structure to the registered callback:
    %   NodeName       - Node name. The field value is a string scalar.
    %   NodeID         - Unique node identifier. The field value is a
    %                    scalar positive integer.
    %   CurrentTime    - Current simulation time in seconds. The field
    %                    value is a nonnegative numeric scalar.
    %   SourceNode     - Name of the source node. The field value is a
    %                    string scalar.
    %   SourceID       - Node ID of the source. The field value is a scalar
    %                    positive integer.
    %   SuccessStatus  - Flag indicating the success status of packet.
    %                    The field value is a logical scalar.
    %   PDU            - PDU bits to be received. The field value is a
    %                    binary column vector.
    %   AccessAddress  - Access address of the packet. The field value is a
    %                    string scalar representing 4-octet hexadecimal
    %                    number.
    %   ChannelIndex   - Channel index for reception. The field value is an
    %                    integer in the range [0, 39].
    %   PHYMode        - PHY reception mode. The field value is one of
    %                    "LE1M", "LE2M", "LE500K" or "LE125K".
    %   ReceivedPower  - Received power in dBm. the field value is a scalar
    %                    value.
    %   SINR           - Signal-to-interference plus noise ratio in dB. The
    %                    field value is a scalar.
    PacketReceptionEnded

    %ChannelMapUpdated is triggered when the node starts using the updated
    %channel map. ChannelMapUpdated passes the event notification along
    %with this structure to the registered callback:
    %   NodeName           - Node name. The field value is a string scalar.
    %   NodeID             - Unique node identifier. The field value is a
    %                        scalar positive integer.
    %   CurrentTime        - Current simulation time in seconds. The field
    %                        value is a nonnegative numeric scalar.
    %   PeerNode           - Name of the peer node. The field value is a
    %                        string scalar.
    %   PeerID             - Identifier of the peer node. The field value
    %                        is a scalar positive integer.
    %   UpdatedChannelList - List of good channels. The field value is a
    %                        vector of integers in the range [0, 36].
    ChannelMapUpdated

    %AppDataReceived is triggered when there is data for application
    %from the node. AppDataReceived passes the event notification
    %along with this structure to the registered callback:
    %   NodeName       - Node name. The field value is a string scalar.
    %   NodeID         - Unique node identifier. The field value is a
    %                    scalar positive integer.
    %   CurrentTime    - Current simulation time in seconds. The field
    %                    value is a nonnegative numeric scalar.
    %   SourceNode     - Name of the source node. The field value is a
    %                    string scalar.
    %   ReceivedData   - Received application data in decimal bytes. The
    %                    field value is a vector of integers in the range
    %                    [0, 255].
    AppDataReceived
    
    %MeshAppDataReceived is triggered when application data received for a
    %mesh node. MeshAppDataReceived passes the event notification along
    %with this structure to the registered callback:
    %   NodeName           - Name of the receiver node. The field value is
    %                        a string scalar.
    %   NodeID             - Unique identifier of the receiver node. The
    %                        field value is a scalar positive integer.
    %   CurrentTime        - Current simulation time in seconds. The field
    %                        value is a nonnegative numeric scalar.
    %   Message            - Received access message. The field value is a
    %                        vector of integers in the range [0, 255].
    %   SourceAddress      - Source address of the message. The field value
    %                        is a string scalar representing 2-octet
    %                        hexadecimal number.
    %   DestinationAddress - Destination address of the message. The field
    %                        value is a string scalar representing 2-octet
    %                        hexadecimal number.
    MeshAppDataReceived

    %ConnectionEventEnded is triggered at the end of each connection event.
    %ConnectionEventEnded passes the event notification along with this
    %structure to the registered callback:
    %   NodeName           - Node name. The field value is a string scalar.
    %   NodeID             - Unique node identifier. The field value is a
    %                        scalar positive integer.
    %   CurrentTime        - Current simulation time in seconds. The field
    %                        value is a nonnegative numeric scalar.
    %   Counter            - Current connection event counter. The field
    %                        value is a scalar integer in the range [0,
    %                        65535].
    %   TransmittedPackets - Number of transmitted packets in the
    %                        connection event. The field value is a scalar
    %                        nonnegative integer.
    %   ReceivedPackets    - Number of received packets in the connection
    %                        event. The field value is a scalar nonnegative
    %                        integer.
    %   CRCFailedPackets   - Number of received packets with CRC failure.
    %                        The field value is a scalar nonnegative
    %                        integer.
    ConnectionEventEnded
end

methods
    % Constructor
    function obj = bluetoothLENodeeFH(role, varargin)
        % Name-value pair check
        coder.internal.errorIf(mod(nargin-1,2) == 1, "bluetooth:bleShared:InvalidPVPairs");
        % Assign name-value arguments
        for idx = 1:2:nargin-1
            obj.(char(varargin{idx})) = varargin{idx+1};
        end
        % Validate the role
        obj.Role = validatestring(role, bluetoothLENodeeFH.Role_Values, mfilename, "role", 1);

        % Create callback for event notification from internal layers to the node
        notificationFcn = @(eventName, eventData) triggerEvent(obj, eventName, eventData);
        
        % Initialize the internal modules
        switch obj.Role
            case {"central", "peripheral"}
                obj.pLinkLayer = linkLayerConnectionseFH(notificationFcn,Role=obj.Role);
            case {"isochronous-broadcaster", "synchronized-receiver"}
                obj.pLinkLayer = ble.internal.linkLayerBroadcastIsochronousGroup(NotificationFcn=notificationFcn);
            case {"broadcaster-observer"}
                obj.pLinkLayer = ble.internal.linkLayerGAPBearer;
                obj.pMesh = ble.internal.meshProfile;
        end
        obj.pPHYTransmitter = ble.internal.phyTransmitter(NotificationFcn=notificationFcn);
        obj.pPHYReceiver = ble.internal.phyReceiver;
        obj.pTrafficManager = ble.internal.trafficManager;

        % Initialize application statistics structures
        obj.pAppStatistics = struct("DestinationNode", blanks(0), ...
            "TransmittedPackets", 0, ...
            "TransmittedBytes", 0, ...
            "ReceivedPackets", 0, ...
            "ReceivedBytes", 0, ...
            "AggregatePacketLatency", 0, ...
            "AveragePacketLatency", 0);

        obj.pMeshAppStatistics = struct( ...
            "SourceAddress", "0000", ...
            "DestinationAddress", "0000", ...
            "TransmittedPackets", 0, ...
            "TransmittedBytes", 0, ...
            "ReceivedPackets", 0, ...
            "ReceivedBytes", 0, ...
            "AggregatePacketLatency", 0, ...
            "AveragePacketLatency", 0);
    end

    % Set advertising interval
    function set.AdvertisingInterval(obj, value)
        validateattributes(value, {'numeric'}, {'scalar', '>=', 20e-3, ...
            '<=', 10485.759375}, mfilename, "AdvertisingInterval");
        coder.internal.errorIf((mod(value, 0.625e-3) ~= 0), ...
            "bluetooth:bluetoothLENode:InvalidAdvertisingInterval", num2str(value));
        obj.AdvertisingInterval = value; % in seconds
    end

    % Set scan interval
    function set.ScanInterval(obj, value)
        validateattributes(value, {'numeric'}, {'scalar', '>=', 5e-3, ...
            '<=', 40.960}, mfilename, "ScanInterval");
        coder.internal.errorIf((mod(value, 0.625e-3) ~= 0), ...
            "bluetooth:bluetoothLENode:InvalidScanInterval", num2str(value));
        obj.ScanInterval = value; % in seconds
    end
    
    % Set mesh configuration object
    function set.MeshConfig(obj, value)
        validateattributes(value, {'bluetoothMeshProfileConfig'}, {'scalar'}, ...
            mfilename, "MeshConfig");
        obj.MeshConfig = value;
    end

    % Get the number of peripherals associated with central node
    function value = get.PeripheralCount(obj)
        value = obj.NumConnections;
    end

    % Get the packet from node transmit buffer
    function value = get.TransmitBuffer(obj)
        value = pullTransmittedData(obj);
        if isempty(value)
            value = wirelessnetwork.internal.wirelessPacket;
        end
    end
end

methods (Access = protected)
    function flag = isInactiveProperty(obj, prop)
        flag = false;
        switch prop
            % Connection configuration is applicable only for central and
            % peripheral roles
            case "ConnectionConfig"
                flag = ~any(strcmpi(obj.Role, {'central', 'peripheral'}));
            % BIG configuration is applicable only for isochronous
            % broadcaster and synchronized-receiver roles
            case "BIGConfig"
                flag = ~any(strcmpi(obj.Role, {'isochronous-broadcaster', 'synchronized-receiver'}));
            % Peripheral count is applicable only for central role
            case "PeripheralCount"
                flag = ~strcmpi(obj.Role, "central");
            % Applicable only for broadcaster-observer role
            case {"AdvertisingInterval", "ScanInterval", "RandomAdvertising", "MeshConfig", "FriendshipConfig"}
                flag = ~strcmpi(obj.Role, "broadcaster-observer");
        end
    end
end

methods
    function addTrafficSource(obj, trafficSource, varargin)
        %addTrafficSource Add data traffic source to Bluetooth LE node
        %
        %   addTrafficSource(OBJ, TRAFFICSOURCE) adds a data traffic source
        %   object to the node. The traffic source, TRAFFICSOURCE, is an
        %   object of type <a
        %   href="matlab:help('networkTrafficOnOff')">networkTrafficOnOff</a>.
        %   To enable this syntax, set the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> property of
        %   <a href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to "isochronous-broadcaster".
        %
        %   addTrafficSource(OBJ, TRAFFICSOURCE,
        %   DestinationNode=destinationNode) adds a data traffic source
        %   object to the node for pumping traffic to the specified
        %   destination, DestinationNode. To enable this syntax, set the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a>
        %   property of <a href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to either "central" or "peripheral".
        %
        %   The "DestinationNode" argument specifies the destination node.
        %   Specify this input as a character vector or string scalar
        %   denoting the name of the destination. You can also specify
        %   this input as an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a> with
        %   the <a href="matlab:help('bluetoothLENode.Role')">Role</a> property set to either "central" or "peripheral".
        %
        %   addTrafficSource(OBJ, TRAFFICSOURCE,
        %   DestinationAddress=dstAddress, SourceAddress=srcAddress,
        %   varargin) adds a data traffic source object to the node for
        %   pumping the traffic between the source and the destination. To
        %   enable this syntax, set the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> property of
        %   <a href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to "broadcaster-observer".
        %
        %   addTrafficSource(OBJ, TRAFFICSOURCE,
        %   DestinationAddress=dstAddress, SourceAddress=srcAddress,
        %   TTL=ttl) adds a data traffic source object to the node for
        %   pumping the traffic between source and destination with the
        %   specified TTL (time-to-live) value. To enable this syntax, set
        %   the <a href="matlab:help('bluetoothLENode.Role')">Role</a> property of <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to "broadcaster-observer".
        %
        %   The "DestinationAddress" argument specifies the destination
        %   address of this message. Specify the destination address value
        %   as 4-element character vector or string scalar denoting a
        %   2-octet hexadecimal address. The destination address can be a
        %   valid element address in the mesh network or a group address.
        %
        %   The "SourceAddress" argument specifies the source address of
        %   this message. Specify the source address value as 4-element
        %   character vector or string scalar denoting a 2-octet
        %   hexadecimal unicast address. The source address must be one of
        %   the element address in the mesh node.
        %
        %   "TTL" argument is an optional input if the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> property of
        %   <a href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object is set to "broadcaster-observer".
        %   This value specifies time-to-live value for messages between
        %   the specified source and destination mesh elements. Specify the
        %   TTL value as an integer in the range [0, 127]. By default, this
        %   object function uses the TTL value specified by the <a
        %   href="matlab:help('bluetoothLENode.MeshConfig')">MeshConfig</a> object.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   TRAFFICSOURCE is an On-Off application traffic pattern object
        %   of type <a
        %   href="matlab:help('networkTrafficOnOff')">networkTrafficOnOff</a>
        %
        %   For more information, see <a
        %   href="matlab:helpview('bluetooth','bluetoothLEaddTrafficSourceExample')"
        %   >Create, Configure, and Simulate Bluetooth LE Network</a> example.

        % Validate traffic source object
        validateattributes(trafficSource, {'networkTrafficOnOff'}, {'scalar'},...
            mfilename, "trafficSource", 2);

        % Validate the name-value arguments
        upperLayerDataInfo = validateUpperLayerMetadata(obj, trafficSource, varargin{:});

        % Add the traffic source to the application manager
        addTrafficSource(obj.pTrafficManager, trafficSource, upperLayerDataInfo);
    end

    function status = updateChannelList(obj, newUsedChannelsList, varargin)
        %updateChannelList Provide the updated channel list to node
        %
        %   STATUS = updateChannelList(OBJ, NEWUSEDCHANNELSLIST) updates
        %   the channel map by providing a new list of used channels,
        %   NEWUSEDCHANNELSLIST, to the node and returns the status,
        %   STATUS, indicating whether the node accepted the new channel
        %   list or not. To enable this syntax, set the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> property of
        %   <a href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to "isochronous-broadcaster".
        %
        %   STATUS is a logical scalar value set as true when the link
        %   layer accepts the new channel list.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   NEWUSEDCHANNELSLIST is the list of good (used) channels,
        %   specified as an integer vector with element values in the range
        %   [0, 36].
        %
        %   STATUS = updateChannelList(OBJ, NEWUSEDCHANNELSLIST,
        %   DestinationNode=destinationNode) updates the channel map for
        %   the specified destination, DestinationNode. To enable this
        %   syntax, set the <a
        %   href="matlab:help('bluetoothLENode.Role')">Role</a> property of
        %   <a href="matlab:help('bluetoothLENode')">bluetoothLENode</a> object to "central".
        %
        %   The "DestinationNode" argument is a mandatory input, specifying
        %   the destination node. Specify this input as a character vector
        %   or string scalar specifying the name of the destination. You
        %   can also specify this input as an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a> with
        %   the <a href="matlab:help('bluetoothLENode.Role')">Role</a> property set to either "central" or "peripheral".
        %
        %   For more information, see <a href="matlab:helpview('bluetooth','bluetoothLEupdateChannelListExample')">Classify Channels and Update Channel Map in Bluetooth LE Network</a> example.

        coder.internal.errorIf(~obj.pIsInitialized, "bluetooth:bluetoothLENode:NodeNotInitialized");
        status = false;
        % Validate the roles and the respective NV-pairs
        switch obj.Role
            % Update channel list is not applicable for synchronized receiver,
            % peripheral or broadcaster-observer roles
            case {"synchronized-receiver", "peripheral", "broadcaster-observer"}
                coder.internal.error("bluetooth:bluetoothLENode:UpdateChannelListNotApplicable", obj.Role);
            case "isochronous-broadcaster" % No NV-pairs are applicable for isochronous broadcaster role
                narginchk(2, 2);
                status = updateChannelList(obj.pLinkLayer, newUsedChannelsList);
            case "central" % DestinationNodeID is applicable for central role
                narginchk(4, 4);
                for i = 1:2:nargin-2 % Apply name-value arguments
                    validatestring(varargin{i}, {'DestinationNode'}, ...
                        mfilename, "name-value-arguments");
                    validateattributes(varargin{i+1}, {'char', 'string', 'bluetoothLENode'}, ...
                        {'row'}, mfilename, "DestinationNode");
                    destinationNode = varargin{i+1};
                    if ischar(destinationNode) || isstring(destinationNode)
                        connectionIndex = find(strcmpi(destinationNode, obj.pConnectedNodes));
                    else
                        connectionIndex = find(strcmpi(destinationNode.Name, obj.pConnectedNodes));
                    end
                    status = updateChannelList(obj.pLinkLayer, newUsedChannelsList, connectionIndex);
                end
        end
    end

    function nodeStatistics = statistics(obj)
        %statistics Get the statistics of the node
        %
        %   NODESTATISTICS = statistics(OBJ) returns the node statistics.
        %
        %   NODESTATISTICS is a structure that stores the statistics of the node.
        %   If you specify the <a href="matlab:help('bluetoothLENode.Role')">Role</a> at node as "central" or "peripheral", then this
        %   value contains statistics related to Bluetooth low energy (LE) node with
        %   connection events. If you specify the <a href="matlab:help('bluetoothLENode.Role')">Role</a> at node as "isochronous-broadcaster"
        %   or "synchronized-receiver", then this value contains statistics related to
        %   Bluetooth LE node with broadcast isochronous group (BIG) events. If you 
        %   specify the <a href="matlab:help('bluetoothLENode.Role')">Role</a> at node as "broadcaster-observer", then this value contains
        %   statistics related to Bluetooth LE mesh node. For more information, see
        %   <a href="matlab:helpview('bluetooth','bluetoothLENodeStatistics')">Bluetooth LE Node Statistics</a>.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.

        nodeStatistics = struct();
        nodeStatistics.Name = obj.Name;
        nodeStatistics.ID = obj.ID;
        phyTx = obj.pPHYTransmitter;
        phyRx = obj.pPHYReceiver;

        switch obj.Role
            case {"central", "peripheral", "isochronous-broadcaster", "synchronized-receiver"}
                for idx = 1:numel(obj.pAppStatistics)
                    if obj.pAppStatistics(idx).ReceivedPackets > 0
                        obj.pAppStatistics(idx).AveragePacketLatency = ...
                            obj.pAppStatistics(idx).AggregatePacketLatency/obj.pAppStatistics(idx).ReceivedPackets;
                    end
                end
                nodeStatistics.App = obj.pAppStatistics;
            case "broadcaster-observer"
                for idx = 1:numel(obj.pMeshAppStatisticsList)
                    if obj.pMeshAppStatisticsList(idx).ReceivedPackets > 0
                        obj.pMeshAppStatisticsList(idx).AveragePacketLatency = ...
                            obj.pMeshAppStatisticsList(idx).AggregatePacketLatency/obj.pMeshAppStatisticsList(idx).ReceivedPackets;
                    end
                end
                meshStats = statistics(obj.pMesh);
                nodeStatistics.App = obj.pMeshAppStatisticsList;
                nodeStatistics.Transport = meshStats.Transport;
                nodeStatistics.Network = meshStats.Network;
        end

        nodeStatistics.LL = statistics(obj.pLinkLayer);
        phyStats = statistics(phyRx);
        phyStats.TransmittedPackets = phyTx.TransmittedPackets;
        phyStats.TransmittedBits = phyTx.TransmittedBits;
        nodeStatistics.PHY = phyStats;
    end

    function nextInvokeTime = runNode(obj, currentTime)
        %runNode Run Bluetooth LE node
        %
        %   NEXTINVOKETIME = runNode(OBJ, CURRENTTIME) runs the Bluetooth
        %   LE node at the current time instant, CURRENTTIME, and runs all
        %   the events scheduled at the current time. This function returns
        %   the time instant at which the node runs again.
        %
        %   NEXTINVOKETIME is a nonnegative numeric scalar specifying the
        %   time instant (in seconds) at which the Bluetooth LE node runs
        %   again.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   CURRENTTIME is a nonnegative numeric scalar specifying the
        %   current simulation time in seconds.
        %
        %   For more information, see <a href="matlab:helpview('bluetooth','bluetoothLErunNodeExample')">Run Bluetooth LE Node</a> example.
        
        coder.internal.warning("bluetooth:bluetoothLENode:DeprecatedFunction", "runNode");

        nextInvokeTime = run(obj, currentTime);
    end

    function pushChannelData(obj, packet)
        %pushChannelData Push data from channel to reception buffer
        %
        %   pushChannelData(OBJ, PACKET) pushes the packet, PACKET, from
        %   the channel to the reception buffer.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   PACKET is the packet received from the channel, specified as a
        %   structure of the format <a
        %   href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>.
        %
        %   For more information, see <a href="matlab:helpview('bluetooth','bluetoothLEpushChannelDataExample')">Run Bluetooth LE Node</a> example.

        coder.internal.warning("bluetooth:bluetoothLENode:DeprecatedFunction", "pushChannelData");

        pushReceivedData(obj, packet);
    end

    function [flag, rxInfo] = channelInvokeDecision(obj, packet)
        %channelInvokeDecision Determine whether to apply channel to
        %incoming signal
        %
        %   [FLAG, RXINFO] = channelInvokeDecision(OBJ, PACKET) determines
        %   whether the node wants to receive the packet and returns a
        %   flag, FLAG, indicating the decision and the receiver
        %   information, RXINFO, needed for applying channel on the
        %   incoming packet, PACKET.
        %
        %   FLAG is a logical scalar value indicating whether to invoke
        %   channel or not.
        %
        %   The object function returns the output, RXINFO, and is valid
        %   only when the FLAG value is 1 (true). The structure of this
        %   output contains these fields:
        %
        %   ID       - Node identifier of the receiver
        %   Position - Current receiver position in Cartesian coordinates,
        %              specified as a real-valued vector of the form [x y
        %              z]. Units are in meters.
        %   Velocity - Current receiver velocity (v) in the x-, y-, and
        %              z-directions, specified as a real-valued vector of
        %              the form [vx vy vz]. Units are in meters per second.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   PACKET is the transmitted packet on which the channel has to be
        %   applied. This value is specified as a structure of the format
        %   <a href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>.
        %
        %   For more information, see <a href="matlab:helpview('bluetooth','bluetoothLEchannelInvokeDecisionExample')">Run Bluetooth LE Node</a> example.

        coder.internal.warning("bluetooth:bluetoothLENode:DeprecatedFunction", "channelInvokeDecision");

        [flag, rxInfo] = isPacketRelevant(obj, packet);
    end
end

methods (Hidden)
    function addConnection(obj, connectionConfig)
        %addConnection Add connection to the node by configuring the
        %connection parameters. This is applicable only for central and
        %peripheral nodes.

        % Connection is only applicable for central and peripheral roles
        if ~any(strcmp(obj.Role, {'central', 'peripheral'}))
            return;
        end

        % Validate the input types
        validateattributes(connectionConfig, {'bluetoothLEConnectionConfig'}, ...
            {'scalar'}, mfilename, "connectionConfig", 2);

        if strcmpi(obj.Role, "peripheral")
            % Peripheral must have single connection only
            coder.internal.errorIf(obj.NumConnections >= 1, ...
                "bluetooth:bluetoothLENode:MustHaveOneConnection", ...
                obj.ConnectionConfig.PeripheralName, obj.ConnectionConfig.CentralName);
            destinationName = connectionConfig.CentralName;
        else
            if obj.NumConnections >= 1
                % All the connections at the central node must have the
                % same connection interval
                existingInterval = obj.ConnectionConfig(obj.NumConnections).ConnectionInterval;
                coder.internal.errorIf(existingInterval ~= connectionConfig.ConnectionInterval, ...
                    "bluetooth:bluetoothLENode:MustHaveSameConnectionInterval", ...
                    existingInterval);
            end
            destinationName = connectionConfig.PeripheralName;
        end
        % Update the number of connections and the connection configuration
        obj.NumConnections = obj.NumConnections + 1;
        obj.ConnectionConfig(obj.NumConnections) = connectionConfig;
        obj.pConnectedNodes(obj.NumConnections) = destinationName;
    end

    function addBIG(obj, bigConfig)
        %addBIG Add BIG parameters configuration to the node. This is
        %applicable only for isochronous broadcaster and synchronized
        %receiver nodes.

        % BIG configuration is only applicable for isochronous broadcaster
        % and synchronized receiver roles
        if ~any(strcmp(obj.Role, {'isochronous-broadcaster', 'synchronized-receiver'}))
            return;
        end

        % Validate the input types
        validateattributes(bigConfig, {'bluetoothLEBIGConfig'}, {'scalar'}, ...
            mfilename, "bigConfig", 2);

        % Update the BIG configuration
        obj.BIGConfig = bigConfig;
    end

    function addMeshFriendship(obj, friendshipConfig)
        %addMeshFriendship Add mesh friendship timing parameters
        %configuration to the node. This is applicable only for
        %broadcaster-observer Role.

        % Friendship configuration is only applicable for mesh role
        % (broadcaster-observer)
        if ~strcmp(obj.Role, "broadcaster-observer")
            return;
        end

        % Validate the input type
        validateattributes(friendshipConfig, {'bluetoothMeshFriendshipConfig'}, {'scalar'}, ...
            mfilename, "FriendshipConfig", 2);

        % Update the mesh friendship configuration
        obj.FriendshipConfig = friendshipConfig;
        obj.FriendshipEstablished = true;
    end

    function nextInvokeTime = run(obj, currentTime)
        %run Run the layers of the Bluetooth LE node at the current time
        %instant
        %
        %   NEXTINVOKETIME = runNode(OBJ, CURRENTTIME) runs the Bluetooth
        %   LE node at the current time instant, CURRENTTIME, and runs all
        %   the events scheduled at the current time. This function returns
        %   the time instant at which the node runs again.
        %
        %   NEXTINVOKETIME is a nonnegative numeric scalar specifying the
        %   time instant (in seconds) at which the Bluetooth LE node runs
        %   again.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   CURRENTTIME is a nonnegative numeric scalar specifying the
        %   current simulation time in seconds.
        
        % Initialize the node
        if ~obj.pIsInitialized
            init(obj);
        end
        % Update the simulation time
        timeInMicroseconds = round(currentTime*1e6, 3);
        elapsedTime = timeInMicroseconds - obj.pCurrentTimeInMicroseconds;
        obj.CurrentTime = currentTime;
        obj.pCurrentTimeInMicroseconds = timeInMicroseconds;

        % Rx buffer has data to be processed
        if obj.ReceiveBufferIdx ~= 0
            % Process the data in the Rx buffer
            for idx = 1:obj.ReceiveBufferIdx
                % Get the data from the Rx buffer and process the data
                dt = runLayers(obj, elapsedTime, obj.ReceiveBuffer{idx});
                % Set the elapsed time as 0, because all the data in the Rx
                % buffer must be processed at the same timestamp
                elapsedTime = 0;
            end
            obj.ReceiveBufferIdx = 0;
        else % Rx buffer has no data to process
            % Advance the current time by elapsed time and run all the
            % layers
            dt = runLayers(obj, elapsedTime, []);
        end
        nextInvokeTimeInMicroseconds = dt + obj.pCurrentTimeInMicroseconds;
        nextInvokeTime = round(nextInvokeTimeInMicroseconds/1e6, 9);
    end

    function pushReceivedData(obj, packet)
        %pushReceivedData Push the received packet to node
        %
        %   pushReceivedData(OBJ, PACKET) pushes the received packet,
        %   PACKET, from the channel to the reception buffer of the node.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   PACKET is the packet received from the channel, specified as a
        %   structure of the format <a
        %   href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>.

        % Copy the received signal to the buffer
        obj.ReceiveBufferIdx = obj.ReceiveBufferIdx + 1;
        obj.ReceiveBuffer{obj.ReceiveBufferIdx} = packet;
    end

    function [flag, rxInfo] = isPacketRelevant(obj, packet)
        %isPacketRelevant Return flag to indicate whether packet is
        %relevant for the node
        %
        %   [FLAG, RXINFO] = isPacketRelevant(OBJ, PACKET) returns a flag,
        %   FLAG, specifying whether the incoming packet, PACKET, is
        %   relevant for the node. The object function also returns the
        %   receiver information, RXINFO, required to apply channel
        %   information on the incoming packet.
        %
        %   FLAG is a logical scalar value indicating whether to invoke
        %   channel or not.
        %
        %   The object function returns the output, RXINFO, and is
        %   valid only when the FLAG value is 1 (true). The structure
        %   of this output contains these fields:
        %
        %   ID       - Node identifier of the receiver
        %   Position - Current receiver position in Cartesian coordinates,
        %              specified as a real-valued vector of the form [x y
        %              z]. Units are in meters.
        %   Velocity - Current receiver velocity (v) in the x-, y-, and
        %              z-directions, specified as a real-valued vector of
        %              the form [vx vy vz]. Units are in meters per second.
        %
        %   OBJ is an object of type <a
        %   href="matlab:help('bluetoothLENode')">bluetoothLENode</a>.
        %
        %   PACKET is the incoming packet to the channel, specified as a
        %   structure of the format <a
        %   href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>.

        % Initialize
        flag = false;
        rxInfo = struct("ID",0,"Position",[0 0 0],"Velocity",[0 0 0],"NumReceiveAntennas",1);

        % Ignore packet transmitted by this node
        if packet.TransmitterID == obj.ID
            return;
        end

        % Transmitter position and frequency
        txPosition = packet.TransmitterPosition;
        txStartFrequency = packet.CenterFrequency-packet.Bandwidth/2;
        txEndFrequency = packet.CenterFrequency+packet.Bandwidth/2;

        % Invoke channel if signal lies in the 2.4 GHz band. The 2.4 GHz
        % band starts at 2.4 GHz and ends at 2.4835 GHz.
        if (txStartFrequency >= obj.BluetoothLEStartBand && txStartFrequency <= obj.BluetoothLEEndBand) || ...
                (txEndFrequency >= obj.BluetoothLEStartBand && txEndFrequency <= obj.BluetoothLEEndBand)
            % Calculate the distance between the transmitter and receiver in meters
            distance = norm(txPosition - obj.Position);

            % Invoke channel if the transmitter lies within the range of
            % receiving node
            if (distance <= obj.ReceiverRange)
                flag = true;
                rxInfo.ID = obj.ID;
                rxInfo.Position = obj.Position;
                rxInfo.Velocity = obj.Velocity;
            end
        end
    end
end

methods (Access = private)
    function init(obj)
    %init Initialize the Bluetooth LE node and its internal modules

        % Initialize LL
        switch obj.Role
            case {"central", "peripheral"}
                appStats = repmat(obj.pAppStatistics, 1, obj.PeripheralCount);
                obj.pLinkLayer.PeripheralCount = obj.PeripheralCount;
                obj.pLinkLayer.TransmitterPower = obj.TransmitterPower;
                for idx = 1:obj.NumConnections
                    if strcmp(obj.Role, "central")
                        appStats(idx).DestinationNode = obj.ConnectionConfig(idx).PeripheralName;
                    else
                        appStats(idx).DestinationNode = obj.ConnectionConfig(idx).CentralName;
                    end
                    updateConnectionConfig(obj.pLinkLayer, idx, obj.ConnectionConfig(idx));
                end
                obj.pAppStatistics = appStats;
            case {"isochronous-broadcaster", "synchronized-receiver"}
                obj.pLinkLayer.Role = obj.Role;
                obj.pLinkLayer.TransmitterPower = obj.TransmitterPower;
                updateBIGConfig(obj.pLinkLayer, obj.BIGConfig);
            case "broadcaster-observer"
                obj.pLinkLayer.AdvertisingInterval = obj.AdvertisingInterval;
                obj.pLinkLayer.ScanInterval = obj.ScanInterval;
                obj.pLinkLayer.RandomAdvertising = obj.RandomAdvertising;
                obj.pLinkLayer.TransmitterPower = obj.TransmitterPower;
                if obj.MeshConfig.LowPower
                    updateLPNState(obj.pLinkLayer, obj.pMesh.LPNSleeping);
                end
                % Initialize mesh profile
                init(obj.pMesh, obj.MeshConfig);
                % Add friendship configuration at mesh profile
                if obj.FriendshipEstablished
                    configureFriendship(obj.pMesh, obj.FriendshipConfig);
                end
                obj.pMeshAppStatisticsList = obj.pMeshAppStatistics;
        end
        init(obj.pLinkLayer);

        % Initialize PHY transmitter
        obj.pPHYTransmitter.TransmitterGain = obj.TransmitterGain;

        % Initialize PHY receiver
        obj.pPHYReceiver.NoiseFigure = obj.NoiseFigure;
        obj.pPHYReceiver.ReceiverGain = obj.ReceiverGain;
        obj.pPHYReceiver.ReceiverSensitivity = obj.ReceiverSensitivity;
        obj.pPHYReceiver.InterferenceFidelity = obj.InterferenceFidelity;
        init(obj.pPHYReceiver);

        % Fill node ID in the Tx buffer        
        obj.pIsInitialized = true;
    end

    function nextInvokeTime = runLayers(obj, elapsedTime, signal)
    %runLayers Runs the layers within the node with the received signal and
    %returns the next invoke time (in microseconds)

        mesh = obj.pMesh; % Mesh profile object
        nextMeshTime = Inf;
        linkLayer = obj.pLinkLayer; % Link layer object
        phyTx = obj.pPHYTransmitter; % PHY transmitter object
        phyRx = obj.pPHYReceiver; % PHY receiver object

        % Invoke the application data generators, and push data to lower
        % layers
        [nextAppTime, appData] = run(obj.pTrafficManager, elapsedTime);
        for appDataIdx = 1:numel(appData)
            if ~isempty(appData(appDataIdx).Data)
                pushUpperLayerData(obj, appData(appDataIdx));
            end
        end

        % Invoke the PHY receiver module
        [nextPHYRxTime, indicationFromPHY] = run(phyRx, elapsedTime, signal);

        % Invoke the link layer module
        [nextLLTime, requestToPHY] = run(linkLayer, elapsedTime, indicationFromPHY);

        % LL requests PHY receiver
        if ~isempty(linkLayer.RxRequest)
            phyRx.RxRequest = linkLayer.RxRequest;
        end

        switch obj.Role
            case {"central", "peripheral"}
                % Link layer decoded successfully
                if ~isempty(linkLayer.RxUpperLayerData)
                    peerIdx = linkLayer.RxActiveConnectionIdx;
                    sourceNode = obj.pConnectedNodes(linkLayer.RxActiveConnectionIdx);
                    updateAppStatistics(obj, peerIdx, sourceNode);
                end
            case {"isochronous-broadcaster", "synchronized-receiver"}
                % Link layer decoded successfully
                if ~isempty(linkLayer.RxUpperLayerData)
                    peerIdx = 1;
                    sourceNode = obj.BIGConfig.BroadcasterName;
                    updateAppStatistics(obj, peerIdx, sourceNode);
                end
            case "broadcaster-observer"
                % Link layer decoded successfully
                if ~isempty(linkLayer.RxUpperLayerData)
                    rxMeshPacket.Message = linkLayer.RxUpperLayerData;
                    rxMeshPacket.Timestamp = linkLayer.RxUpperLayerTimestamp;
                else
                    rxMeshPacket = [];
                end

                % Invoke mesh profile
                [nextMeshTime, txMeshPacket] = run(mesh, elapsedTime, rxMeshPacket);
                if obj.MeshConfig.LowPower % Set link layer state for LPN
                    nextLLTime = updateLPNState(linkLayer, mesh.LPNSleeping);
                end
                if ~isempty(txMeshPacket) % Push mesh packet into link layer
                    [~, nextLLTime] = pushUpperLayerPDU(linkLayer, txMeshPacket.Message, txMeshPacket.Timestamp);
                end
                if linkLayer.PacketReceptionEnded % Trigger packet reception event for successful and failed receptions
                    triggerEvent(obj, "PacketReceptionEnded", linkLayer.PacketReceptionEndedData);
                end
                if mesh.MeshAppDataReceived.IsTriggered % Mesh decoding successful, update mesh application statistics
                    updateMeshAppStats(obj, mesh.MeshAppDataReceived.SourceAddress, ...
                        mesh.MeshAppDataReceived.DestinationAddress, mesh.MeshAppDataReceived.Message);
                end
        end

        % Invoke the PHY transmitter module
        txPacket = run(phyTx, requestToPHY);

        % Update the transmitted waveform along with the metadata
        if ~isempty(txPacket)
            txPacket.TransmitterID = obj.ID;
            txPacket.TransmitterPosition = obj.Position;
            txPacket.TransmitterVelocity = obj.Velocity;
            txPacket.StartTime = obj.CurrentTime;
            txPacket.Metadata.TransmitterName = obj.Name;
        end
        obj.TransmitterBuffer = txPacket;

        % Update the next invoke time as minimum of next invoke times of
        % all the modules
        invokeTimes = [nextPHYRxTime nextLLTime nextMeshTime nextAppTime];
        nextInvokeTime = min(invokeTimes);
    end

    function upperLayerData = validateUpperLayerMetadata(obj, trafficSource, varargin)
        %validateUpperLayerMetadata Validate the name-value arguments for
        %the upper layer data

        % Initialize upper layer data structure
        upperLayerData = struct("ConnectionIndex", 0, "SourceAddress", "0000", ...
            "DestinationAddress", "0000", "TTL", 0);

        % Validate the roles and the respective name-value arguments
        switch obj.Role
            % Send data is not applicable for the synchronized-receiver
            case "synchronized-receiver"
                coder.internal.error("bluetooth:bluetoothLENode:TrafficSourceNotApplicable");
            % No name-value arguments are applicable for
            % "isochronous-broadcaster"
            case "isochronous-broadcaster"
                narginchk(2, 2);
                % Refer Bluetooth Core Specification v5.3, Volume 6, Part B, Section 4.4.6.3.
                coder.internal.errorIf(trafficSource.PacketSize > 251, "bluetooth:bluetoothLENode:InvalidPacketLength", obj.Role, "1", "251");
            % DestinationNodeID is applicable for "central" and "peripheral" roles
            case {"central", "peripheral"}
                narginchk(4, 4);
                nvPairs = {'DestinationNode'};
                % Refer Bluetooth Core Specification v5.3, Volume 6, Part B, Section 2.4.
                coder.internal.errorIf(trafficSource.PacketSize > 251, "bluetooth:bluetoothLENode:InvalidPacketLength", obj.Role, "1", "251");
            % "SourceAddress", "DestinationAddress" and "TTL" are applicable 
            % for "broadcaster-observer" role
            case "broadcaster-observer"
                narginchk(6, 8);
                nvPairs = {'SourceAddress', 'DestinationAddress', 'TTL'};
                upperLayerData.TTL = obj.MeshConfig.TTL;
                % Refer Bluetooth Mesh Profile v1.0.1, Section 3.5.2.1.
                coder.internal.errorIf(trafficSource.PacketSize > 15 || trafficSource.PacketSize < 5, ...
                    "bluetooth:bluetoothLENode:InvalidPacketLength", obj.Role, "5", "15");
        end

        % Apply name-value arguments
        for i = 1:2:nargin-2
            value = validatestring(varargin{i}, nvPairs, mfilename, "name-value-arguments");
            switch value
                case "DestinationNode"
                    validateattributes(varargin{i+1}, {'char', 'string', 'bluetoothLENode'}, ...
                        {'row'}, mfilename, "DestinationNode");
                    destinationNode = varargin{i+1};
                    connectedNodes = strjoin(obj.pConnectedNodes, ", ");
                    if isa(destinationNode, "bluetoothLENode")
                        connectionIndex = find(strcmp(destinationNode.Name, obj.pConnectedNodes));
                    else
                        connectionIndex = find(strcmpi(destinationNode, obj.pConnectedNodes));
                    end
                    coder.internal.errorIf(isempty(connectionIndex), ...
                        "bluetooth:bluetoothLENode:InvalidDestinationNode", connectedNodes(1,:));
                    upperLayerData.ConnectionIndex = connectionIndex;
                case "SourceAddress"
                    % Validate the input source address field. Refer Mesh
                    % Profile v1.0.1 of Bluetooth Specification | Section
                    % 3.4.4.6
                    srcAddress = varargin{i+1};
                    ble.internal.validateHex(srcAddress, 4, "SourceAddress");
                    addressBinary = int2bit(hex2dec(srcAddress), 16);
                    coder.internal.errorIf((~(addressBinary(1) == 0 && sum(addressBinary) ~= 0)), ...
                        "bluetooth:bluetoothLENode:AddTrafficInvalidSRC");
                    upperLayerData.SourceAddress = char(srcAddress);
                case "DestinationAddress"
                    % Validate the input destination address field. Refer
                    % Mesh Profile v1.0.1 of Bluetooth Specification |
                    % Section 3.4.4.7
                    dstAddress = varargin{i+1};
                    ble.internal.validateHex(dstAddress, 4, "DestinationAddress");
                    upperLayerData.DestinationAddress = char(dstAddress);
                case "TTL"
                    % Validate the input time to live field. Refer Mesh
                    % Profile v1.0.1 of Bluetooth Specification | Section
                    % 3.6.4.4
                    ttl = varargin{i+1};
                    validateattributes(ttl, {'numeric'}, {'integer', 'nonempty', ...
                        'nonnegative', '<=', 127}, mfilename, "TTL");
                    upperLayerData.TTL = ttl;
            end
        end
    end

    function pushUpperLayerData(obj, upperLayerData)
        %pushUpperLayerData Push the upper layer data into the lower layer
        %based on role

        switch obj.Role
            case {"central", "peripheral"}
                connectionIndex = upperLayerData.ConnectionIndex;
                pushUpperLayerPDU(obj.pLinkLayer, connectionIndex, ...
                    upperLayerData.Data, obj.pCurrentTimeInMicroseconds);
                obj.pAppStatistics(connectionIndex).TransmittedPackets = ...
                    obj.pAppStatistics(connectionIndex).TransmittedPackets + 1;
                obj.pAppStatistics(connectionIndex).TransmittedBytes = ...
                    obj.pAppStatistics(connectionIndex).TransmittedBytes + numel(upperLayerData.Data);
            case "broadcaster-observer"
                srcAddress = upperLayerData.SourceAddress;
                dstAddress = upperLayerData.DestinationAddress;
                ttl = upperLayerData.TTL;
                pushAccessMessage(obj.pMesh.TransportLayer, upperLayerData.Data, ...
                    srcAddress, dstAddress, ttl, obj.pCurrentTimeInMicroseconds);
                updateMeshAppStats(obj, srcAddress, dstAddress, upperLayerData.Data);
            case "isochronous-broadcaster"
                pushUpperLayerPDU(obj.pLinkLayer, upperLayerData.Data, obj.pCurrentTimeInMicroseconds);
                obj.pAppStatistics(1).TransmittedPackets = ...
                    obj.pAppStatistics(1).TransmittedPackets + 1;
                obj.pAppStatistics(1).TransmittedBytes = ...
                    obj.pAppStatistics(1).TransmittedBytes + numel(upperLayerData.Data);
        end
    end

    function updateAppStatistics(obj, peerIdx, sourceNode)
        %updateAppStatistics Update application statistics for "central",
        %"peripheral", "isochronous-broadcaster" and
        %"synchronized-receiver" roles

        obj.pAppStatistics(peerIdx).ReceivedPackets = ...
            obj.pAppStatistics(peerIdx).ReceivedPackets + 1;
        obj.pAppStatistics(peerIdx).ReceivedBytes = ...
            obj.pAppStatistics(peerIdx).ReceivedBytes + numel(obj.pLinkLayer.RxUpperLayerData);
        packetLatency = (obj.pCurrentTimeInMicroseconds - obj.pLinkLayer.RxUpperLayerTimestamp)/1e6;
        obj.pAppStatistics(peerIdx).AggregatePacketLatency = ...
            obj.pAppStatistics(peerIdx).AggregatePacketLatency + packetLatency;

        % Trigger app packet reception event
        eventData = obj.pAppDataReceived;
        eventData.SourceNode = sourceNode;
        eventData.ReceivedData = obj.pLinkLayer.RxUpperLayerData;
        triggerEvent(obj, "AppDataReceived", eventData);
    end

    function updateMeshAppStats(obj, srcAddress, dstAddress, message)
        %updateMeshAppStats Update mesh application statistics

        meshAppIdx = -1;
        % Get the application index to which the packet belongs
        for idx = 1:obj.pMeshAppSize
            if (strcmpi(obj.pMeshAppStatisticsList(idx).SourceAddress, srcAddress) ...
                    && strcmpi(obj.pMeshAppStatisticsList(idx).DestinationAddress, dstAddress))
                meshAppIdx = idx;
                break;
            end
        end

        % Add a new application statistics structure to the list
        if meshAppIdx == -1
            obj.pMeshAppSize = obj.pMeshAppSize + 1;
            obj.pMeshAppStatisticsList(obj.pMeshAppSize) = obj.pMeshAppStatistics;
            meshAppIdx = obj.pMeshAppSize;
            % Update source and destination element addresses at the application
            % statistics
            obj.pMeshAppStatisticsList(meshAppIdx).SourceAddress = srcAddress;
            obj.pMeshAppStatisticsList(meshAppIdx).DestinationAddress = dstAddress;
        end
        appStats = obj.pMeshAppStatisticsList(meshAppIdx);

        % Update the application receive statistics
        if obj.pMesh.MeshAppDataReceived.IsTriggered
            rxMeshApptimestamp = obj.pMesh.MeshAppDataReceived.Timestamp;
            appStats.ReceivedPackets = appStats.ReceivedPackets + 1;
            appStats.ReceivedBytes = appStats.ReceivedBytes + numel(message);
            packetLatency = (obj.pCurrentTimeInMicroseconds - rxMeshApptimestamp)/1e6;
            appStats.AggregatePacketLatency = appStats.AggregatePacketLatency + packetLatency;
        else % Update the application transmit statistics
            appStats.TransmittedPackets = appStats.TransmittedPackets + 1;
            appStats.TransmittedBytes = appStats.TransmittedBytes + numel(message);
        end
        obj.pMeshAppStatisticsList(meshAppIdx) = appStats;

        % Trigger mesh app packet reception event
        eventData = obj.pMeshAppDataReceived;
        eventData.Message = message;
        eventData.SourceAddress = srcAddress;
        eventData.DestinationAddress = dstAddress;
        triggerEvent(obj, "MeshAppDataReceived", eventData);
    end

    function triggerEvent(obj, eventName, eventData)
        %triggerEvent Trigger the event to notify all the listeners

        if event.hasListener(obj, eventName)
            eventData.NodeName = obj.Name;
            eventData.NodeID = obj.ID;
            eventData.CurrentTime = obj.CurrentTime;
            eventDataObj = ble.internal.nodeEventData;
            eventDataObj.Data = eventData;
            notify(obj, eventName, eventDataObj);
        end
    end
end
end

% LocalWords:  PHY isochronous TTL SINR PDU CRC RTT WLAN LENODE LEBIG TRAFFICSOURCE LEadd
% LocalWords:  NEWUSEDCHANNELSLIST LEupdate NODESTATISTICS LErun LEpush RXINFO vy vz LEchannel
