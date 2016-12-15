(reset)
(import reasoning.*)
(open reasoning/out/output.txt id w)

;;prefix:fixed
;;coefficient:fixed
;;repeat sensorName:fixed
;;full coverage from sensors---minimum cost:fixing
;;cascade:fixed
;;expression for formula -- suffix expression: fixed


;;system information for compatibility test and data comversion
;;sensor/analyzer environment compatibility
;;benifit of reasoning: easy to 

;------------template section-------------------

(deftemplate triple 
    (slot predicate (default ""))
    (slot subject (default ""))
    (slot object (default ""))
    )

(deftemplate slaItem
    (slot name (type STRING))
    (slot measureType (default ""))
    (slot value (default ))
    (slot dataType (default ""))
    (slot unit (default ""))
    (slot requirementType (default ""))
    (slot OSname (default ""))
    )

(deftemplate sensors
    (slot name (type STRING))
    (multislot attribute)
    (slot inheritance )
    (slot purpose (default ""))
    (slot sensorId (type INTEGER))
    (slot storeLoc (default ""))
    (multislot OSname)	;TODO: string operation, making it a single slot
    (slot layer)	;TODO: same as the former one
    (multislot samplingRate (type FLOAT))
    (multislot rateUnit (type STRING))
    (multislot unit)	;data conversion
    (multislot valueThreshold)
    (slot cost) ;cost to activate this unit
    )


(deftemplate analyzers
    (slot name (type STRING) )
    (multislot attribute)
    (slot purpose (default ""))
    (slot analyzerId (type INTEGER) )
    (slot storeLoc (default ""))
    (multislot OSname)
    (slot layer)
    (multislot samplingRate (type FLOAT))
    (multislot rateUnit (type STRING))
    (multislot unit)
    (multislot valueThreashold)
    (slot cost)	;cost to activate this unit
    )

;(deftemplate connection
	;connection between analyzer and sensor
;    (slot analyzerId )
;    (slot sensorId )
;    )

(deftemplate Unit
    ;;for unit convertion
    (slot name (type STRING))
    (slot value (type float))
    )

(deftemplate entranceShift
    (slot value (type Integer) (default 0))
    ;; 0 for analyzer entrance
    ;; not 0 for sla entrance
    )

(deftemplate selectedAttribute 
    ;direct,calculated, triggered
    (slot attributeName (type STRING))
    (multislot helpList (type STRING)) ;initally it's the same as caculatedList, but after iterations, this should be empty at last
    ;grouped candidates
    ;format of each string: "name1@@vFlag1::name2@@vFlag2::name3@@vFlag3..."
    (multislot calculatedList (type Integer))
    
    (multislot triggeredList (type Integer))

    (multislot candidateSensor (type STRING))
    ;collect all candidates, remove repeated ones
    (slot unit)
    )

(deftemplate candidateIndex
    (slot index (type Integer))
    (multislot candidate (type STRING))
    ; old: format of each string: "attributeName1::attributeName2::..."  
    (multislot rest4match (type STRING))
    ; old:format of each string: "attributeName1::attributeName2::..."
    (slot formula (type STRING))
    ; '+','-','*','/','(',')'
    (multislot matchedSensor (type STRING))
    ; old: format of each string: "sensorName1::sensorName2::..."
    (multislot cost (type Integer) (default 0))
    )

(deftemplate candidateSensor
    (slot attributeName (type STRING))
    (multislot candidate (type STRING))
    (multislot sensorName (type STRING))
    (multislot formula (type STRING) )
    )

(deftemplate selectedSensor
    (slot attributeName (type STRING))
    (slot sensorName (type STRING))
    )

(deftemplate candidateAnalyzer
    (slot attributeName (type STRING))
    (slot analyzerName (type STRING))
    )

(deftemplate result_sla
    (slot attributeName (type STRING))
    (multislot formula (type STRING))
    (multislot sensorName (type STRING))
    (slot analyzerName (type STRING))
    (slot unit (type STRING))
    (slot coefficient (type FLOAT))
    )

(deftemplate result_analyzer
    (slot analyzerName (type STRING))
    (multislot attributeName (type STRING))
    (multislot formula (type STRING))
    (multislot sensorName (type STRING))
    (multislot unit (type STRING))
    (multislot coefficient (type FLOAT))
    )

(deftemplate result_analyzer2
    (slot analyzerName (type STRING))
    (multislot attributeName (type STRING))
    (multislot formula (type STRING))
    (multislot sensorName (type STRING))
    (multislot unit (type STRING))
    (multislot coefficient (type FLOAT))
    )

(deftemplate finalAttributeList
    (slot attributeName (type STRING))
    )


(deftemplate StringSpliter
    (declare (from-class StringSpliter))
    ;(include-variables TRUE))
    )

(deftemplate FormulaParser
    (declare (from-class OperateTriDouble))
    )

(deftemplate treeNode
    (slot attributeName (type String))
    (multislot formula (type String))
    ; multislot in format of : bcd+/
    )

;--------------------global variables-----------
;default value of ?*prefix*  , needs to be updated with new ontology
(defglobal ?*prefix* = "http://www.semanticweb.org/ontologies/2012/8/Ontology1348074741596.owl#")

(defglobal ?*subClassOf* = "http://www.w3.org/2000/01/rdf-schema#subClassOf")

(defglobal ?*Restriction* = "http://www.w3.org/2002/07/owl#Restriction")

(defglobal ?*type* = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type")

(defglobal ?*comment* = "http://www.w3.org/2000/01/rdf-schema#comment")

(defglobal ?*onProperty* = "http://www.w3.org/2002/07/owl#onProperty")

(defglobal ?*someValuesFrom* = "http://www.w3.org/2002/07/owl#someValuesFrom")

(defglobal ?*allValuesFrom* = "http://www.w3.org/2002/07/owl#allValuesFrom")

(defglobal ?*onClass* = "http://www.w3.org/2002/07/owl#onClass")

(defglobal ?*Performance* = (str-cat ?*prefix* "Performance"))

(defglobal ?*hasMetric* = (str-cat ?*prefix* "hasMetric"))

(defglobal ?*measures* = (str-cat ?*prefix* "measures"))

(defglobal ?*calculatedBy* = (str-cat ?*prefix* "calculatedBy"))

(defglobal ?*triggerBy* = (str-cat ?*prefix* "triggerBy"))

(defglobal ?*maxIteration* = 10)

(defglobal ?*groupIndex* = 1)

(defglobal ?*attributeNumber* = 0)

(defglobal ?*MINVALUE* = 10000)

;---------------predefined facts----------------
(assert 
    (entranceShift
        )
    )

;-----------------function section----------------

(deffunction addAttribute (?analyzer)
    ;;add attribute for analyzer, replica is not removed
    
    ;(printout t "adding attribute" crlf)
    (bind ?length1 (length$ ?analyzer.attribute))
    (bind ?length2 (length$ ?analyzer.unit))
    (if (neq ?length1 ?length2) then
        (printout t "Inconsistent analyzer." crlf)
        (return))
    (bind ?i ?length1)
    (while (> ?i 0) 
        (bind ?name (nth$ ?i ?analyzer.attribute))
        (bind ?unit (nth$ ?i ?analyzer.unit))
        (assert 
			(selectedAttribute
                (attributeName ?name)
                (helpList (create$ (str-cat ?name "@@FALSE")))
            	(calculatedList (create$ ?*groupIndex*))
                ;(unit ?unit)
                )
            )
        (assert 
        	(candidateIndex
            	(index ?*groupIndex*)
            	(candidate (create$ ?name))
            	(rest4match (create$ ?name))
            	)
        	)
    	(++ ?*groupIndex*)
        (++ ?*attributeNumber*)
        ;(printout t ?analyzer.name " : " ?name " : " ?unit crlf)
        (-- ?i)
    );while
)

(deffunction parseComment ($?list)
    ;; input is a list of attribute based on a parsed formula
    ;; output is a formated string: connect all the attributes with "::"
    
    (bind ?length (length$ $?list))
    (bind ?i ?length)
    (bind ?result "")
    (while (> ?i 1)
        (bind ?attribute (nth$ ?i $?list))
        (-- ?i)
        (bind ?result (str-cat ?result  ?*prefix* ?attribute "::"))
        ;(printout t "calculatedList: " ?attributeName " : " (str-cat ?*prefix* ?attribute) crlf)
        )  
    (bind ?attribute (nth$ 1 $?list))
    (bind ?result (str-cat ?result  ?*prefix* ?attribute))
    (return ?result)
    )

(deffunction eliminatePrefix (?string)
    ;eliminate the prefix of a full name, return the concise name
    (bind ?loc (str-index "#" ?string))
    (if (eq ?loc FALSE) then
        (return "FLASE")
        )
    (bind ?string (sub-string (+ ?loc 1) (str-length ?string) ?string))
    (return ?string)
    )

(deffunction eliminatePrefixList ($?list)
    (bind ?i (length$ $?list))
    (bind $?result (create$))
    (while (> ?i 0)
        (bind ?curr (nth$ ?i $?list))
        (bind ?currResult (eliminatePrefix ?curr))
        (bind $?result (union$ $?result (create$ ?currResult)))
        (-- ?i)
    )
    (return $?result)
)

(deffunction prefixJudge ($?string)
    (bind ?length (length$ $?string))
    (bind ?i ?length)
    (bind $?result (create$))
    (while (> ?i 0)
        (bind ?j (str-index "#" (nth$ ?i $?string)))
        (if (eq ?j FALSE) then
            (return FALSE)
            )
        (-- ?i))
    (return TRUE)
    )

(deffunction addPrefix (?string)
    (bind ?string (str-cat ?*prefix* ?string))
    (return ?string)
    )

(deffunction addPrefixList ($?string)
    ;eliminate the prefix of a full name, return the concise name
    (bind ?length (length$ $?string))
    (bind ?i ?length)
    (bind $?result (create$))
    (while (> ?i 0)
        (bind $?result (create$ $?result (addPrefix (nth$ ?i $?string))))
        (-- ?i))
    (return $?result)
    )

(deffunction str2list(?string ?delimeter)
    ;;(printout t "The input: " ?string " && " ?delimeter crlf)
    (bind $?result (create$))
    (while(> (str-length ?string) 0)
        (bind ?index (str-index ?delimeter ?string))
    	(if (neq ?index FALSE) then
            ;multiple
            ;(bind $?result (create$ (sub-string 1 (- ?index 1) ?string) $?result))
        	(bind $?result (union$ $?result (create$ (sub-string 1 (- ?index 1) ?string))))
        	(bind ?string (sub-string (+ ?index (str-length ?delimeter)) (str-length ?string) ?string))
     	 else
            ;single
            ;(printout t "Before updated: " $?result crlf)
        	(bind $?result (union$ $?result (create$ ?string)))
            ;(printout t "Updated: " $?result crlf)
        	(return $?result)
    	)
    )
    ;(printout t "str2list: " $?result crlf) 
    (return $?result)
)

(deffunction list2string(?delimeter $?list)
    (bind ?len (length$ $?list))
    (bind ?i (- ?len 1))
    (bind ?result (nth$ ?len $?list))
    (while (> ?i 0)
        (bind ?result (str-cat ?result ?delimeter (nth$ ?i $?list)))
        (-- ?i)
    );while
    ;(printout t "ToString: " ?result crlf)
    (return ?result)
    )

(deffunction containJudge(?element $?list)
    ;; return TRUE if "an element" in $?list contains ?element
    ;; $?list is a list, whose element has a format of "word1@@flag1::word2@@flag2::word3@@flag3...."
    ;; match only when equal and with false flag
    
    (bind ?i (length$ $?list))
    (while (> ?i 0)
        (bind ?curr (nth$ ?i $?list))
        (bind $?tempList (str2list ?curr "::"))
        ;; (printout t "Current candidate: " ?curr " && " ?element crlf)
        (if (member$ (str-cat ?element "@@FALSE") $?tempList) then
            (return TRUE)
        )
        
        (-- ?i)
    );while in the list
    (return FALSE)
)

(deffunction getUpdatedGroup (?element ?object $?list)
    ; return a list of new attribute ;this list is generated from an element in $?list
    ; that is, an attribute in an element of $?list is replaced by other attribute(s), so this found just return the new list, no other actions to the old list
    ; ?element is just one metric
    ; ?object can contain several metrics in format of "m1::m2::m3..."
    
    ;(printout t "Updating: " ?object " From: " ?element " In: "  $?list crlf)
    (bind ?i (length$ $?list))
    (bind $?result (create$))
    ;;(printout t "Current candidate: " ?object " && " ?element crlf)
    (bind $?newList (str2list ?object "::"))
    
    
    (bind ?foundFlag FALSE)
    (while (> ?i 0)
        ; generate the new string named ?string from the containing string named ?curr
        ;(printout t ?i "-th loop" crlf)
        (bind ?curr  (nth$ ?i $?list))
        ;(printout t "Current list: " ?curr " && " ?element crlf)
        (bind $?tempList (str2list ?curr "::")) ;; this list's elements have the suffix of "@@flag" 
        ;(printout t "str2list: " $?tempList crlf) 
        (if (member$ (str-cat ?element "@@FALSE") $?tempList) then
            (bind ?j (length$ $?tempList))
            (while (> ?j 0)
                (bind ?currStr (nth$ ?j $?tempList))
                (if (eq (str-cat ?element "@@FALSE") ?currStr) then
                    (bind $?result (union$ $?result $?newList))
                    (bind ?foundFlag TRUE);(return $?result)
                 else
                    (bind ?loc (str-index "@@" ?currStr))
                    (bind $?result (union$ (create$ (sub-string 1 (- ?loc 1) ?currStr)) $?result))
                )
                (-- ?j)
            )
        ); end if contain
        (if (eq ?foundFlag TRUE) then
            (bind ?i 0)
         else
            (-- ?i)
        )
    )
    ;(printout t "Updated result: " $?result crlf)
    (return $?result)    
)

(deffunction containUpdate (?element ?object $?list)
    ;delete the old onw, add the new one, and return a new list
    ; ?element is a single metric
    ; ?object is a set of metrics, including the replacement of ?element. ?object is in format of "m1::m2::m3...", so when replacing reformat is needed
    ; $?list is a list of sets metrics, one of which contain ?element, and need to be replaced by ?object
    
    ;;(printout t "The input for containUpdate: " ?element " && " ?object " && " $?list crlf)
    
    (bind $?newList (str2list ?object "::"))
    (bind ?l (length$ $?newList)) 
    (bind ?newObject (str-cat (nth$ ?l $?newList) "@@FALSE"))
    (-- ?l)
    (while (> ?l 0)
        (bind ?newObject (str-cat ?newObject "::" (nth$ ?l $?newList) "@@FALSE") )
        (-- ?l)
    )
    
    (bind ?i (length$ $?list))
    (bind $?result (create$ ))
    (while (> ?i 0)
        (bind ?curr (nth$ ?i $?list))
        ;;(printout t "Current list: " ?curr " && " ?element crlf)
        (bind $?tempList (str2list ?curr "::"))
        (if (member$ (str-cat ?element "@@FALSE") $?tempList) then
            (bind $?result (union$ $?result (create$ ?newObject)))
            ;(printout t "The new one" $?result " && the object " ?object crlf)
            
            (bind $?newList (create$))
            (bind ?l (length$ $?tempList))
            (while (> ?l 0)
                (bind ?string (nth$ ?l $?tempList))
                (if (eq (str-cat ?element "@@FALSE") ?string) then
                    (bind $?newList (union$ $?newList (create$ (str-cat ?element "@@TRUE"))))
                 else 
                	(bind $?newList (union$ $?newList (create$ ?string)))
                )	
                (-- ?l)
            )
            
            (bind $?result (union$ $?result (create$ (list2string "::" $?newList))))
            ;(printout t "The old one" $?result crlf)
          else 
            (bind $?result (union$ $?result (create$ ?curr)))
        )
        (-- ?i)
    )
    ;(printout t $?result)
    (return $?result)
)



(deffunction addAfterCheck (?new $?list)
    (if (not (member$ ?new $?list)) then
        (bind $?list (create$ $?list ?new))
    )
    (return $?list)
)

(deffunction getRest (?candidateIndex ?sensor)
    ;remove intersection from the rest4match
    (bind $?restList ?candidateIndex.rest4match)
    (bind $?common (intersection$ $?restList ?sensor.attribute))
    (bind ?i (length$ $?restList))
    (bind $?result (create$))
    (while (> ?i 0)
        (if (not (member$ (nth$ ?i $?restList) $?common)) then
            (bind $?result (union$ $?result (create$ (nth$ ?i $?restList))))
            )
        (-- ?i)
        )
    (return $?result)
)

(deffunction getFormula (?string)
    ; result the right hand side of the '=' symbol
    ;(printout t "Input formula: " ?string crlf)
    (bind ?i (str-index "=" ?string))
    (bind ?temp (sub-string (+ ?i 1) (str-length ?string) ?string))
    ;(printout t "Cutted formula: " ?temp crlf)
    (bind ?b (new OperateTriDouble))
    (?b setObject ?temp)
    (bind $?result (?b getFormula))
    ;(printout t "Parsed formula: " $?result crlf)
    (return $?result)
)

(deffunction mergeFormula (?attributeName $?formula)
    (bind ?i 1)
    (while (< ?i (length$ $?formula))
        (bind ?curr (nth$ ?i $?formula))
        (if (eq ?attribute ?curr) then
            (return ?i)
        )
        (++ ?i)
    )
)

(deffunction formula2str ($?formula)
    (bind ?i 1)
    ;(printout t "Input formula: " $?formula crlf)
    (bind ?string "< ")
    ;(printout t ?string crlf)
    (while (<= ?i (length$ $?formula))
        (bind ?curr (nth$ ?i $?formula))
        ;(printout t ?curr crlf)
        (bind ?string (str-cat ?string " " ?curr ))
        ;(printout t ?string crlf)
        (++ ?i)
    )
    (bind ?string (str-cat ?string " >"))
    ;(printout t "Formula to string: " ?string crlf )
    (return ?string)
)


;------------------rule section-------------------

(defrule entrance
    ; detect and control the rule entrance
    (declare (salience 1000))
    ?fact <- (slaItem) ;;sla not null, then sla entrance
    ?ent <- (entranceShift)
    =>
    ;(retract ?ent)
    ;(assert 
    ;    (entranceShift 
    ;        (value 1))
    ;    )
    (modify ?ent (value 1))
    )

(defrule getPrefix
    ;update the prefix to match items from the ontology
    (declare (salience 1000))
    ?root <- (triple (predicate ?predicate&:(eq ?predicate ?*type*)) (subject ?subject) (object ?object&:(eq ?object "http://www.w3.org/2002/07/owl#Ontology")))
    =>
    (bind ?*prefix* (str-cat ?subject "#"))
    
    (bind ?*Performance*  (str-cat ?*prefix* "Performance"))

	(bind ?*hasMetric*  (str-cat ?*prefix* "hasMetric"))

	(bind ?*measures* (str-cat ?*prefix* "measures"))

	(bind ?*calculatedBy*  (str-cat ?*prefix* "calculatedBy"))

	(bind ?*triggerBy* (str-cat ?*prefix* "triggerBy"))
   
    )

(defrule addPrefix_sensor
    ;adjust the name of sensors and sensor attributes to make them consistent with the names in the ontology
    (declare (salience 999))
    ?former <- (sensors (name $?nameList&:(eq (prefixJudge $?nameList) FALSE)) (attribute $?attributeList&:(eq (prefixJudge $?attributeList) FALSE)))
    =>
    (modify ?former
        (name (addPrefixList $?nameList))
        (attribute (addPrefixList $?attributeList))
        )
    ;(printout t "adding prefix for sensors: " ?former.name crlf)
)

(defrule addPrefix_analyzer
    (declare (salience 999))
    ?former <- (analyzers (name $?nameList&:(eq (prefixJudge $?nameList) FALSE)) (attribute $?attributeList&:(eq (prefixJudge $?attributeList) FALSE)))
    =>
    (modify ?former
        (name (addPrefixList $?nameList))
        (attribute (addPrefixList $?attributeList))
        )
    ;(printout t "adding prefix for analyzers: " ?former.name crlf)
)

(defrule loadAnalyzer
    (declare (salience 100))
    ?gate <- (entranceShift (value ?entrance&:(eq ?entrance 0))) ;;no sla
    ;;analyzer to metric
    ?analyzer <- (analyzers (name ?analyzerName))
    ;(not (selectedAttribute (attributeName ?attibutedName&:(eq ?analyzerName ?attibutedName))))
    =>
    ;(printout t "fired" crlf)
    (addAttribute ?analyzer)
)

(defrule loadSLA
    (declare (salience 100))
    ?gate <- (entranceShift (value ?entrance&:(neq ?entrance 0))) ;;with sla
    ?sla <- (slaItem)
    =>
    (assert 
        (selectedAttribute
            (attributeName ?sla.name)
            (helpList (create$ (str-cat ?sla.name "@@FALSE")))
            (calculatedList (create$ ?*groupIndex*))
            (unit ?sla.unit))
        )
    (assert 
        (candidateIndex
            (index ?*groupIndex*)
            (candidate (create$ ?sla.name))
            (rest4match (create$ ?sla.name))
            )
        )
    (++ ?*groupIndex*)
    (++ ?*attributeNumber*) 
)

(defrule mergeAttribute
    (declare (salience 99))
    ?attribute1 <- (selectedAttribute (attributeName ?attributeName1) (calculatedList $?calculatedList1))
    ?attribute2 <- (selectedAttribute (attributeName ?attributeName2&:(eq ?attributeName1 ?attributeName2)) (calculatedList $?calculatedList2&:(eq (length$ (intersection$ $?calculatedList1 $?calculatedList2)) 0)))
    =>
    ;(printout t "merged" ?attributeName1 crlf)
    (retract ?attribute2)    
    (-- ?*attributeNumber*)
)

(defrule cascade_calculated
    ;;empty check, existing check, endless check
    ;;assumption: comment or calculate, can't together
    ;;assumption: calculate can't work in endless loop
    ;;assumption: prefix ends with "#", and "#" is prohibited in other names
    (declare (salience 95))
    ?attribute <- (selectedAttribute (attributeName ?attributeName) (helpList $?helpList) (calculatedList $?calculatedList))
    ?attr_restr <- (triple (subject ?subject1&:(containJudge ?subject1 $?helpList)) (predicate ?predicate1&:(eq ?predicate1 ?*subClassOf*)) (object ?object1))
    ?Restr <- (triple (object ?object2&:(eq ?object2 ?*Restriction*)) (predicate ?predicate2&:(eq ?predicate2 ?*type*)) (subject ?subject2&:(eq ?subject2 ?object1)))
    ?property <- (triple (subject ?subject3&:(eq ?subject3 ?subject2)) (predicate ?predicate3&:(eq ?predicate3 ?*onProperty*)) (object ?object3&:(eq ?object3 ?*calculatedBy*)))
    ?target <- (triple (subject ?subject4&:(eq ?subject4 ?subject3)) (predicate ?predicate4&:(member$ ?predicate4 (create$ ?*someValuesFrom* ?*onClass* ?*allValuesFrom*))) (object ?object4))
    ;?node <- (treeNode (attributeName ?attributeName5&:(eq ?attributeName ?attributeName5)) (formula $?formula))
    =>
    ;;(printout t "case" crlf ?subject1 "--" ?object1 crlf ?subject2 "--" ?object2 crlf ?subject3 "--" ?object3 crlf ?subject4 "--" ?object4 crlf $?helpList crlf)
    (bind $?group (getUpdatedGroup ?subject1 ?target.object $?helpList))
    (assert
       (candidateIndex
            (index ?*groupIndex*)
            (candidate $?group)
            ;(candidate (create$ $?group))
            (rest4match $?group)
            )
    )
    (assert
        (treeNode
            (attributeName ?subject1)
            (formula (create$ (eliminatePrefix ?object4)))
        ) 
    )
    ;(printout t "Calculated: " $?group crlf)
    (modify ?attribute
        (helpList (containUpdate ?subject1 (list2string "::" $?group) $?helpList ))
    	(calculatedList (create$ $?calculatedList ?*groupIndex*))        
    )
    (++ ?*groupIndex*)
    ;(printout t ?attribute.attributeName ?attribute.helpList ?attribute.calculatedList crlf)
)

(defrule cascade_commented
    ;;empty check, existing check
    (declare (salience 95))
    ?attribute <- (selectedAttribute (attributeName ?attributeName) (helpList $?helpList) (calculatedList $?calculatedList))
    ;commented
    ?commentTriple <- (triple (subject ?subject1&:(containJudge ?subject1 $?helpList)) (predicate ?predicate1&:(eq ?predicate1 ?*comment*)) (object ?object1))
    ;?node <- (treeNode (attributeName ?attributeName3&:(eq ?attributeName ?attributeName3)) (formula $?formula))
    =>
    (bind ?a (new StringSpliter))
	(?a setTarget ?object1) 
    ;;(printout t "Parsed: "(parseComment (?a getSplit)) crlf)
    (bind $?group (getUpdatedGroup ?subject1 (parseComment (?a getSplit)) $?helpList))
    ;;(printout t "For comment: " ?subject1 " && " ?object1 " && " $?helpList crlf)
    ;;(printout t "Commented: " $?group crlf)
    (assert
        (candidateIndex
            (index ?*groupIndex*)
            (candidate $?group)
            ;(candidate (create$ $?group))
            (rest4match $?group)
            )
    )
    ;(printout t "Formula: " ?object1 crlf)
    (assert
        (treeNode
            (attributeName ?subject1)
            (formula (getFormula ?object1))
        )
    )
    ;;(printout t "For containUpdate: " (list2string "::" $?group) " from  " $?group crlf)
    (modify ?attribute
        (helpList (containUpdate ?subject1 (list2string "::" $?group) $?helpList ))
    	(calculatedList (create$ $?calculatedList ?*groupIndex*))        
        )
    (++ ?*groupIndex*)
)

(defrule triggered
    ;;existing check
    (declare (salience 95))
    ?attribute <- (selectedAttribute (attributeName ?attributeName) (helpList $?helpList) (calculatedList $?calculatedList))
    ?attr_restr <- (triple (subject ?subject1&:(containJudge ?subject1 $?helpList)) (predicate ?predicate1&:(eq ?predicate1 ?*subClassOf*)) (object ?object1))
    ?Restr <- (triple (object ?object2&:(eq ?object2 ?*Restriction*)) (predicate ?predicate2&:(eq ?predicate2 ?*type*)) (subject ?subject2&:(eq ?subject2 ?object1)))
    ?property <- (triple (subject ?subject3&:(eq ?subject3 ?subject2)) (predicate ?predicate3&:(eq ?predicate3 ?*onProperty*)) (object ?object3&:(eq ?object3 ?*triggerBy*)))
    ?target <- (triple (subject ?subject4&:(eq ?subject4 ?subject3)) (predicate ?predicate4&:(member$ ?predicate4 (create$ ?*someValuesFrom* ?*onClass* ?*allValuesFrom*))) (object ?object4))
    ;?node <- (treeNode (attributeName ?attributeName5&:(eq ?attributeName ?attributeName5)) (formula $?formula))
    =>
    (bind $?group (getUpdatedGroup ?subject1 ?target.object $?helpList))
    ;(printout t "Triggered: "$?group " From: " ?subject1 crlf)
    (assert
        (candidateIndex
            (index ?*groupIndex*)
            (candidate $?group)
            ;(candidate (create$ $?group))
            (rest4match $?group)
            )
        )
    (assert
        (treeNode
            (attributeName ?subject1)
            (formula (create$ (eliminatePrefix ?object4)))
        )
        
    )
    (modify ?attribute
        (helpList (containUpdate ?subject1 (list2string "::" $?group) $?helpList ))
    	(calculatedList (create$ $?calculatedList ?*groupIndex*))        
        )
    ;(printout t "triggered result: " ?attribute.helpList "From: " ?object4 crlf)
    (++ ?*groupIndex*)
)

(defrule linkSensor
    (declare (salience 90))
    ; view rest4match as a list, and every time match a sensor for the head attribute in the list
    ; after  
    ;;; cost: activation cost, running cost, communication cost
    ;; TODO::time variant, so need to use "test" conditional element as head!!!
    ?attributeGroup <- (candidateIndex (index ?index) (candidate $?candidateGroup) (rest4match $?rest4match&:(> (length$ $?rest4match) 0)) (cost $?costTotal))
    ?candidateSensor <- (sensors (name ?sensorName) (attribute $?sensorAttribute&:(> (length$ (intersection$ $?sensorAttribute $?rest4match)) 0)) (cost ?cost))
    =>
    (modify ?attributeGroup
        (rest4match (getRest ?attributeGroup ?candidateSensor))
        (matchedSensor  (addAfterCheck (str-cat ?sensorName) ?candidateSensor.name ?attributeGroup.matchedSensor))
        ;(cost (addCostAfterCheck))
    )
)

(defrule getAnalyzer
    ;from sla
    (declare (salience 90))
    ?attribute <- (selectedAttribute (attributeName ?attributeName))
    ?analyzer <- (analyzers (name ?analyzerName) (attribute $?attributeList&:(member$ ?attributeName $?attributeList)))
    =>
    (assert 
        (candidateAnalyzer
            (attributeName ?attributeName)
            (analyzerName ?analyzerName))
        )
    )

(defrule finalAnalyzer
    ;TODO: need to be better
 	;TODO: concern trimming by sensor
    (declare (salience 89))
    ?analyzer1 <- (candidateAnalyzer)
    ?analyzer2 <- (candidateAnalyzer {attributeName == analyzer1.attributeName && analyzerName != analyzer1.analyzerName})
    =>
    (retract ?analyzer2)
    )


(defrule matchSensor
    ;; remove redundency
    (declare (salience 89))
    ?attribute <- (selectedAttribute (attributeName ?attributeName) (helpList $?helpList) (calculatedList $?calculatedList))
    ?attributeGroup <- (candidateIndex (index ?index&:(member$ ?index $?calculatedList)) (candidate $?candidateGroup) (rest4match $?rest4match&:(eq (length$ $?rest4match) 0)) (cost $?costTotal))
    ?node <- (treeNode (attributeName ?attributeName3&:(eq ?attributeName ?attributeName3)) (formula $?formula))    
    =>
    ;(printout t "#Attribute: " (eliminatePrefix ?attributeName) " Candidate: " $?candidateGroup " #Matched Sensor: " ?attributeGroup.matchedSensor crlf )
    (assert
        (candidateSensor
            (attributeName ?attributeName)
            (candidate $?candidateGroup)
            (sensorName ?attributeGroup.matchedSensor)
            (formula $?formula)
        ) 
    )
    ;(printout t "#Formula: " $?formula crlf)
)

(defrule matchFormula
    ;; remove redundency
    (declare (salience 88))
    ?attribute <- (selectedAttribute (attributeName ?attributeName) (helpList $?helpList) (calculatedList $?calculatedList))
    ;?attributeGroup <- (candidateIndex (index ?index&:(member$ ?index $?calculatedList)) (candidate $?candidateGroup) (rest4match $?rest4match&:(eq (length$ $?rest4match) 0)) (cost $?costTotal))    
    ?candidate <- (candidateSensor (attributeName ?attributeName2&:(eq ?attributeName ?attributeName2)) (candidate $?candidateAttribute) (formula $?formulaCache)) 
    ?node <- (treeNode (attributeName ?attributeName3&:(member$ (eliminatePrefix ?attributeName3) $?formulaCache)&:(not (member$ ?attributeName3 $?candidateAttribute))) (formula $?formula))   
    =>
    ;(printout t "#Attribute: " (eliminatePrefix ?attributeName) crlf )
    ;(printout t "#Formula: " $?formula crlf)
    ;(bind ?loc (mergeFormula (eliminatePrefix ?attributeName3) $?formulaCache))
    (bind ?loc (member$ (eliminatePrefix ?attributeName3) $?formulaCache))
    (bind $?tempList (delete$ $?formulaCache ?loc ?loc)) 
    (modify ?candidate
        (formula (insert$ $?tempList ?loc $?formula))
    )
    ;(printout t "New formula: " ?candidate.formula crlf)
)

(defrule setMatch1
    ;from sla
    (declare (salience 50))
    ?gate <- (entranceShift (value ?entrance&:(neq ?entrance 0))) ;;with sla
    ?sla <- (selectedAttribute (attributeName ?attributeName) (unit ?unit))
;    ?commentTriple <- (triple (subject ?subject1&:(eq ?subject1 ?attributeName)) (predicate ?predicate1&:(eq ?predicate1 ?*comment*)) (object ?object1))
	?analyzer <- (candidateAnalyzer {attributeName == sla.attributeName})
    ?sensor <- (candidateSensor {attributeName == sla.attributeName})
    ;;?MtoS1 <- (MS)
    =>
    ;;(printout t "From SLA to sensors: " ?PtoM.slaItemName ?MtoS.metric ?MtoS.sensorId ?AtoA.analyzerId crlf)
	(assert 
        (result_sla
            (attributeName (eliminatePrefix ?attributeName))
            (formula ?sensor.formula)
            (sensorName (eliminatePrefixList ?sensor.sensorName))
            (analyzerName (eliminatePrefix ?analyzer.analyzerName))
            (unit ?unit)
            (coefficient (convertor ?unit ?analyzer ?sensor)))
        )
    )

(defrule setMatch2_0
    ;from analyzer
    (declare (salience 50))
    ?gate <- (entranceShift (value ?entrance&:(eq ?entrance 0))) ;;no sla
    ?analyzer <- (analyzers (name ?analyzerName) (attribute $?attributeList))
    ?allAttribute <- (accumulate (bind $?result (create$))
        (bind $?result (union$ $?result (create$ ?attributeName)))
        $?result
        (candidateSensor (attributeName ?attributeName&:(member$ ?attributeName $?attributeList)) (sensorName $?sensorName))
        )

    =>
    (assert 
        (result_analyzer
            (analyzerName (eliminatePrefix ?analyzerName))
            (attributeName (eliminatePrefixList ?allAttribute))
            ;(formula ?allFormula)
            ;(sensorName (eliminatePrefixList ?allSensor))
            ;(unit ?unit)
            ;(coefficient (convertor ?unit ?analyzer ?sensor))
            )
        )
    ;(printout t  "Matched result: " (eliminatePrefixList ?attributeList) " Sensor: " (eliminatePrefixList ?allSensor) crlf)
    )

(defrule setMatch2_1
    ;from analyzer
    (declare (salience 49))
    ?gate <- (entranceShift (value ?entrance&:(eq ?entrance 0))) ;;no sla
    ?analyzer <- (result_analyzer (analyzerName ?analyzerName) (attributeName $?attributeList))
    ?allSensor <- (accumulate (bind $?result (create$))
        (bind $?result (union$ $?result $?sensorName))
        $?result
        (candidateSensor (attributeName ?attributeName&:(member$ (eliminatePrefix ?attributeName) $?attributeList)) (sensorName $?sensorName) (formula $?formula))
        )
    =>
    (assert
        (result_analyzer2
            (analyzerName ?analyzerName)
            (attributeName $?attributeList)
            (sensorName (eliminatePrefixList ?allSensor))
        )
    )
    ;(printout t  "Matched result: "  $?attributeList " Formula: " (?allFormula toString) crlf)
    )

(defrule setMatch2_2
    ;from analyzer
    (declare (salience 49))
    ?gate <- (entranceShift (value ?entrance&:(eq ?entrance 0))) ;;no sla
    ?analyzer <- (result_analyzer2 (analyzerName ?analyzerName) (attributeName $?attributeList))
    ?allFormula <- (accumulate (bind $?result (create$))
        (bind $?result (union$ $?result (create$ (formula2str $?formula))))
        $?result
        (candidateSensor (attributeName ?attributeName&:(member$ (eliminatePrefix ?attributeName) $?attributeList)) (sensorName $?sensorName) (formula $?formula))
        )
    =>
    (modify  ?analyzer
            (formula ?allFormula)
            ;(unit ?unit)
            ;(coefficient (convertor ?unit ?analyzer ?sensor))
            
    )
    ;(printout t  "Matched result: "  $?attributeList " Formula: " (?allFormula toString) crlf)
    )

(defrule output1
    ;from sla
    (declare (salience 45))
    ?gate <- (entranceShift (value ?entrance&:(neq ?entrance 0))) ;;with sla
    ?result <- (result_sla)
    =>
    (bind ?cof (/ ?Unit1.value ?Unit2.value))
    
    (printout id "Reasoning information, starting from SLA: " crlf "attributeName:  "?result.attributeName  crlf "formula  " ?result.formula crlf "sensorName  " ?result.sensorName crlf "analyzerName  " ?result.analyzerName crlf "unit  " ?result.unit crlf "coefficient  " ?result.cofficient crlf crlf)    
    (printout t "Reasoning information, starting from SLA: " crlf )
    (printout t "attributeName  " ?result.attributeName crlf)
    (printout t "formula  " ?result.formula crlf)
    (printout t "sensorName  " ?result.sensorName crlf)
    (printout t "analyzerName  " ?result.analyzerName crlf)
    ;(printout t "unit  " ?result.unit crlf)
    ;(printout t "coefficient  " ?result.coefficient crlf crlf)
    
    (assert
        (finalAttributeList 
            (attributeName ?result.attributeName))
        )
    ;(retract ?result)
    )

(defrule output2
    ;from analyzer
    (declare (salience 45))
    ?gate <- (entranceShift (value ?entrance&:(eq ?entrance 0))) ;;no sla
    ?result <- (result_analyzer2)
    =>
    ;(bind ?cof (/ ?Unit1.value ?Unit2.value))
    
    (printout id "Reasoning information, starting from selected analyzers: " crlf "analyzerName:  "?result.analyzerName crlf "sensorName  " ?result.sensorName crlf "attributeName  " ?result.attributeName crlf "formula  " ?result.formula crlf  "unit  " ?result.unit crlf  "coefficient  " ?result.coefficient crlf crlf)
    
    (printout t "Reasoning information, starting from selected analyzers: " crlf )
    (printout t "analyzerName  " ?result.analyzerName crlf)
    (printout t "sensorName  " ?result.sensorName crlf)
    (printout t "attributeName  " ?result.attributeName crlf)
    (printout t "formula  " ?result.formula crlf crlf)
    ;(printout t "unit  " ?result.unit crlf)
    ;(printout t "coefficient  " ?result.coefficient crlf crlf)
    ;(finalizeAttribute_analzyer ?result.attributeName)
    ;(retract ?result)
    )


(defrule printSelectedAttribute
    (declare (salience 10))
    ?attribute <- (selectedAttribute)
    =>
    (bind $?newList (create$ ))
    (bind ?i (length$ ?attribute.helpList))
    (while (> ?i 0)
        (bind ?curr (nth$ ?i ?attribute.helpList))
        (bind $?tempList (str2list ?curr "::"))
        (bind ?newHelp (list2string "::" (eliminatePrefixList $?tempList)))
        (bind $?newList (union$ $?newList (create$ ?newHelp)))
        (-- ?i)
    )
    ;(printout t "Attribute: "  (eliminatePrefix ?attribute.attributeName) $?newList ?attribute.calculatedList crlf)
    )

(defrule printCandidateIndex
    (declare (salience 10))
    ?index <- (candidateIndex)
    =>
    ;(printout t "Index: " ?index.index (eliminatePrefixList ?index.candidate) (eliminatePrefixList ?index.rest4match) (eliminatePrefixList ?index.matchedSensor)  crlf)
    )

(defrule printCandidateSensor
    (declare (salience 10))
    ?sensor <- (candidateSensor)
    =>
    ;(printout t "Sensor: " (eliminatePrefix ?sensor.attributeName) (eliminatePrefixList ?sensor.sensorName) ?sensor.formula crlf)
    )

;------------facts load---------------

(batch "reasoning/SLA/SLAfacts.clp")
(batch "reasoning/r_sensor/Sensorfacts.clp")
(batch "reasoning/r_analyzer/Analyzerfacts.clp")
(batch "reasoning/ontology/redirect.clp")
(batch "reasoning/ontology/transformed/batch.clp")

;;entrance , cascade, full match

(run)

