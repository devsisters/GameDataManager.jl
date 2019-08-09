function editor_Player!(jwb)
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:DroneDelivery], "Level")
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:PartTime], "Level")
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:SpaceDrop], "Level")

    deleteat!(jwb, :DroneDelivery)
    deleteat!(jwb, :PartTime)
    deleteat!(jwb, :SpaceDrop)

end