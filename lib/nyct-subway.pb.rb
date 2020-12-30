require 'protobuf'
require 'google/transit/gtfs-realtime.pb'

module Transit_realtime

  # forward declarations
  class TripReplacementPeriod < ::Protobuf::Message; end
  class NyctFeedHeader < ::Protobuf::Message; end
  class NyctTripDescriptor < ::Protobuf::Message; end
  class NyctStopTimeUpdate < ::Protobuf::Message; end

  class TripReplacementPeriod < ::Protobuf::Message
    optional :string, :route_id, 1
    optional TimeRange, :replacement_period, 2
  end

  class NyctFeedHeader < ::Protobuf::Message
    required :string, :nyct_subway_version, 1
    repeated TripReplacementPeriod, :trip_replacement_period, 2
  end

  class NyctTripDescriptor < ::Protobuf::Message
    # forward declarations

    # enums
    class Direction < ::Protobuf::Enum
      define :NORTH, 1
      define :EAST, 2
      define :SOUTH, 3
      define :WEST, 4
    end

    optional :string, :train_id, 1
    optional :bool, :is_assigned, 2
    optional Direction, :direction, 3
  end

  class TripDescriptor
    optional NyctTripDescriptor, :nyct_trip_descriptor, 1001
  end

  class NyctStopTimeUpdate < ::Protobuf::Message
    optional :string, :scheduled_track, 1
    optional :string, :actual_track, 2
  end

  class TripUpdate::StopTimeUpdate
    optional NyctStopTimeUpdate, :nyct_stop_time_update, 1001
  end
end
