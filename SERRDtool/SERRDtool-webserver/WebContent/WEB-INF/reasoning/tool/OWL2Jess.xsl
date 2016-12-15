<?xml version="1.0" encoding="ISO-8859-1"?>
<!-- Transforms a RDF schema into a set of JESS assertions based on the description of the meta-model of RDF(S) -->

<!DOCTYPE uridef[
  <!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns">
  <!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema">
  <!ENTITY xsd "http://www.w3.org/2000/10/XMLSchema">
  <!ENTITY nbsp "&#160;">
]>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
 xmlns:rdf="&rdf;#"
 xmlns:rdfs="&rdfs;#"
 xmlns:xsd="&xsd;#"
 >
  <!-- get the namespace of the RDF file -->
  <xsl:param name='namespace' select="concat(/rdf:RDF/@xml:base,'#')"/>
  
  <xsl:output method="text" media-type="text/plain" encoding="ISO-8859-1" omit-xml-declaration="yes"/>

  <xsl:template match="/"><xsl:apply-templates /></xsl:template>
  <xsl:template match="rdf:RDF"><xsl:apply-templates /></xsl:template>
  

  <!-- transform RDF snytax into Jess triples - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -->
  
  <!-- declare root class instances -->
  <xsl:template match="/rdf:RDF/*">
    <xsl:call-template name="process-class-instance"/>
  </xsl:template>



  <!-- named templates - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -->

  <!-- process an instance of a class -->
  <xsl:template name="process-class-instance" >
(assert
  (triple
    (predicate "&rdf;#type")
    (subject   "<xsl:call-template name="get-ID"/>")
    (object    "<xsl:value-of select="concat(namespace-uri(.),local-name(.))"/>")
  )
)<xsl:for-each select="*"><xsl:call-template name="process-property-instance"/></xsl:for-each> 
  </xsl:template>

  <!-- process an instance of a property -->
  <xsl:template name="process-property-instance" >
    <xsl:choose>
      <xsl:when test='count(*)=1'> <!-- has element nodes as children -->
        <xsl:call-template name="process-objectproperty-instance"/>
      </xsl:when>
      <xsl:when test='count(text())=1'> <!-- has text nodes as children -->
        <xsl:call-template name="process-dataproperty-instance"/>
      </xsl:when>
      <xsl:when test='count(*)>1'> <!-- has a collection -->
        <xsl:for-each select="*"><xsl:call-template name="process-collection"/></xsl:for-each>
      </xsl:when>
      <xsl:when test='@rdf:resource'> <!-- has a reference -->
        <xsl:call-template name="process-referenceproperty-instance"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- process an instance of a objectproperty -->
  <xsl:template name="process-objectproperty-instance" >
(assert
  (triple
   (predicate "<xsl:value-of select="concat(namespace-uri(.),local-name(.))"/>")
   (subject   "<xsl:call-template name="get-father-ID"/>")
   (object    "<xsl:call-template name="get-child-ID"/>")
  )
)<xsl:for-each select="*[position()=1]"><xsl:call-template name="process-class-instance"/></xsl:for-each>
  </xsl:template>

  <!-- process a collection -->
  <xsl:template name="process-collection" >
(assert
  (triple
   (predicate "<xsl:value-of select="concat(namespace-uri(..),local-name(..))"/>")
   (subject   "<xsl:call-template name="get-grandfather-ID"/>")
   (object    "<xsl:call-template name="get-ID"/>")
  )
)<xsl:for-each select="*"><xsl:call-template name="process-property-instance"/></xsl:for-each> 
  </xsl:template>
  
  <!-- process an instance of a dataproperty -->
  <xsl:template name="process-dataproperty-instance" >
(assert
  (triple
   (predicate "<xsl:value-of select="concat(namespace-uri(.),local-name(.))"/>")
   (subject   "<xsl:call-template name="get-father-ID"/>")
   (object    "<xsl:value-of select="normalize-space(.)"/>")
  )
)  
  </xsl:template>

  <!-- process an instance of a property referencing a resource in its range-->
  <xsl:template name="process-referenceproperty-instance" >
(assert
  (triple
   (predicate "<xsl:value-of select="concat(namespace-uri(.),local-name(.))"/>")
   (subject   "<xsl:call-template name="get-father-ID"/>")
   (object    "<xsl:call-template name="local-Ref"><xsl:with-param name="ref"><xsl:value-of select="@rdf:resource"/></xsl:with-param></xsl:call-template>")
  )
)
  </xsl:template>


  <!-- named templates - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -->
  
  <!-- normalize local URIs -->
  <xsl:template name="local-ID" >
    <xsl:param name="id" />
    <xsl:choose>
      <xsl:when test="starts-with($id,'#')">
        <xsl:value-of select="concat($namespace,substring-after($id,'#'))"/>
      </xsl:when>
      <xsl:when test="contains($id,'/') or contains($id,'#') or contains($id,':')">
        <xsl:value-of select="$id" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat($namespace,$id)"/>
      </xsl:otherwise>
    </xsl:choose> 
  </xsl:template>

  <!-- normalize local References (including the #) -->
  <xsl:template name="local-Ref" >
    <xsl:param name="ref" />
    <xsl:choose>
      <xsl:when test="starts-with($ref,'#')">
        <xsl:value-of select="concat($namespace,substring-after($ref,'#'))"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$ref" /></xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!-- get ID or About of the current node -->
  <xsl:template name="get-ID" >
    
    <xsl:choose>
      <xsl:when test="@rdf:ID">
        <xsl:call-template name="local-ID"><xsl:with-param name="id"><xsl:value-of select="@rdf:ID"/></xsl:with-param></xsl:call-template> 
      </xsl:when>
      <xsl:when test="@rdf:about">
        <xsl:call-template name="local-ID"><xsl:with-param name="id"><xsl:value-of select="@rdf:about"/></xsl:with-param></xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat($namespace,generate-id(.))"/>
      </xsl:otherwise>
    </xsl:choose> 
  </xsl:template>


  
  <!-- get the ID or About of the parent node -->
  <xsl:template name="get-father-ID" >
    
    <xsl:choose>
      <xsl:when test="../@rdf:ID">
        <xsl:call-template name="local-ID"><xsl:with-param name="id"><xsl:value-of select="../@rdf:ID"/></xsl:with-param></xsl:call-template> 
      </xsl:when>
      <xsl:when test="../@rdf:about">
        <xsl:call-template name="local-ID"><xsl:with-param name="id"><xsl:value-of select="../@rdf:about"/></xsl:with-param></xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat($namespace,generate-id(..))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- get the ID or About of the grandparent node -->
  <xsl:template name="get-grandfather-ID" >
    
    <xsl:choose>
      <xsl:when test="../../@rdf:ID">
        <xsl:call-template name="local-ID"><xsl:with-param name="id"><xsl:value-of select="../../@rdf:ID"/></xsl:with-param></xsl:call-template> 
      </xsl:when>
      <xsl:when test="../../@rdf:about">
        <xsl:call-template name="local-ID"><xsl:with-param name="id"><xsl:value-of select="../../@rdf:about"/></xsl:with-param></xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat($namespace,generate-id(../..))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  
  <!-- get the ID or About of the first child  -->

  <xsl:template name="get-child-ID" >
    <xsl:choose>
      <xsl:when test="@rdf:resource">
        <xsl:call-template name="local-ID"><xsl:with-param name="id"><xsl:value-of select="@rdf:resource"/></xsl:with-param></xsl:call-template> 
      </xsl:when>
      <xsl:when test="*[position()=1]/@rdf:ID">
        <xsl:call-template name="local-ID"><xsl:with-param name="id"><xsl:value-of select="*[position()=1]/@rdf:ID"/></xsl:with-param></xsl:call-template> 
      </xsl:when>
      <xsl:when test="*[position()=1]/@rdf:about">
        <xsl:call-template name="local-ID"><xsl:with-param name="id"><xsl:value-of select="*[position()=1]/@rdf:about"/></xsl:with-param></xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat($namespace,generate-id(*[position()=1]))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  

   
  <xsl:template match="*" />

  
</xsl:stylesheet>

<!-- Referring to http://www-2.cs.cmu.edu/~sadeh/MyCampusMirror/ROWL/OWLOntology2Jess.xsl -->

<!-- Referring to http://www-2.cs.cmu.edu/~sadeh/MyCampusMirror/ROWL/OWLAnnotation2Jess.xsl -->
