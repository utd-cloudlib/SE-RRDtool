(reset)
(import com.ncss.serrdtool.*)

; Assumption:
; 1. "@","::" should not be used as concept name
; 2. "#" can only be used for count of entities in cloud

;--------------------global variables-----------

;******** variables *********
(defglobal ?*subClassOf* = "http://www.w3.org/2000/01/rdf-schema#subClassOf")

(defglobal ?*Restriction* = "http://www.w3.org/2002/07/owl#Restriction")

(defglobal ?*type* = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type")

(defglobal ?*comment* = "http://www.w3.org/2000/01/rdf-schema#comment")

(defglobal ?*onProperty* = "http://www.w3.org/2002/07/owl#onProperty")

(defglobal ?*someValuesFrom* = "http://www.w3.org/2002/07/owl#someValuesFrom")

(defglobal ?*allValuesFrom* = "http://www.w3.org/2002/07/owl#allValuesFrom")

(defglobal ?*onClass* = "http://www.w3.org/2002/07/owl#onClass")

(defglobal ?*quantitativeDefinition* = "quantitativeDefinition")

(defglobal ?*conceptPool* = "conceptPool")


;******** static *********

(defglobal ?*ontologyFile* = "reasoning/input/ontology/redirect.clp")

(defglobal ?*queryFile* = "reasoning/input/query.clp")

(defglobal ?*archiveFile* = "reasoning/input/archive.clp")

(defglobal ?*simulatedFile* = "reasoning/input/ontology/transformed/batch.clp")

(defglobal ?*customizationFile* = "reasoning/input/customization/facts.clp")

(defglobal ?*outputFile* = "reasoning/out/output.txt")

(defglobal ?*metaFile* = "reasoning/input/Config/meta.clp")

(defglobal ?*cloudFile* = "reasoning/input/Config/cloud.clp")

;----------------- template section -------------------
(deftemplate triple 
    ; ontology will be translated into triples
    ; natually with prefix
    (slot predicate (default ""))
    (slot subject (default ""))
    (slot object (default ""))
    )

(deftemplate model
    ; customization will be represented in models
    ; load as existing facts
    ; without prefix 
    (slot metricName (type STRING))
    (slot quantitativeDefinition (type STRING))
    (multislot hasMetric (type STRING))
    (multislot conceptPool (type STRING))
    (slot unitName (type STRING))
    (slot entityType (type STRING))
    )

(deftemplate meta
    ; metadata will be saved in metas
    ; load as existing facts
    ; without prefix 
    (slot handle (type STRING))
    (slot path (type STRING))
    (slot DSName (type STRING))
    (slot CF (type STRING))
    (slot metricName (type STRING))
    (slot unitName (type STRING))
    (slot unit (type STRING))
    (slot entityType (type STRING))
    (slot entity (type STRING))
    (slot startTime (type STRING))
    (slot endTime (type STRING))
    (slot rows (type STRING))
    (slot step (type STRING))
    )

(deftemplate query
    ; format for new query
    ; load as existing facts
    ; without prefix 
    (slot metricName (type STRING))
    (slot DSName (type STRING))
    (slot CF (type STRING))
    (slot quantitativeDefinition (type STRING))
    (multislot helpList (type STRING))
    (multislot matchedList (type STRING))
    (slot unitName (type STRING))
    (slot unit (type STRING))
    (slot entityType (type STRING))
    (slot entity (type STRING))
    (slot startTime (type STRING))
    (slot endTime (type STRING))
    (slot rows (type STRING))
    (slot step (type STRING))
    )

(deftemplate archive
    ; saved reasoning result
    ; load as existing facts
    ; without prefix
    (slot metricName (type STRING))
    (slot unitName (type STRING))
    (slot unit (type STRING))
    (slot entityType (type STRING))
    (slot entity (type STRING))
    (slot quantitativeDefinition (type STRING))
    )

(deftemplate parsed
    ; final result for query
    ; with prefix
    ; remove prefix when output
    (slot metricName (type STRING))
    (slot unitName (type STRING))
    (slot unit (type STRING))
    (slot entityType (type STRING))
    (slot entity (type STRING))
    (slot quantitativeDefinition (type STRING))
    )

(deftemplate Config
    (declare (from-class Config))
    ;(include-variables TRUE))
    )

(deftemplate dataCenter
    (slot name (type STRING))
    (multislot cluster (type STRING))
    )

(deftemplate cluster
    (slot name (type STRING))
    (multislot host (type STRING))
    )

(deftemplate host
    (slot name (type STRING))
    (multislot VM (type STRING))
    )

;----------------- function section ----------------
(deffunction containsOperator (?string)
    (if (regexp "LT|LE|GT|GE|EQ|NE|MIN|MAX|AVG|MEDIAN|COUNT|SIN|COS|LOG|EXP|SQRT|FLOOR|CEIL|ABS|[-+/%\\*]|\\d+(\\.\\d+)?" ?string) then
        (return TRUE)
    )
    (return FALSE)
)

(deffunction hasMetric2String ($?list)
    (bind ?i (length$ $?list))
    ;(printout t "Metrics to string: length: " ?i crlf)
    ;(printout t "Metrics to string: list: " $?list crlf)
    (bind ?result "")
    (while (> ?i 0)
        (bind ?result (str-cat ?result (nth$ ?i $?list) ","))
        ;(printout t "Metrics to string: " ?result crlf)
        (-- ?i)
    )
    (bind ?result (str-cat ?result "AVG"))
    ;(printout t "Metrics to string: " ?result crlf)
    (return ?result)
)

(deffunction definition2List (?string)
    (bind $?result (create$ ))
    (bind ?delimeter ",")
    (while (> (str-length ?string) 0)
        (bind ?index (str-index ?delimeter ?string))
        (if (neq ?index FALSE) then
            (bind ?temp (sub-string 1 (- ?index 1) ?string))
            (if (not (containsOperator ?temp)) then ; this is a metric
                (bind $?result (union$ $?result (create$ ?temp)))                
            )
            (bind ?string (sub-string (+ ?index (str-length ?delimeter)) (str-length ?string) ?string))
         else ; single metric, possible???
            (if (not (containsOperator ?string)) then ; this is a metric
                (bind $?result (union$ $?result (create$ ?string)))                
            )
            (bind ?string "")  
        )
        ;(printout t "Definition: " ?string crlf)
    )
    (return $?result)
)

(deffunction modifyQuantitativeDefinition (?query ?meta)
    ; there could be multiple occurance within quantitativeDefinition
    (bind ?i (str-index ?meta.metriaName ?q.1uantitativeDefinition))
    (bind ?result "")
    (while (neq ?i FALSE)
        (bind ?result (sub-string 1 (- ?i 1) ?q.1uantitativeDefinition))
        (bind ?result (str-cat ?result ?meta.path "::" ?meta.DSName "::" ?meta.CF))
    )
)

;----------------- rule section  -------------------

; 1. ########## check cached result #########
(defrule checkArchive
    ; check whether the query is already in the archive
    (declare (salience 999))
    ?q <- (query (metricName ?metric)  (unitName ?unit) (entityType ?entityType) (entity ?entity))
    ?a <- (archive (metricName ?metric1&:(eq ?metric ?metric1)) (unitName ?unit1&:(eq ?unit ?unit1)) (entityType ?entityType1&:(eq ?entityType1 ?entityType)) (entity ?entity1&:(eq ?entity1 ?entity)))
    =>
    ; directly matched in archive, and output
    (assert
        (parsed
            (metricName ?metric1)
            (unitName ?unit1)
            (entityType ?entityName1)
            (entity ?entity1)
            (quantitativeDefinition ?a.quantitativeDefinition)
        )
    )    
)

(defrule checkMeta
    ; check whether the query is already in the meta
    (declare (salience 999))
    ?q <- (query (metricName ?metric)  (unitName ?unit) (entityType ?entityType) (entity ?entity))
    ?m <- (meta (metricName ?metric1&:(eq ?metric ?metric1)) (unitName ?unit1&:(eq ?unit ?unit1)) (entityType ?entityType1&:(eq ?entityType1 ?entityType)) (entity ?entity1&:(eq ?entity1 ?entity)))
    =>
     ; directly matched in model, and output
    (assert
        (parsed
            (metricName ?metric1)
            (unitName ?unit1)
            (entityType ?entity1)
            (entity ?entity1)
            (quantitativeDefinition ?m.quantitativeDefinition)
        )
    )
)

(defrule outputParsed
    ; if any queried metric is cached, then output
    (declare (salience 989))
    ?p <- (parsed)
    =>
    (open ?*outputFile* id w)
    (printout id "metricName: " ?p.metricName crlf "unitName: " ?p.unitName crlf "entityType: " ?p.entityType crlf "quantitativeDefinition" ?p.quantitativeDefinition crlf crlf)
    (close id)
    )

;
(defrule preprocess
    (declare (salience 988)) ;add metrics in quantitativeDefinition into helpList
    ?q <- (query (quantitativeDefinition ?quantitativeDefinition&:(neq ?quantitativeDefinition nil)))
    =>
    ;(printout t "Preprocess: " ?quantitativeDefinition crlf)
    (modify ?q
        (helpList (definition2List ?quantitativeDefinition))
    )
)

(defrule channelByCustomization_definition
    ; link through custormization, mainly by definition in customization
    ; has the highest priority during reasoning
    (declare (salience 899))
    ?q <- (query (metricName ?metricName) (entityType ?entityType) (quantitativeDefinition ?quantitativeDefinition))
    ?m <- (model (metricName ?metricName2&:(eq ?metricName ?metricName2)) (entityType ?entityType2&:(eq ?entityType2 ?entityType)) (quantitativeDefinition ?quantitativeDefinition2&:(and (neq ?quantitativeDefinition2 nil) (neq ?quantitativeDefinition2 ?quantitativeDefinition))))
    
    =>
    ;(printout t "customization defintion: " ?metricName2 " : " ?entityType2 " : " ?quantitativeDefinition2 crlf)
    (assert
        (query
            (metricName ?metricName)
            (quantitativeDefinition ?quantitativeDefinition2)
            (helpList (definition2List ?quantitativeDefinition2))
            (unitName ?q.unitName)
            (unit ?q.unit)
            (entityType ?entityType)
            (entity ?q.entity)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
        )
    )
    ;(printout t "Finished." crlf)
)

(defrule channelByCustomization_metric
    ; link through custormization, mainly by definition in customization
    ; has the highest priority during reasoning
    (declare (salience 899))
    ?q <- (query (metricName ?metricName) (entityType ?entityType))
    ?m <- (model (metricName ?metricName2&:(eq ?metricName ?metricName2)) (entityType ?entityType2&:(eq ?entityType2 ?entityType)) (hasMetric $?hasMetric2&:(neq (length$ $?hasMetric2) 0)))
    =>
    ; by default, the queried result is the average of the metrics linked by hasMetric
    ;(printout t "customization hasMetric: " ?metricName2 " : " ?entityType2 " : " $?hasMetric2 crlf)
    (assert
        (query
            (metricName ?metricName)
            (quantitativeDefinition (hasMetric2String $?hasMetric2))
            (helpList $?hasMetric2)
            (unitName ?q.unitName)
            (unit ?q.unit)
            (entityType ?entityType)
            (entity ?q.entity)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
        )
    )
)

(defrule channelByCustomization_pool
    ; link through custormization, mainly by definition in customization
    ; has the highest priority during reasoning
    ; shouldn't be fired when this metric is customized
    (declare (salience 899))
    =>
    
)

(defrule channelByConceptPool
    ; link through concept pool: replace the concept
    ; shouldn't be fired when this metric is customized
    (declare (salience 899))
    ?q <- (query (metricName ?metricName))
    ?commentTriple <- (triple (subject ?subject1&:(eq ?subject1 ?metricName)) (predicate ?predicate1&:(eq ?predicate1 ?*conceptPool*)) (object ?object1))
    =>
)

(defrule channelByHasMetric
    ; link through hasMetric relation: e.g. utilization to CPU@utilization, Mem@utilization, etc.
    ; by default, the final result is an average of all extened metrics
    ; shouldn't be fired when this channel is customized
    (declare (salience 889))
    ;; TODO: modify the first accumulate statement: how to avoid "nested query"?
    ?l <- (accumulate (bind $?list (create$))
        (bind $?list (union$ $?list (create$ (str-cat ?metric "::" ?entity))))
        $?list
        (model (metricName ?metric) (entityType ?entity))
        )
        
    ?q <- (query (metricName ?metricName) (entityType ?entityType&:(not (member$ (str-cat ?metricName "::" ?entityType) ?l)))) ; this channel should not be customized
    
    ?attr_restr <- (triple (subject ?subject1&:(eq ?subject1 ?metricName)) (predicate ?predicate1&:(eq ?predicate1 ?*subClassOf*)) (object ?object1))
    ?Restr <- (triple (subject ?subject2&:(eq ?subject2 ?object1)) (predicate ?predicate2&:(eq ?predicate2 ?*type*)) (object ?object2&:(eq ?object2 ?*Restriction*))  )
    ?property <- (triple (subject ?subject3&:(eq ?subject3 ?subject2)) (predicate ?predicate3&:(eq ?predicate3 ?*onProperty*)) (object ?object3&:(eq ?object3 "hasMetric")))
    
    ?m <- (accumulate (bind $?list (create$))
        (bind $? (union$ $?list (create$ ?object4)))
        $?list
        (triple (subject ?subject4&:(eq ?subject4 ?subject3)) (predicate ?predicate4&:(member$ ?predicate4 (create$ ?*someValuesFrom* ?*onClass* ?*allValuesFrom*))) (object ?object4))
        )
    
    =>
    ; by default, the queried result is the average of the metrics linked by hasMetric
    (assert
        (query
            (metricName ?metricName)
            (quantitativeDefinition (hasMetric2String ?m))
            (unitName ?q.unitName)
            (unit ?q.unit)
            (entityType ?entityType)
            (entity ?q.entity)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
        )
    )
)

(defrule channelByComment
    ; link l quantitative definition in ontology by comment: e.g. avalaibility to uptime and downtime
    ; shouldn't be fired when this metric is customized
    (declare (salience 889))
    ?q <- (query (metricName ?metricName))
    ?commentTriple <- (triple (subject ?subject1&:(eq ?subject1 ?metricName)) (predicate ?predicate1&:(eq ?predicate1 ?*quantitativeDefinition*)) (object ?object1))
    ;?node <- (treeNode (attributeName ?attributeName3&:(eq ?attributeName ?attributeName3)) (formula $?formula))
    =>
)

(defrule channelByEntity
    ; link through cloud entity, where only limited entity can be extended by restriction of specific metric
    (declare (salience 889))
    =>
)

(defrule channelByCounter
    ; link through "#"
    (declare (salience 889))
    =>
)




(defrule checkOutput
    ; for all the metrics, check whether metadata exists for each metric in definition
    (declare (salience 799))
    ?e <- (query (metricName ?metricName) (quantitativeDefinition ?quantitativeDefinition) (matchedList $?matchedList) (helpList $?helpList) (unitName ?unitName) (unit ?unit) (entityType ?entityType) (entity ?entity) (startTime ?startTime) (endTime ?endTime) (rows ?rows) (step ?step))
    ?m <- (meta (metricName ?metricName2&:(member$ ?metricName2 $?helpList)) (entityType ?entityType2&:(eq ?entityType ?entityType2)) (entity ?entity2&:(eq ?entity ?entity2)) (startTime ?startTime2&:(and (> ?startTime2 ?startTime) (< ?startTime2 ?endTime))) (endTime ?endTime2&:(< ?endTime2 ?endTime)))  
    /*
    ?q <- (accumulate (bind $?match $?helpList)
        (bind $?match (complement$ (create$ ?metricName2) $?match)) ;delete the matched metric
        ;(printout t "Accumulate test: " $?match crlf)
        $?match
        ;(meta (metricName ?metricName2&:(eq ?metricName ?metricName2)) (entityType ?entityType2&:(eq ?entityType ?entityType2)) (entity ?entity2&:(eq ?entity ?entity2)) (startTime ?startTime2&:(and (> ?startTime2 ?startTime) (< ?startTime2 ?endTime))) (endTime ?endTime2&:(< ?endTime2 ?endTime)))
        (meta (metricName ?metricName2&:(member$ ?metricName2 $?helpList)) (entityType ?entityType2&:(eq ?entityType ?entityType2)) (entity ?entity2&:(eq ?entity ?entity2)) )
        )
    */
    =>
    /*
    (if (eq (length$ ?q) 0) then
        (assert
            (parsed
                (metricName ?metricName)
            	(unitName ?unitName)
            	(entityType ?entityType)
            	(quantitativeDefinition ?quantitativeDefinition)
            )
        )
    )*/
    (modify ?e
        (matchedList (union$ $?matchedList (create$ ?metricName2)))
    )
    ;(printout t "Query with helpList: " $?helpList crlf)
    ;(bind $?match  ?helpList)
    ;(printout t "Test bind: " $?match crlf) 
)

(defrule generateOutput
    ; check whether a full match exist: for all the metrics, the metadata exists for each metric
    (declare (salience 799))
    ?e <- (query (metricName ?metricName) (quantitativeDefinition ?quantitativeDefinition) (matchedList $?matchedList) (helpList $?helpList&:(eq (length$ (intersection$ $?matchedList $?helpList)) (length$ $?helpList))) (unitName ?unitName) (unit ?unit) (entityType ?entityType) (entity ?entity) (startTime ?startTime) (endTime ?endTime) (rows ?rows) (step ?step))
    ?m <- (meta (metricName ?metricName2&:(member$ ?metricName2 $?helpList)) (entityType ?entityType2&:(eq ?entityType ?entityType2)) (entity ?entity2&:(eq ?entity ?entity2)) (startTime ?startTime2&:(and (> ?startTime2 ?startTime) (< ?startTime2 ?endTime))) (endTime ?endTime2&:(< ?endTime2 ?endTime)))
    =>
    (modify ?e
        (quantitativeDefinition (modifyQuantitativeDefinition ?e ?m))
    )
)

;------ test rule------

(defrule testQuery
    ?q <- (query) 
    =>
    (printout t "Query: " ?q.metricName " : " ?q.entityType " : " ?q.unitName " : " ?q.helpList "  : " ?q.matchedList "  : " ?q.quantitativeDefinition crlf)
    ;(printout t ((new Config) getPath) crlf)
)
/*
(defrule testModel
    ?q <- (model (hasMetric $?hasMetric)) 
    =>
    (printout t "Model: " ?q.metricName " : " ?q.entityType " : " ?q.unitName " : " ?q.quantitativeDefinition " : " $?hasMetric crlf)
)
*/
;------------ load facts ---------------
;new customization
(batch ?*customizationFile*)
; ontology
(batch ?*ontologyFile*)
; query
(batch ?*queryFile*)
; archive
(batch ?*archiveFile*)
; simulated facts as if in ontology
(batch ?*simulatedFile*)
; cloud config
(batch ?*cloudFile*)
; meta info
(batch ?*metaFile*)

(run)
