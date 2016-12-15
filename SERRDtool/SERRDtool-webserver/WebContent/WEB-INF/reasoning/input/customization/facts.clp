(assert
(model
(metricName "Availability")
(quantitativeDefinition "Utilization,Size,*,#Host@Cluster,/,100,*,90,LT")
(unitName "Percent")
(entityType "Cluster")
)
)
(assert
(model
(metricName "Utilization")
(unitName "Percent")
(entityType "Cluster")
(conceptPool "Usage" "Percent In Use")
(hasMetric "Utilization@CPU" "Utilization@Memory")
)
)
