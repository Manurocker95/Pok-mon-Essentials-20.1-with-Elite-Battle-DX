module FootprintSettings
    TERRAIN_FOOT = 3                                                # Set here the terrain tag for footprints, 3 is sand
    INITIAL_FOOT_OPACITY = 62                                       # Initial opacity for footprints
    FOOT_DELAY_VELOCITY = 1.1                                       # Delay velocity
    FOOTPRINT_IMAGE_DIRECTORY = "Graphics/Pictures/Footset/"        # Path to the regular footprint set
    FOOTPRINT_REGULAR_IMAGE = "footset"                             # Name of the regular footprint set image
    FOOTPRINT_BIKE_IMAGE = "footsetbike"                            # Name of the bike footprint set
    EVENT_NAME_SKIP_FOOTPRINT = "/nofoot/"                          # If an event has this name, it skips the footprint
end    