function editor_Player!(jwb)
    combine_args_sheet!(jwb, :DevelopmentLevel, :PartTime; key = :Level)
    combine_args_sheet!(jwb, :DevelopmentLevel, :DroneDelivery; key = :Level)
    combine_args_sheet!(jwb, :DevelopmentLevel, :SpaceDrop; key = :Level)
end