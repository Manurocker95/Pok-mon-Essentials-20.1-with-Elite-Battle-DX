module Settings
    USE_BUMP_SOUND = true
end
    
class Game_Player < Game_Character
    alias old_bump_into_object bump_into_object
    def bump_into_object
    return if (@bump_se && @bump_se > 0) || !Settings::USE_BUMP_SOUND
    pbSEPlay("Player bump") if !@move_route_forcing
    @bump_se = Graphics.frame_rate / 4
    end
end    