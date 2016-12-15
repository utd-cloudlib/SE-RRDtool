(reset)
(import com.ncss.serrdtool.*)
(import java.lang.String)

; Assumption:
; 1. "@","::" should not be used as concept name
; 2. "#" can only be used for count of entities in cloud


; how to extend: metric@CPU@host001, metric@Memory@host001, metric@CPU@host002 and metric@Memory@host002 for cluster001
; format in helpList: metric@entityType[@entityType*]@entity, or #entityType1@entityType2
; customization can determine metric@entityType part
; extension rule should be triggered to modify @entity part
; knowledge in ontology only influence metric part

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
(defglobal ?*path* = "")

(defglobal ?*ontologyFile* = "reasoning/input/ontology/Ontology_V1.10_short.clp")

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
    (slot DSName (type STRING))
    (slot CF (type STRING))
    (slot metricName (type STRING))
    (slot unitName (type STRING))
    (slot unit (type STRING))
    (slot entityType (type STRING))
    (slot entity (type STRING))
    (slot quantitativeDefinition (type STRING))
    (slot startTime (type STRING))
    (slot endTime (type STRING))
    (slot rows (type STRING))
    (slot step (type STRING))
    )

(deftemplate parsed
    ; final result for query
    ; with prefix
    ; remove prefix when output
    (slot DSName (type STRING))
    (slot CF (type STRING))
    (slot metricName (type STRING))
    (slot unitName (type STRING))
    (slot unit (type STRING))
    (slot entityType (type STRING))
    (slot entity (type STRING))
    (slot quantitativeDefinition (type STRING))
    (slot startTime (type STRING))
    (slot endTime (type STRING))
    (slot rows (type STRING))
    (slot step (type STRING))
    (slot archive (type INTEGER) (default 0)) ; indicator whether this is from archive: 0 for not from archive, 1 for from archive
    )

(deftemplate Config
    (declare (from-class Config))
    ;(include-variables TRUE))
    )

(deftemplate String
    (declare (from-class String))
)

(deftemplate cloudEntity
    (slot entityType (type STRING))
    (slot entity (type STRING))
    (slot componentType (type STRING))
    (multislot component (type STRING))
)

(deftemplate cachedEntity
    (slot patten (type STRING))
    (slot count (type INTEGER))
)

;----------------- function section ----------------
(deffunction containsOperator (?string)
    ; input: a string
    ; output: a boolean value
    ; description: juedge whether a string is an operator supported by rpn
    (if (regexp "LT|LE|GT|GE|EQ|NE|MIN|MAX|AVG|MEDIAN|COUNT|SIN|COS|LOG|EXP|SQRT|FLOOR|CEIL|ABS|[-+/%\\*]|\\d+(\\.\\d+)?" ?string) then
        (return TRUE)
    )
    (return FALSE)
)

(deffunction containsEntityType (?string)
    ; input: a string
    ; output: a boolean value
    ; description: judge whether a string contains @entityType notation, if it contains, then return TRUE, otherwise, return FALSE
    
    (if (regexp ".*@(DataCenter|Cluster|Host|VM).*" ?string) then
        (return TRUE)
    ) 
    (return FALSE)
)

(deffunction isAdv (?string)
    ; input: a string
    ; output: a boolean value
    ; description: judge whether a string is in advanced format: metric@entityType[@entityType*]@entity, or #entityType1@entityType2, or handle::DSName::CF
    
    (if (regexp "(.+@(DataCenter|Cluster|Host|VM)@.+)|(.+::.+::.+)|(^#(DataCenter|Cluster|Host|VM)@(DataCenter|Cluster|Host|VM)$)" ?string) then
        (return TRUE)
    )
    (return FALSE)
)

(deffunction convert2Adv (?metricName ?entityType ?entity)
    ; input: a fact under template query
    ; output: advanced metric for input fact
    ; description: this is an initialization for each query
    (bind ?result ?metricName)
    (if (regexp ".+" ?entityType) then
        (bind ?result (str-cat ?result "@" ?entityType ))
    )
    (if (regexp ".+" ?entity) then
        (bind ?result (str-cat ?result "@" ?entity ))
    )
    (return ?result)
)


(deffunction definition2List (?query)
    ; input: a fact under template query
    ; output: a list of advanced metric 
    ; description: generate a list of advanced metric, each of which is from the quantitativeDefinition of this fact
    ; if the metric is already matched by meta data, and is in format of ".+::.+::.+", then it doesn't need to be converted 
    
    ; generate new helpList based on definition
    ; judge whether it's already in advanced metric mode
    (bind $?result (create$ ))
    (bind ?delimeter ",")
    (bind ?string ?query.quantitativeDefinition)
    (while (> (str-length ?string) 0)
        (bind ?index (str-index ?delimeter ?string))
        (if (neq ?index FALSE) then ; multiple metrics are involved
            (bind ?temp (sub-string 1 (- ?index 1) ?string)) ;?index won't casue access exceed boundary
            (if (not (containsOperator ?temp)) then ; this is a metric
                (if (isAdv ?temp) then
                    (bind $?result (union$ $?result (create$ (str-cat ?temp))))   
                 else
                    (bind $?result (union$ $?result (create$ (str-cat ?temp "@" ?query.entityType "@" ?query.entity))))   
                )                
            )
            (bind ?string (sub-string (+ ?index (str-length ?delimeter)) (str-length ?string) ?string))
         else ; single metric
            (if (not (containsOperator ?string)) then ; this is a metric
                (if (isAdv ?string) then
                    (bind $?result (union$ $?result (create$ (str-cat ?string)))) 
                 else 
                    (bind $?result (union$ $?result (create$ (str-cat ?string "@" ?query.entityType "@" ?query.entity)))) 
                )
                               
            )
            (bind ?string "")  
        )
        ;(printout t "Definition: " ?string crlf)
    )
    ;(printout t "Definition to list: " $?result crlf)
    (return $?result)
)

(deffunction formDefinition (?definition ?entityType ?entity ?post)
    ; input: a string of original definition, a string of entityType, a string of entity, a string of postfix
    ; output: a string of new definition
    ; description: the input definition may lost some content to be in advanced format, so other information need to be added to it
    
    (if (regexp ".+" ?entityType) then
        (bind ?post (str-cat "@" ?entityType ?post))
    )
    (if (regexp ".+" ?entity) then
        (bind ?post (str-cat "@" ?entity ?post))
    )
    
    (bind ?string ?definition)
    (bind ?delimeter ",")
    (bind ?result "")
    (while (> (str-length ?string) 0)
        (bind ?index (str-index ?delimeter ?string))
        (if (neq ?index FALSE) then ; not the end of the string
            (bind ?temp (sub-string 1 (- ?index 1) ?string))
            (if (not (or (isAdv ?temp) (containsOperator ?temp))) then ; this is a metric
                (bind ?result (str-cat ?result ?temp ?post ?delimeter))
             else
                (bind ?result (str-cat ?result ?temp ?delimeter))
            )
            (bind ?string (sub-string (+ ?index (str-length ?delimeter)) (str-length ?string) ?string))
         else
            (bind ?temp ?string)
            (if (not (or (isAdv ?temp) (containsOperator ?temp))) then ; this is a metric
                (bind ?result (str-cat ?result ?temp ?post))
             else
                (bind ?result (str-cat ?result ?temp))
            )
            (bind ?string "")
        )
    )
    ;(printout t "Formed definition: " ?result crlf)
    (return ?result)
)

(deffunction containsInDefinition (?mark ?definition)
    ; input: a string of mark, a string of definition
    ; output: a boolean value
    ; description: to check whether the mark is contained in the definition
    ;(printout t "contains: " ?mark ":" ?definition crlf)
    (if (neq (str-index ?mark ?definition) FALSE) then
        (return TRUE)
    )
    (return FALSE)
)

(deffunction channelDefinition_definition (?quantitativeDefinition ?mark ?entityType ?entity ?definition)
    ; input: a string of original quantitativeDefinition, a string mark, a string of entityType, a string of entity, a new definition to replace the mark in quantitativeDefinition
    ; output: a string for new quantitativeDefinition
    ; description: the mark indicates the occurance of original metric in quantitativeDefinition of the query fact, this original metric needs to be replaced by the new difinition
    
    ; the mark could be from ontology (in format "metricName"), or from customization (in format "metricName@entityType"), or from other advanced metric
    (bind ?string ?quantitativeDefinition)
    (bind ?delimeter ",")
    (bind ?ind (str-index ?mark ?string)) ; index of mark location
    (while (neq ?ind FALSE)
        (if (eq ?ind 1) then
            (bind ?before "")
         else 
            (bind ?before (sub-string 1 (- ?ind 1) ?string)) ;get the substring before mark
        )
        
        (bind ?after (sub-string (+ ?ind (str-length ?mark)) (str-length ?string) ?string)) ; get the substring after mark
        
        (bind ?loc (str-index ?delimeter ?after)) ;get the end of metric that contains the mark
        (bind ?post "") ;the postfix for the mark to form an advanced metric
        (if (neq ?loc FALSE) then ;not the end of the string
            (bind ?post (sub-string 1 (- ?loc 1) ?after))
            (bind ?after (sub-string ?loc (str-length ?after) ?after))
         else
            (bind ?post ?after)
            (bind ?after "")
        )
        (bind ?string (str-cat ?before (formDefinition ?definition ?entityType ?entity ?post) ?after))        
        (bind ?ind (str-index ?mark ?string))
        ;(printout t "Channel definition: " ?string crlf)
    )
    (return ?string)
)

(deffunction channelDefinition_hasMetric (?quantitativeDefinition ?mark ?entityType ?entity $?list)
    ; input: a string of original quantitativeDefinition, a string mark, a string of entityType, a string of entity, a list of metrics to replace the mark in quantitativeDefinition
    ; output: a string for new quantitativeDefinition
    ; description: the mark indicates the occurance of original metric in quantitativeDefinition of the query fact, this original metric needs to be replaced by the content in the list
    
    ; the mark could be from ontology (in format "metricName"), or from customization (in format "metricName@entityType"), or from other advanced metric
    (bind ?string ?quantitativeDefinition)
    (bind ?delimeter ",")
           
    (bind ?ind (str-index ?mark ?string)) ; index of mark location    
    (while (neq ?ind FALSE)
        (if (eq ?ind 1) then
            (bind ?before "")
         else 
            (bind ?before (sub-string 1 (- ?ind 1) ?string)) ;get the substring before mark
        )
        
        (bind ?after (sub-string (+ ?ind (str-length ?mark)) (str-length ?string) ?string)) ; get the substring after mark
        
        (bind ?loc (str-index ?delimeter ?after)) ;get the end of metric that contains the mark
        (bind ?post "") ;the postfix for the mark to form an advanced metric
        (if (neq ?loc FALSE) then ;not the end of the string
            (bind ?post (sub-string 1 (- ?loc 1) ?after))
            (bind ?after (sub-string ?loc (str-length ?after) ?after))
         else
            (bind ?post ?after)
            (bind ?after "")
        )
        
        (bind ?string ?before)
        (foreach ?x $?list
            (bind ?string (str-cat ?string (formDefinition ?x ?entityType ?entity ?post) ?delimeter))
        )
        (bind ?string (str-cat ?string "AVG" ?after))        
        (bind ?ind (str-index ?mark ?string))
        
    ) ; end while
    ;(printout t "Channel definition: " ?string crlf)
    (return ?string) 
)

(deffunction channelDefinition_pool (?quantitativeDefinition ?mark ?entityType ?entity $?list)
    ; input: a string of original quantitativeDefinition, a string mark, a string of entityType, a string of entity, a list of metrics to replace the mark in quantitativeDefinition
    ; output: a list of strings for new quantitativeDefinition
    ; description: the mark indicates the occurance of original metric in quantitativeDefinition of the query fact, this original metric needs to be replaced by the content in the list
    
    ; the mark could be from ontology (in format "metricName"), or from customization (in format "metricName@entityType"), or from other advanced metric
    
    (bind $?result (create$))
    (bind ?delimeter ",")
    
    (foreach ?x ?list
        
    (bind ?string ?quantitativeDefinition)
    (bind ?ind (str-index ?mark ?string)) ; index of mark location
    (while (neq ?ind FALSE)
        (if (eq ?ind 1) then
            (bind ?before "")
         else 
            (bind ?before (sub-string 1 (- ?ind 1) ?string)) ;get the substring before mark
        )
        
        (bind ?after (sub-string (+ ?ind (str-length ?mark)) (str-length ?string) ?string)) ; get the substring after mark
        
        (bind ?loc (str-index ?delimeter ?after)) ;get the end of metric that contains the mark
        (bind ?post "") ;the postfix for the mark to form an advanced metric
        (if (neq ?loc FALSE) then ;not then end of the string
            (bind ?post (sub-string 1 (- ?loc 1) ?after))
            (bind ?after (sub-string ?loc (str-length ?after) ?after))
         else
            (bind ?post ?after)
            (bind ?after "")
        )
        (bind ?string (str-cat ?before (formDefinition ?x ?entityType ?entity ?post) ?after))        
        (bind ?ind (str-index ?mark ?string))
        
    ); end while
      ;(printout t "Channel definition by pool: " ?string "::" ?x crlf)
      (bind $?result (union$ $?result (create$ ?string)))  
    )
    (return $?result) 
)


(deffunction channelDefinition_entity (?quantitativeDefinition ?mark ?entityType ?entity $?list)
    ; input: a string of original quantitativeDefinition, a string mark, a string of entityType, a string of entity, a list of cloud entities to replace the mark in quantitativeDefinition
    ; output: a string for new quantitativeDefinition
    ; description: the mark indicates the occurance of original metric in quantitativeDefinition of the query fact, this original metric needs to be replaced by the content in the list
    
    ; the mark could be from ontology (in format "metricName"), or from customization (in format "metricName@entityType"), or from other advanced metric
    (bind ?string ?quantitativeDefinition)
    (if (eq (str-compare ?entityType "DataCenter") 0) then
        (bind ?newType "Cluster")
     else 
        (if (eq (str-compare ?entityType "Cluster") 0) then
            (bind ?newType "Host")
         else
            (bind ?newType "VM")
        )
    )
    (bind ?delimeter ",")
    (bind ?ind (str-index ?mark ?string)) ; index of mark location
    (while (neq ?ind FALSE)
        (if (eq ?ind 1) then
            (bind ?before "")
         else 
            (bind ?before (sub-string 1 (- ?ind 1) ?string)) ;get the substring before mark
        )
        
        (bind ?s (new String ?before))
        (bind ?loc (?s lastIndexOf ",")) ;get the start of metric that contains the mark
        (bind ?pre "") ; the prefix for the mark to form an advanced metric, "@" will be included
        ;(printout t "debug before: " ?quantitativeDefinition  " : " ?string " : " ?before " : " ?pre crlf)
        (if (neq ?loc -1) then             
            (bind ?pre (sub-string (+ ?loc 2) (+ (str-index ?entityType (sub-string (+ ?loc 2) (str-length ?before) ?before)) ?loc) ?before))
            (bind ?before (sub-string 1 (+ ?loc 1) ?before))
         else
            (bind ?pre (sub-string 1 (- (str-index ?entityType ?before) 1) ?before))
            (bind ?before "")
        )
        
        (if (> (+ ?ind (str-length ?mark)) (str-length ?string)) then
            (bind ?after "")
         else
            (bind ?after (sub-string (+ ?ind (str-length ?mark)) (str-length ?string) ?string)) ; get the substring after mark
        )        
        
        
        (bind ?loc (str-index ?delimeter ?after)) ;get the end of metric that contains the mark
        (bind ?post "") ;the postfix for the mark to form an advanced metric
        ;(printout t "debug after: " ?string " : " ?before " : " ?pre " : " ?post " : "  ?after crlf)
        (if (neq ?loc FALSE) then ;not the end of the string            
            (if (neq ?loc 1) then
                (bind ?post (sub-string 1 (- ?loc 1) ?after))
            	(bind ?after (sub-string ?loc (str-length ?after) ?after))
             else
                (bind ?post "")
                ;(bind ?after "")
            )
         else
            (bind ?post ?after)
            (bind ?after "")
        )
        
        ;(printout t "debug: " ?quantitativeDefinition  " : "  ?string " : " ?before " : " ?pre " : " ?post " : "  ?after crlf)
        (bind ?string ?before)
        (foreach ?x $?list
            (bind ?string (str-cat ?string ?pre ?newType "@" (formDefinition ?x "" ?entity ?post) ?delimeter))    
        )
        (bind ?string (str-cat ?string "AVG" ?after))
            
        (bind ?ind (str-index ?mark ?string))
        
    )
    ;(printout t "Channel definition by entity: " ?string crlf)
    (return ?string)
     
)

(deffunction getCounter (?string)
    ; input: a string of quantitativeDefinition
    ; output: if a counter exists, then return the counter metric string, else return empty string
    ; description: extract the counter metric string if exists
    (bind ?i (str-index "#" ?string))
    (if (eq ?i FALSE) then
        (return "")
    )
    (bind ?j (str-index "," (sub-string ?i (str-length ?string) ?string)))
    (if (eq ?j FALSE) then
        (bind ?j (+ (str-length ?string) 1))
     else 
        (bind ?j (+ ?j ?i -1))
    )
    ;(printout t "Debug: i-" ?i " j-" ?j " len-" (str-length ?string) crlf )
    (bind ?result (sub-string ?i (- ?j 1) ?string))
    ;(printout t "Extracted counter: " ?result crlf)
    (return ?result)
    ;(return (sub-string ?i (- ?j 1) ?string))
)

(deffunction channelDefinition_counter (?definition ?len)
    ; input: a string of original quantitativeDefinition, an integer of the length of the component 
    ; output: a string for new quantitativeDefinition
    ; description: a counter in the definition needs to be replaced by the len
    (bind ?i (str-index "#" ?definition))
    (if (eq ?i 1) then
        (bind ?before "")
     else
        (bind ?before (sub-string 1 (- ?i 1) ?definition))
    )
    
    (bind ?j (str-index "," (sub-string ?i (str-length ?definition) ?definition)))
    (if (eq ?j FALSE) then
        (bind ?after "")
     else
        (bind ?j (+ ?j ?i -1))
        (bind ?after (sub-string ?j (str-length ?definition) ?definition))
    )
    
    (bind ?result (str-cat ?before ?len ?after))
    ;(printout t "Replaced counter: " ?result crlf)
    (return ?result)
    ;(return (str-cat ?before ?len ?after))
)


(deffunction modifyQuantitativeDefinition (?definition ?mark ?replace)
    ; input: a string of quantitativeDefinition, a string of matched mark, a string to replace mark
    ; output: a string of new quantitativeDefinition
    ; description: when matching with meta data, the matched meta should be updated in the query fact
    ; generate output in format of metricName::DSName::CF
    
    ; there could be multiple occurance within quantitativeDefinition

    (bind ?i (str-index ?mark ?definition)) ; find the location of the mark in the definition
    
    (bind ?rest ?definition)
    (bind ?result "")
    
    (while (neq ?i FALSE)
        ; find the string before the mark
        (if (neq ?i 1) then
            (bind ?before (sub-string 1 (- ?i 1) ?rest))
         else
            (bind ?before "")
        )
        
        ; find the string after the mark
        (if (> (+ ?i (str-length ?mark)) (str-length ?rest)) then
            (bind ?rest "")
         else
            (bind ?rest (sub-string (+ ?i (str-length ?mark)) (str-length ?rest) ?rest))
        )
        
        ; replace the mark
        (bind ?result (str-cat ?result ?before ?replace))    
        
        (bind ?i (str-index ?mark ?rest))
    ) 
    (bind ?result (str-cat ?result ?rest))
    ;(printout t "Modified definition: " ?definition " : "?result crlf)
    (return ?result)
)

(deffunction matchInHelpList (?metric ?type ?entity $?list)
    (if (member$ (str-cat ?metric "@" ?type "@" ?entity) $?list) then
        ;(printout t "Matched in helpList: " (str-cat ?metric "@" ?type "@" ?entity) $?list crlf)
        (return TRUE)
    )
    ;(printout t "No match in helpList: " (str-cat ?metric "@" ?type "@" ?entity) $?list crlf)
    (return FALSE)
)

;----------------- rule section  -------------------

; 0. ########## process path #########
(bind ?*path* ((new Config) getPath))
;(printout t "Prepath:" ?*path* crlf)
(bind ?*ontologyFile* (str-cat ?*path* ?*ontologyFile*))
(bind ?*queryFile* (str-cat ?*path* ?*queryFile*))
(bind ?*archiveFile* (str-cat ?*path* ?*archiveFile*))
(bind ?*simulatedFile* (str-cat ?*path* ?*simulatedFile*))
(bind ?*customizationFile* (str-cat ?*path* ?*customizationFile*))
(bind ?*outputFile* (str-cat ?*path* ?*outputFile*))
(bind ?*metaFile* (str-cat ?*path* ?*metaFile*))
(bind ?*cloudFile* (str-cat ?*path* ?*cloudFile*))

; 1. ########## check cached result #########
(defrule checkArchive
    ; check whether the query is already in the archive
    (declare (salience 999))
    ?q <- (query (metricName ?metric)  (unitName ?unit) (entityType ?entityType) (entity ?entity))
    ?a <- (archive (metricName ?metric1&:(eq (str-compare ?metric ?metric1) 0)) (unitName ?unit1) (entityType ?entityType1&:(eq (str-compare ?entityType1 ?entityType) 0)) (entity ?entity1&:(eq (str-compare ?entity1 ?entity) 0)))
    ;?a <- (archive (metricName ?metric1&:(eq (str-compare ?metric ?metric1) 0)))
    =>
    ; directly matched in archive, and output
    ;(printout t "From archived meta: " ?a.quantitativeDefinition crlf)
    (assert
        (parsed
            (metricName ?a.metricName)
            (unitName ?a.unitName)
            (unit ?a.unit)
            (entityType ?a.entityType)
            (entity ?a.entity)
            (quantitativeDefinition ?a.quantitativeDefinition)
            (DSName ?q.DSName)
            (CF ?q.CF)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
            (archive 1)
        )
    )  
    (retract ?q)  
)

(defrule checkMeta
    ; check whether the query is already in the meta
    ; TODO
    (declare (salience 998))
    ?q <- (query (metricName ?metric)  (unitName ?unit) (entityType ?entityType) (entity ?entity))
    ?m <- (meta (metricName ?metric1&:(eq (str-compare ?metric ?metric1) 0)) (unitName ?unit1) (entityType ?entityType1&:(eq (str-compare ?entityType1 ?entityType) 0)) (entity ?entity1&:(eq (str-compare ?entity1 ?entity) 0)))
    =>
     ; directly matched in model, and output
    (assert
        (parsed
            (metricName ?m.metricName)
            (unitName ?m.unitName)
            (unit ?m.unit)
            (entityType ?m.entityType)
            (entity ?m.entity)
            (quantitativeDefinition (str-cat ?m.handle "::" ?m.DSName "::" ?m.CF))
            (DSName ?q.DSName)
            (CF ?q.CF)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
            ;(archive 1)
        )
    ) 
    (retract ?q)
)

(defrule outputParsed
    ; if any queried metric is cached, then output
    (declare (salience 998))
    ?p <- (parsed)
    =>
    (open ?*outputFile* id w)
    (printout id "metricName: " ?p.metricName crlf)
    (printout id  "unitName: " ?p.unitName crlf)
    (printout id  "unit: " ?p.unit crlf)
    (printout id  "entityType: " ?p.entityType crlf)
    (printout id  "entity: " ?p.entity crlf)
    (printout id  "quantitativeDefinition: " ?p.quantitativeDefinition crlf)
    (printout id "DSName: " ?p.DSName crlf)
    (printout id "CF: " ?p.CF crlf)
    (printout id "startTime: " ?p.startTime crlf)
    (printout id "endTime: " ?p.endTime crlf)
    (printout id "rows: " ?p.rows crlf)
    (printout id "step: " ?p.step crlf crlf)
    (close id)
    )

;
(defrule preprocess
    (declare (salience 988)) ;convert metrics into advanced mode in quantitativeDefinition
    ?q <- (query (quantitativeDefinition ?quantitativeDefinition&:(eq ?quantitativeDefinition nil)))
    =>
    ;(printout t "Preprocess advanced: " (convert2Adv ?q.metricName ?q.entityType ?q.entity) crlf)
    (modify ?q
        (quantitativeDefinition (convert2Adv ?q.metricName ?q.entityType ?q.entity))
    )
)

(defrule preprocess_help
    (declare (salience 988)) ;add metrics in quantitativeDefinition into helpList
    ?q <- (query (quantitativeDefinition ?quantitativeDefinition&:(neq ?quantitativeDefinition nil)))
    =>
    ;(printout t "Preprocess: " ?quantitativeDefinition crlf)
    (modify ?q
        (helpList (definition2List ?q))
    )
)


; 2. ######### channel metric by customization ############# 
(defrule channelByCustomization_definition
    ; link through custormization, mainly by definition in customization
    ; has the highest priority during reasoning
    (declare (salience 899))
    ?q <- (query (metricName ?metricName) (entityType ?entityType) (entity ?entity) (quantitativeDefinition ?quantitativeDefinition) (matchedList $?matchedList))
    ;?m <- (model (metricName ?metricName2&:(eq ?metricName ?metricName2)) (entityType ?entityType2&:(eq ?entityType2 ?entityType)) (quantitativeDefinition ?quantitativeDefinition2&:(and (neq ?quantitativeDefinition2 nil) (neq ?quantitativeDefinition2 ?quantitativeDefinition))))
    ?m <- (model (metricName ?metricName2&:(eq (str-compare ?metricName ?metricName2) 0)) (entityType ?entityType2&:(containsInDefinition (str-cat ?metricName2 "@" ?entityType2) ?quantitativeDefinition)) (quantitativeDefinition ?quantitativeDefinition2&:(neq ?quantitativeDefinition2 nil) ))
    =>
    ;(printout t "customization defintion: " ?metricName2 " : " ?entityType2 " : " ?quantitativeDefinition2 crlf)
    (assert
        (query
            (metricName ?metricName)
            (quantitativeDefinition (channelDefinition_definition ?quantitativeDefinition (str-cat ?metricName2 "@" ?entityType2) ?entityType "" ?quantitativeDefinition2))
            ;(helpList (definition2List ?q))
            (matchedList $?matchedList)
            (unitName ?q.unitName)
            (unit ?q.unit)
            (entityType ?entityType)
            (entity ?q.entity)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
            (DSName ?q.DSName)
            (CF ?q.CF)
        )
    )
)


(defrule channelByCustomization_metric
    ; link through custormization, mainly by definition in customization
    ; has the highest priority during reasoning
    (declare (salience 899))
    ?q <- (query (metricName ?metricName) (entityType ?entityType) (entity ?entity) (quantitativeDefinition ?quantitativeDefinition) (matchedList $?matchedList))
    ?m <- (model (metricName ?metricName2) (entityType ?entityType2&:(containsInDefinition (str-cat ?metricName2 "@" ?entityType2) ?quantitativeDefinition)) (hasMetric $?hasMetric2&:(neq (length$ $?hasMetric2) 0)))
    =>
    ; by default, the queried result is the average of the metrics linked by hasMetric
    ;(printout t "customization hasMetric: " ?metricName2 " : " ?entityType2 " : " $?hasMetric2 crlf)
    (assert
        (query
            (metricName ?metricName)
            (quantitativeDefinition (channelDefinition_hasMetric ?quantitativeDefinition (str-cat ?metricName2 "@" ?entityType2) ?entityType "" $?hasMetric2))
            ;(helpList $?hasMetric2)
            (matchedList $?matchedList)
            (unitName ?q.unitName)
            (unit ?q.unit)
            (entityType ?entityType)
            (entity ?q.entity)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
            (DSName ?q.DSName)
            (CF ?q.CF)
        )
    )
)

(defrule channelByCustomization_pool
    ; link through custormization, mainly by definition in customization
    ; has the highest priority during reasoning
    ; shouldn't be fired when this metric is customized
    (declare (salience 899))
    ?q <- (query (metricName ?metricName) (entityType ?entityType) (entity ?entity) (quantitativeDefinition ?quantitativeDefinition) (matchedList $?matchedList))
    ?m <- (model (metricName ?metricName2) (entityType ?entityType2&:(containsInDefinition (str-cat ?metricName2 "@" ?entityType2) ?quantitativeDefinition)) (conceptPool $?conceptPool&:(neq (length$ $?conceptPool) 0)))
    =>
    ;(printout t "Channel customization pool: " $?conceptPool "::" (channelDefinition_pool ?quantitativeDefinition (str-cat ?metricName2 "@" ?entityType2) ?entityType "" $?conceptPool) crlf)
    (bind $?newDefinition (channelDefinition_pool ?quantitativeDefinition (str-cat ?metricName2 "@" ?entityType2) ?entityType "" $?conceptPool))
    (foreach ?x $?newDefinition
        (assert
        	(query
            	(metricName ?metricName)
            	(quantitativeDefinition ?x)
            	;(helpList $?hasMetric2)
            	(matchedList $?matchedList)
            	(unitName ?q.unitName)
            	(unit ?q.unit)
            	(entityType ?entityType)
            	(entity ?q.entity)
            	(startTime ?q.startTime)
            	(endTime ?q.endTime)
            	(rows ?q.rows)
            	(step ?q.step)
                (DSName ?q.DSName)
            	(CF ?q.CF)
        	)
    	)
        ;(printout t "Channel customization pool: " ?x crlf)
    )
)

(defrule channelByConceptPool
    ; link through concept pool: replace the concept
    ; shouldn't be fired when this metric is customized
    (declare (salience 889))
    ?l <- (accumulate (bind $?list (create$))
        (bind $?list (union$ $?list (create$ (str-cat ?metric "::" ?entity))))
        $?list
        (model (metricName ?metric) (entityType ?entity))
        )
        
    ?q <- (query (metricName ?metricName) (matchedList $?matchedList) (quantitativeDefinition ?quantitativeDefinition) (entity ?entity) (entityType ?entityType&:(not (member$ (str-cat ?metricName "::" ?entityType) ?l)))) ; this channel should not be customized
    ?commentTriple <- (triple (subject ?subject1&:(containsInDefinition ?subject1 ?quantitativeDefinition)) (predicate ?predicate1&:(eq (str-compare ?predicate1 ?*conceptPool*) 0)) (object ?object1))
    =>
    (assert
        (query
            (metricName ?metricName)
            (quantitativeDefinition (channelDefinition_pool ?quantitativeDefinition ?subject1 "" "" ?object1))
            ;(helpList (definition2List ?q))
            (matchedList $?matchedList)
            (unitName ?q.unitName)
            (unit ?q.unit)
            (entityType ?entityType)
            (entity ?q.entity)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
            (DSName ?q.DSName)
            (CF ?q.CF)
        )
    )
)

; 3. ######## channel metric by ontology ##########
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
        
    ?q <- (query (metricName ?metricName) (matchedList $?matchedList) (quantitativeDefinition ?quantitativeDefinition) (entity ?entity) (entityType ?entityType&:(not (member$ (str-cat ?metricName "::" ?entityType) ?l)))) ; this channel should not be customized
    
    ?attr_restr <- (triple (subject ?subject1&:(containsInDefinition ?subject1 ?quantitativeDefinition)) (predicate ?predicate1&:(eq (str-compare ?predicate1 ?*subClassOf*) 0)) (object ?object1))
    ?Restr <- (triple (subject ?subject2&:(eq (str-compare ?subject2 ?object1) 0)) (predicate ?predicate2&:(eq (str-compare ?predicate2 ?*type*) 0)) (object ?object2&:(eq (str-compare ?object2 ?*Restriction*) 0))  )
    ?property <- (triple (subject ?subject3&:(eq (str-compare ?subject3 ?subject2) 0)) (predicate ?predicate3&:(eq (str-compare ?predicate3 ?*onProperty*) 0)) (object ?object3&:(eq (str-compare ?object3 "hasMetric") 0)))
    
    ?m <- (accumulate (bind $?list (create$))
        (bind $? (union$ $?list (create$ ?object4)))
        $?list
        (triple (subject ?subject4&:(eq (str-compare ?subject4 ?subject3) 0)) (predicate ?predicate4&:(member$ ?predicate4 (create$ ?*someValuesFrom* ?*onClass* ?*allValuesFrom*))) (object ?object4))
        )
    
    =>
    ; by default, the queried result is the average of the metrics linked by hasMetric
    (assert
        (query
            (metricName ?metricName)
            (quantitativeDefinition (channelDefinition_hasMetric ?quantitativeDefinition ?subject1 "" "" $?hasMetric2))
            ;(helpList $?hasMetric2)
            (matchedList $?matchedList)
            (unitName ?q.unitName)
            (unit ?q.unit)
            (entityType ?entityType)
            (entity ?q.entity)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
            (DSName ?q.DSName)
            (CF ?q.CF)
        )
    )
)


(defrule channelByComment
    ; link l quantitative definition in ontology by comment: e.g. avalaibility to uptime and downtime
    ; shouldn't be fired when this metric is customized
    (declare (salience 889))
    ;; TODO: modify the first accumulate statement: how to avoid "nested query"?
    ?l <- (accumulate (bind $?list (create$))
        (bind $?list (union$ $?list (create$ (str-cat ?metric "::" ?entity))))
        $?list
        (model (metricName ?metric) (entityType ?entity))
        )
        
    ?q <- (query (metricName ?metricName) (quantitativeDefinition ?quantitativeDefinition) (matchedList $?matchedList) (entity ?entity)(entityType ?entityType&:(not (member$ (str-cat ?metricName "::" ?entityType) ?l)))) ; this channel should not be customized
    
    ;?q <- (query (metricName ?metricName) (quantitativeDefinition ?quantitativeDefinition)(entityType ?entityType) (entity ?entity))
    ?commentTriple <- (triple (subject ?subject1&:(containsInDefinition ?subject1 ?quantitativeDefinition)) (predicate ?predicate1&:(eq (str-compare ?predicate1 ?*quantitativeDefinition*) 0)) (object ?object1))
    ;?node <- (treeNode (attributeName ?attributeName3&:(eq ?attributeName ?attributeName3)) (formula $?formula))
    =>
    ;(printout t "channelByComment: " ?object1 crlf)
    (assert
        (query
            (metricName ?metricName)
            (quantitativeDefinition (channelDefinition_definition ?quantitativeDefinition ?subject1 "" "" ?object1))
            ;(helpList (definition2List ?q))
            (matchedList $?matchedList)
            (unitName ?q.unitName)
            (unit ?q.unit)
            (entityType ?entityType)
            (entity ?q.entity)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
            (DSName ?q.DSName)
            (CF ?q.CF)
        )
    )    
)

(defrule channelByEntity
    ; link through cloud entity, where only limited entity can be extended by restriction of specific metric
    (declare (salience 889))
    ?q <- (query (metricName ?metricName) (quantitativeDefinition ?quantitativeDefinition) (entityType ?entityType) (entity ?entity) (matchedList $?matchedList))
    ;?c <- (cloudEntity (entityType ?entityType2) (entity ?entity2&:(containsInDefinition ?entity2 ?quantitativeDefinition)) (composition ?composition))
    ?c <- (cloudEntity (entityType ?entityType2) (entity ?entity2&:(containsInDefinition ?entity2 ?quantitativeDefinition)) (component $?component))
    =>
    ;(printout t "Channel by entity: " crlf)
    (assert
        (query
            (metricName ?metricName)
            (quantitativeDefinition (channelDefinition_entity ?quantitativeDefinition ?entity2 ?entityType2 "" $?component))
            ;(helpList (entity2List ?q ?c))
            (matchedList $?matchedList)
            (unitName ?q.unitName)
            (unit ?q.unit)
            (entityType ?entityType)
            (entity ?q.entity)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
            (DSName ?q.DSName)
            (CF ?q.CF)
        )
    )
)

(defrule channelByCounter
    ; link through "#"
    ; directly find the counter, if possible
    (declare (salience 899))
    ;; TODO
    ?q <-(query (metricName ?metricName) (entityType ?entityType) (entity ?entity) (quantitativeDefinition ?quantitativeDefinition&:(eq (regexp ".*#(DataCenter|Cluster|Host|VM)@(DataCenter|Cluster|Host|VM).*" ?quantitativeDefinition) TRUE))) ; contains counter
    ?e1 <- (cloudEntity (entityType ?entityType2&:(containsInDefinition ?entityType2 (getCounter ?quantitativeDefinition))) (entity ?entity2) (componentType ?componentType2&:(containsInDefinition ?componentType2 (getCounter ?quantitativeDefinition))) (component $?component2))
    =>
    ;(printout t "Counter found directly: " (getCounter ?quantitativeDefinition) crlf)
    (modify ?q
        (quantitativeDefinition (channelDefinition_counter ?quantitativeDefinition (length$ $?component2)))   
    )
)

(defrule channelByCounter_deep
    ; link through "#"
    ; should be linked through multiple cloudEntity facts
    ;; TODO
    (declare (salience 899))
    ?q <-(query (metricName ?metricName) (entityType ?entityType) (entity ?entity) (quantitativeDefinition ?quantitativeDefinition&:(eq (regexp ".*#(DataCenter|Cluster|Host|VM)@(DataCenter|Cluster|Host|VM).*" ?quantitativeDefinition) TRUE))) ; contains counter
    ?e <- (cloudEntity (entityType ?entityType2&:(containsInDefinition ?entityType2 (getCounter ?quantitativeDefinition))) (entity ?entity2&:(eq (str-compare ?entity ?entity2) 0)) (componentType ?componentType2&:(not (containsInDefinition ?componentType2 (getCounter ?quantitativeDefinition)))) (component $?component2))
    ?m <- (accumulate (bind $?result (create$))
        (bind $?result (union$ $?result ?component3))
        $?result
        (cloudEntity (entityType ?entityType3) (entity ?entity3&:(member$ ?entity3 $?component2)) (componentType ?componentType3) (component $?component3))
        )
    ?c <- (cloudEntity (entityType ?entityType4) (entity ?entity4) (componentType ?componentType4) (component $?component4&:(neq (length$ (intersection$ $?component4 ?m)) 0)))
    ;?e2 <- (cloudEntity (entityType ?entityType2) (entity ?entity2) (componentType ?componentType2) (component ?component2))
    =>
    ;(printout t "Channel counter deeply: " ?quantitativeDefinition "::" ?entity "::" ?entity2 "::" ?m crlf)
    (if (containsInDefinition ?componentType4 (getCounter ?quantitativeDefinition)) then ; matched
        (modify ?q
        	(quantitativeDefinition (channelDefinition_counter ?quantitativeDefinition (length$ ?m)))   
    	)
     else
        (assert
            (cloudEntity
                (entityType ?entityType)
                (entity ?entity)
                (componentType ?componentType4)
                (component ?m)
            )
        )
    )
)

; 4. ########## prepare output ###########
(defrule checkOutput
    ; for all the metrics, check whether metadata exists for each metric in definition
    ; match by advanced metric
    (declare (salience 899)) ; high priority for early detection
    
    ;?m <- (meta (metricName ?metricName2) (entityType ?entityType2&:(member$ (str-cat ?metricName2 "@" ?entityType2) $?helpList)) (entity ?entity2&:(eq ?entity ?entity2)) (startTime ?startTime2&:(and (> ?startTime2 ?startTime) (< ?startTime2 ?endTime))) (endTime ?endTime2&:(< ?endTime2 ?endTime)))  
    ?m <- (meta (metricName ?metricName2) (handle ?handle2) (DSName ?DSName2) (CF ?CF2) (entity ?entity2) (entityType ?entityType2) )
    ?q <- (query (metricName ?metricName) (quantitativeDefinition ?quantitativeDefinition) (matchedList $?matchedList) (helpList $?helpList&:(eq (matchInHelpList ?metricName2 ?entityType2 ?entity2 $?helpList) TRUE)) (unitName ?unitName) (unit ?unit) (entityType ?entityType) (entity ?entity) (startTime ?startTime) (endTime ?endTime) (rows ?rows) (step ?step))

    =>    
    (modify ?q
        (quantitativeDefinition (modifyQuantitativeDefinition ?quantitativeDefinition (str-cat ?metricName2 "@" ?entityType2 "@" ?entity2) (str-cat ?handle2 "::" ?DSName2 "::" ?CF2) ))
        (matchedList (union$ $?matchedList (create$ (str-cat ?metricName2 "@" ?entityType2 "@" ?entity2))))
    )
    /*(if (containsInDefinition "Size" ?quantitativeDefinition) then
        (printout t "Size found: " ?quantitativeDefinition crlf)
        (printout t "Updated query: " ?q.quantitativeDefinition "::" ?q.matchedList crlf)
    )*/
    ;(printout t "Matched metas: " ?e.helpList " :: " ?e.matchedList crlf)
    ;(bind $?match  ?helpList)
    ;(printout t "Test bind: " $?match crlf) 
)

(defrule generateOutput
    ; check whether a full match exist: for all the metrics, the metadata exists for each metric
    ; match advanced metric, i.e. metricName@entity, in helpList
    (declare (salience 899))
    ?q <- (query (metricName ?metricName) (quantitativeDefinition ?quantitativeDefinition) (matchedList $?matchedList) (helpList $?helpList&:(eq (length$ $?matchedList) (length$ $?helpList))) (unitName ?unitName) (unit ?unit) (entityType ?entityType) (entity ?entity) (startTime ?startTime) (endTime ?endTime) (rows ?rows) (step ?step))
    ;?m <- (meta (metricName ?metricName2) (entityType ?entityType2&:(member$ (str-cat ?metricName2 "@" ?entityType2) $?helpList))  (startTime ?startTime2&:(and (> ?startTime2 ?startTime) (< ?startTime2 ?endTime))) (endTime ?endTime2&:(< ?endTime2 ?endTime)))
    =>
    /*(modify ?e
        (quantitativeDefinition (modifyQuantitativeDefinition ?e ?m 2))
    )*/
    (printout t "Fully matched query: " ?q.metricName " : " ?q.entityType " : " ?q.unit " : " ?q.helpList "  : " ?q.matchedList "  : " ?q.quantitativeDefinition crlf)
    (assert
        (parsed
            (metricName ?metricName)
            (unitName ?unitName)
            (entityType ?entityType)
            (entity ?entity)
            (quantitativeDefinition ?quantitativeDefinition)
            (DSName ?q.DSName)
            (CF ?q.CF)
            (startTime ?q.startTime)
            (endTime ?q.endTime)
            (rows ?q.rows)
            (step ?q.step)
            (unit ?q.unit)
        )
    ) 
)

(defrule generateArchive
    ; generate facts for archive to be output
    (declare (salience 879))
    ?a <- (parsed (archive ?archive&:(neq ?archive 1))) 
    =>
    ;(printout t "Non-archive parsed: " ?a.quantitativeDefinition crlf)
    (open ?*archiveFile* id a)
    
    ;(printout id "metricName: " ?p.metricName crlf "unitName: " ?p.unitName crlf "entityType: " ?p.entityType crlf "quantitativeDefinition" ?p.quantitativeDefinition crlf crlf)
    (printout id "(assert" crlf)
    (printout id "    (archive" crlf)
    (printout id "        (metricName " ?a.metricName ")" crlf)
    (printout id "        (unitName " ?a.unitName ")" crlf)
    (printout id "        (unit " ?a.unit ")" crlf)
    (printout id "        (entityType " ?a.entityType ")" crlf)
    (printout id "        (entity " ?a.entity ")" crlf)
    (printout id "        (quantitativeDefinition " ?a.quantitativeDefinition ")" crlf)
    (printout id "        (DSName " ?a.DSName ")" crlf)
    (printout id "        (CF " ?a.CF ")" crlf)
    (printout id "        (startTime " ?a.startTime ")" crlf)
    (printout id "        (endTime " ?a.endTime ")" crlf)
    (printout id "        (rows " ?a.rows ")" crlf)
    (printout id "        (step " ?a.step ")" crlf)
    (printout id "    )" crlf)
    (printout id ")" crlf crlf)
    (close id)
    
)

;------ test rule------

(defrule testQuery
    ?q <- (query) 
    =>
    ;(printout t "Query: " ?q.metricName " : " ?q.entityType " : " ?q.entity " : " ?q.helpList "  : " ?q.matchedList "  : " ?q.quantitativeDefinition crlf)
    ;(printout t ((new Config) getPath) crlf)
)

(defrule matchedQuery
    ?q <- (query (matchedList $?matchedList) (helpList $?helpList&:(> (length$ $?matchedList) 3))) 
    =>
    ;(printout t "Good matched query: " ?q.metricName " : " ?q.entityType " : " ?q.entity " : " ?q.helpList "  : " ?q.matchedList "  : " ?q.quantitativeDefinition crlf)
    ;(printout t ((new Config) getPath) crlf)
)

(defrule loadEntity
    ?e <- (cloudEntity)
    =>
    ;(printout t "Entity: " ?e.entity " : " ?e.component crlf)
)

(defrule loadArchive
    ?a <- (archive)
    =>
    ;(printout t "Archive: " ?a.quantitativeDefinition crlf)
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
