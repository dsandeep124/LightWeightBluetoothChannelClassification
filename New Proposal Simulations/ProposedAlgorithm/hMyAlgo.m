classdef hMyAlgo < handle

    properties (GetAccess = public,SetAccess = private)
        %CentralNode Bluetooth Central node
        %   This indicates the Central node associated with the Peripheral
        %   node whose physical link needs to be classified.
        CentralNode

        %PeripheralNode Bluetooth Peripheral node
        %   This indicates the Peripheral node whose channel used for the
        %   physical link needs to be classified at the Central node.
        PeripheralNode

        %PreferredMinimumGoodChannels Minimum preferred number of good
        %channels
        %   This property is an integer in the range [2,37] for Bluetooth
        %   LE and [20 79] for Bluetooth BR. This property specifies the
        %   preferred number of minimum good channels that need to be
        %   maintained for the data exchange between Bluetooth devices
        PreferredMinimumGoodChannels

        %MinReceivedCountToClassify Minimum number of received packets to
        %classify the channels
        %   Specify the minimum received count as an integer greater than
        %   4. This property specifies the minimum number of received
        %   packets and status to be used for classification of the
        %   channels. The default value is 4.
        % MinReceptionsToClassify = 4

        %ChannelMap Channel map of Bluetooth data channels
        ChannelMap
    end

    properties (Access = private)
        %pLastRxStatus Status of the recent received packets
        %   pLastRxStatus is a two-dimensional array of size
        %   [obj.pNumDataChannels, obj.BufferSize].
        %   pLastRxStatus(channelNum,:) contains the status of previous
        %   receptions in the channel "channelNum". The received packet
        %   status value 0 represents "Failed", 1 represents "Success" and
        %   -1 indicates not yet received.
        pLastRxStatus

        %pRxIdx Current receiving packet index in pLastRxStatus array
        %   pRxIdx is a vector. pRxIdx(channelNum) represents the index in
        %   channel "channelNum".
        pRxIdx

        %BufferSize Size of the reception buffer to store the reception
        %status
        pBufferSize = 100

        %pNumDataChannels Number of data channels based on the Bluetooth
        %standard
        pNumDataChannels

        %pIsBluetoothBREDR Flag to represent Bluetooth BR protocol standard
        pIsBluetoothBREDR = false

        
    end
    properties
        InitialTrainingPeriodElapsed = false;
        PDRThreshold = 50;
        pRxPacketsCount = zeros(1,37);
        pSuccessPacketsCount = zeros(1,37);
        pFailPacketsCount = zeros(1,37);

        pSuccessPacketsCountAtClassification = zeros(1,37);
        pFailPacketsCountAtClassification = zeros(1,37);
        pSuccessRateOfChange=ones(1,37)*100;
        pFailRateOfChange=zeros(1,37);
        pPrevChannelMap=ones(1,37);
    end

    methods
        function obj = hMyAlgo(centralNode,peripheralNode,varargin)
            %Constructor
			
            % Initialize based on the Bluetooth node
            if isa(peripheralNode, "bluetoothNode")
                obj.pIsBluetoothBREDR = true;
                obj.pNumDataChannels = 79;
                obj.PreferredMinimumGoodChannels = 20;
            else
                obj.pNumDataChannels = 37;
                obj.PreferredMinimumGoodChannels = 2;
            end
            % Set name-value pairs
            for idx = 1:2:nargin-2
                propertyName = varargin{idx};
                value = varargin{idx+1};
                obj.(propertyName) = value;
            end
            % Update the channel map and Peripheral node
            usedChannels = centralNode.ConnectionConfig.UsedChannels;
            channelMapUsed = zeros(1,obj.pNumDataChannels);
            channelMapUsed(usedChannels+1) = 1;
            obj.ChannelMap = channelMapUsed;
            % Validate the Central node
            validateattributes(centralNode, ["bluetoothLENode","bluetoothNode"], {'scalar'});
            obj.CentralNode = centralNode;
            % Validate the Peripheral node
            validateattributes(peripheralNode, ["bluetoothLENode","bluetoothNode"], {'scalar'});
            obj.PeripheralNode = peripheralNode;
            % verifyConnection(obj);

            % Initialize the status of the receptions to -1. These
            % receptions are per data channel. Value 1 indicates success, 0
            % indicates failure and -1 indicates not yet received.
            obj.pLastRxStatus = ones(obj.pNumDataChannels,obj.pBufferSize)*-1;
            obj.pRxIdx = ones(1,obj.pNumDataChannels);

            % Add listener at the Central node  for the
            % PacketReceptionEnded event exposed by the bluetoothNode
            % object to receive packet reception information
            addlistener(obj.CentralNode,"PacketReceptionEnded", @(nodeObj,eventdata) updateRxStatus(obj,eventdata));
        end

        function updateRxStatus(obj,rxEventData)
            %updateRxStatus Updates the status of the received packet

            rxInfo = rxEventData.Data;
            % Get the node ID from where the Central received the
            % information
            if obj.pIsBluetoothBREDR
                sourceNodeID = rxInfo.SourceNodeID;
            else
                sourceNodeID = rxInfo.SourceID;
            end
            % Check if the Peripheral ID of the classifier object is same
            % as node ID of the received information
            if obj.PeripheralNode.ID == sourceNodeID
                indexPos = rxInfo.ChannelIndex+1;
                % Update the reception information
                obj.pLastRxStatus(indexPos,obj.pRxIdx(indexPos)) = rxInfo.SuccessStatus;
                obj.pRxIdx(indexPos) = obj.pRxIdx(indexPos)+1;
                % If the reception index of the received channel is greater
                % than the number of receptions reset the index
                if obj.pRxIdx(indexPos)>obj.pBufferSize
                    obj.pRxIdx(indexPos) = 1;
                end
				
				obj.pRxPacketsCount(indexPos)=obj.pRxPacketsCount(indexPos)+1;
				obj.pSuccessPacketsCount(indexPos) = obj.pSuccessPacketsCount(indexPos)+double(rxInfo.SuccessStatus);
				obj.pFailPacketsCount(indexPos) = obj.pFailPacketsCount(indexPos)+double(~rxInfo.SuccessStatus); 
            end                       
        end

        function classifyChannels(obj)
            %classifyChannels Classifies the channels into good or bad
            %based on statistics of each channel
            if obj.InitialTrainingPeriodElapsed
                obj.pSuccessRateOfChange = fillmissing(((obj.pSuccessPacketsCount-obj.pSuccessPacketsCountAtClassification)./obj.pSuccessPacketsCount)*100, 'constant',0);
                obj.pFailRateOfChange = fillmissing(((obj.pFailPacketsCount-obj.pFailPacketsCountAtClassification)./obj.pFailPacketsCount)*100, 'constant',0);

                obj.pSuccessPacketsCountAtClassification=obj.pSuccessPacketsCount;
                obj.pFailPacketsCountAtClassification=obj.pFailPacketsCount;


                if all(obj.pSuccessRateOfChange==0) && all(obj.pFailRateOfChange==0)
                    goodchannels=0:36;
                else
                    goodchannels = find(obj.pSuccessRateOfChange>0)-1;
                    badChannels = find(obj.pFailRateOfChange>0)-1;
                    goodchannels = setdiff(goodchannels, badChannels);
                    if numel(goodchannels)<2
                        goodchannels=0:36;
                    end
                end
            else
                pdrPerChannel = (obj.pSuccessPacketsCount/obj.pRxPacketsCount)*100;
                pdrPerChannel = fillmissing(pdrPerChannel, 'constant', 100);

                goodchannels = find(pdrPerChannel>=obj.PDRThreshold)-1;
                if numel(goodchannels)<2
                    goodchannels=0:36;
                end
                obj.InitialTrainingPeriodElapsed = true;
            end

            updateChannelList(obj.CentralNode,goodchannels,"DestinationNode",obj.PeripheralNode);
            obj.pPrevChannelMap=goodchannels;
        end
    end
end