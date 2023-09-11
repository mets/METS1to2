<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mets2="http://www.loc.gov/METS/v2"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:mets="http://www.loc.gov/METS/" 
    xmlns:xlink="http://www.w3.org/1999/xlink"
    xmlns:xlinktr="http://www.w3.org/TR/xlink"
    exclude-result-prefixes="xs mets xlink xlinktr" version="1.0">

    <!--
     Transforms METS1 to draft METS2
     
     Version 0.2 (2023-01-23)
     
     - flattens nested filegroups
     - migrates XPTR attribute to LOCREF
     - XSLT 1.0 implementation for maximum compatibility
     - removes unused namespace declarations
     - handle alternate xlink namespace (not valid in current version of METS schema, but shows up in some METS profiles, and not difficult to handle) 
     
     Version 0.1 (2022-12-22)
     
     - adds METS2 schema
     - changes namespace of METS1 elements to METS2
     - puts dmdSec, amdSec, techMD, rightsMD, sourceMD, digiprovMD into mdGrp sections and md elements
     - changes xlink:href to LOCREF and warns on usage of other xlink attributes
     - maps OTHER attributes to their non-OTHER versions (and warn if this would mask a non-OTHER original attribute) 
     - wraps structMaps in structSec element
     - gives an error if structLink, behaviorSec, XPTR, or nested filegroups are used
     - keeps all other elements & attributes as-is
     
    Known issues:

     - Doesn't remove the old XSD from xsi:schemaLocation
     
     - The message regarding nested fileGrp elements could be more useful.
     
     - Namespace declarations get pushed down to xmlData nodes - if you want other namespaces (e.g. PREMIS) to appear at the top level,
       add them to the namespace declarations in the xsl:stylesheet above, matching prefixes in the input document.
     
     Aaron Elkiss <aelkiss@hathitrust.org>
        
     -->

    <xsl:output method="xml" indent="yes"/>

    <xsl:template match="mets:mets">

        <mets2:mets>
            <!-- to-do: remove old METS and Xlink schema -->
            <xsl:attribute name="xsi:schemaLocation">
                <xsl:value-of
                    select="concat('http://www.loc.gov/METS/v2 https://raw.githubusercontent.com/mets/METS-schema/mets2/v2/mets.xsd ', @xsi:schemaLocation)"
                />
            </xsl:attribute>                                  

            <!-- keep attributes and metsHdr as-is -->
            <xsl:apply-templates select="mets:metsHdr | @*[name() != xsi:schemaLocation]"/>

            <xsl:if test="mets:dmdSec | mets:amdSec">
                <mets2:mdSec>
                    <xsl:if test="mets:dmdSec">
                        <mets2:mdGrp USE="DESCRIPTIVE">
                            <xsl:apply-templates select="mets:dmdSec"/>
                        </mets2:mdGrp>
                    </xsl:if>
                    <xsl:apply-templates select="mets:amdSec"/>
                </mets2:mdSec>

            </xsl:if>

            <xsl:apply-templates select="mets:fileSec"/>

            <mets2:structSec>
                <xsl:apply-templates select="mets:structMap"/>
            </mets2:structSec>

        </mets2:mets>


    </xsl:template>

    <!-- change each metadata section type to mets2 md -->
    <xsl:template match="mets:dmdSec">
        <mets2:md>
            <xsl:apply-templates select="node() | @*"/>
        </mets2:md>
    </xsl:template>

    <xsl:template match="mets:amdSec">
        <mets2:mdGrp USE="ADMINISTRATIVE">
            <xsl:apply-templates select="node() | @*"/>
        </mets2:mdGrp>
    </xsl:template>

    <xsl:template match="mets:techMD">
        <mets2:md USE="TECHNICAL">
            <xsl:apply-templates select="node() | @*"/>
        </mets2:md>
    </xsl:template>

    <xsl:template match="mets:rightsMD">
        <mets2:md USE="RIGHTS">
            <xsl:apply-templates select="node() | @*"/>
        </mets2:md>
    </xsl:template>

    <xsl:template match="mets:sourceMD">
        <mets2:md USE="SOURCE">
            <xsl:apply-templates select="node() | @*"/>
        </mets2:md>
    </xsl:template>

    <xsl:template match="mets:digiprovMD">
        <mets2:md USE="PROVENANCE">
            <xsl:apply-templates select="node() | @*"/>
        </mets2:md>
    </xsl:template>
    
    <xsl:template match="mets:mdRef">
        <xsl:element name="mets2:mdRef">
            <xsl:choose>
                <xsl:when test="self::*[@xlink:href | @xlinktr:href][@XPTR]">
                    <!-- todo refactor with attr string join -->
                    <xsl:message>INFO: Found mdRef@XPTR attribute; appending as a URL fragment to @xlink:href</xsl:message>
                    <xsl:attribute name="LOCREF">
                        <xsl:value-of select="concat(@xlink:href, @xlinktr:href, '#', @XPTR)"/>
                    </xsl:attribute>
                    <xsl:apply-templates select="node() | @*[name() != 'xlink:href'][name() != 'XPTR']"/>
                </xsl:when>
                <xsl:when test="self::*[@XPTR]">
                    <xsl:message>WARNING: Found mdRef with only @XPTR and no @xlink:href; setting LOCTYPE to "XPTR" and LOCREF to @XPTR</xsl:message>
                    <xsl:attribute name="LOCTYPE">XPTR</xsl:attribute>
                    <xsl:attribute name="LOCREF"><xsl:value-of select="@XPTR"/></xsl:attribute>
                    <xsl:apply-templates select="node() | @*[name() != 'XPTR'][name() != 'LOCTYPE'][name() != 'OTHERLOCTYPE']"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="node() | @*"/>
                </xsl:otherwise>
            </xsl:choose>    

        </xsl:element>
    </xsl:template>

    <!-- Flatten nested file groups -->
    <xsl:template match="mets:fileSec">
        <xsl:element name="mets2:fileSec">
            <xsl:apply-templates select="@*" />
            
            <!-- output each filegrp that has files at the top level -->
            <xsl:for-each select=".//mets:fileGrp[mets:file]">
                <!-- collect the USE and ADMID attributes for each parent fileGrp and concatenate; warn if we lose something? -->
                <xsl:element name="mets2:fileGrp">
                    <xsl:call-template name="attr-string-join">
                        <xsl:with-param name="attrname">USE</xsl:with-param>
                        <xsl:with-param name="tokens" select="ancestor-or-self::mets:fileGrp/@USE"/>
                    </xsl:call-template>
                    
                    <xsl:call-template name="attr-string-join">
                        <xsl:with-param name="attrname">MDID</xsl:with-param>
                        <xsl:with-param name="tokens" select="ancestor-or-self::mets:fileGrp/@ADMID"/>
                    </xsl:call-template>
                    
                    <!-- FIXME: Output fileGrp elements are missing @ID?? -->
                    <!-- process immediate child files (but not descendents - they would appear in their own immediate parent fileGrp) -->
                    <xsl:apply-templates select="mets:file | @*[name() != 'USE'][name() != 'ADMID']"/>
                </xsl:element>
            </xsl:for-each>
            <xsl:for-each select=".//mets:fileGrp[not(mets:file)]">
                <xsl:message terminate="no">WARNING: Not outputting fileGrp with no file children, @ID=<xsl:value-of select="@ID"/>, @USE=<xsl:value-of select="@USE"/>. @VERSDATE (if present) will be lost; @USE and @ADMID will be concatenated with child fileGrp values.</xsl:message>
            </xsl:for-each>
        </xsl:element>
    </xsl:template>  
    
    <!-- error if the METS uses sections that are unsupported in METS2 -->
    <xsl:template match="mets:behaviorSec | mets:structLink">
        <xsl:message terminate="yes">ERROR: <xsl:value-of select="name()"/> is not supported in
            METS2</xsl:message>. METS 1 continues to support these sections.
    </xsl:template>
 
    <!-- Remove original ADMID, DMDID, XPTR -->
    <xsl:template match="mets:*/@ADMID | mets:*/@DMDID | mets:*/@XPTR"/>

    <!-- Map OTHERROLE, OTHERTYPE, OTHERMDTYPE, OTHERLOCTYPE attributes to their standard form; 
        warn if ROLE/TYPE/MDTYPE/LOCTYPE is not present and equal to OTHER -->

    <xsl:template match="mets:*/@*[starts-with(name(), 'OTHER')]">
        <xsl:variable name="baseattr" select="substring(name(), string-length('OTHER') + 1)"/>
        <xsl:if test="not(../@*[name() = $baseattr] = 'OTHER')">
            <xsl:message terminate="no">WARNING: <xsl:value-of select="name()"/> is present, but not
                    @<xsl:value-of select="$baseattr"/>=OTHER</xsl:message>
        </xsl:if>
        <xsl:attribute name="{ $baseattr }">
            <xsl:value-of select="."/>
        </xsl:attribute>
    </xsl:template>
    
    <!-- Change the namespace on any other METS1 elements to METS2, and concatenate ADMID and DMDID into MDID -->
    <xsl:template match="mets:*">
        <xsl:element name="mets2:{local-name()}">
            <!-- TODO refactor with attr-string-join -->
            <xsl:choose>
                <xsl:when test="self::*[@ADMID][@DMDID]">
                    <xsl:attribute name="MDID">
                        <xsl:value-of select="concat(@ADMID, ' ', @DMDID)"/>
                    </xsl:attribute>
                </xsl:when>
                <xsl:when test="@ADMID">
                    <xsl:attribute name="MDID">
                        <xsl:value-of select="@ADMID"/>
                    </xsl:attribute>
                </xsl:when>
                <xsl:when test="@DMDID">
                    <xsl:attribute name="MDID">
                        <xsl:value-of select="@DMDID"/>
                    </xsl:attribute>
                </xsl:when>
            </xsl:choose>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:element>
    </xsl:template>

    <!-- XLINK REMOVAL -->

    <!-- map xlink:href to LOCREF -->
    <xsl:template match="mets:*/@xlink:href | mets:*/@xlinktr:href">
        <xsl:attribute name="LOCREF">
            <xsl:value-of select="."/>
        </xsl:attribute>
    </xsl:template>
    

    <!-- discard xlink:type -->
    <xsl:template match="mets:*/@xlink:type[. = 'simple'] | mets:*/@xlink:atrtype[. = 'simple']"/>
    
    <!-- discard and warn for any remaining xlink attribute -->
    <xsl:template match="mets:*/@xlink:* | mets:*/@xlinktr:*" priority="-1">
        <xsl:message terminate="no">WARNING: <xsl:value-of select="name()"/> is not supported in
            METS2; discarded <xsl:value-of select="name(parent::*)"/> attribute <xsl:value-of
                select="name()"/>="<xsl:value-of select="."/>"</xsl:message>
    </xsl:template>

    
    <!-- Default element processing: copy, omitting extraneous namespace declarations
        
        (This is primarily useful for xmlData nodes as well as for METS embedded in other XML documents)
        
        This results in multiple declarations rather than a single one at the top level, but is simpler and likely more performant
        than other solutions for doing this.
        
        https://stackoverflow.com/questions/4593326/xsl-how-to-remove-unused-namespaces-from-source-xml -->
    
    <xsl:template match="*">
        <xsl:element name="{name()}" namespace="{namespace-uri()}">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:element>
    </xsl:template>
    
    <!-- Default for all other nodes: copy to output document -->
    
    <xsl:template match="@* | text() | comment() | processing-instruction()">
        <xsl:copy/>
    </xsl:template>
    
    <!-- Create an attribute attrname with the joined values of the nodes in tokens, if the node set is non-empty -->
    <xsl:template name="attr-string-join">
        <xsl:param name="attrname"/>
        <xsl:param name="tokens"/>
        <xsl:param name="separator" select="' '"></xsl:param>
        <xsl:if test="$tokens">
            <xsl:attribute name="{$attrname}">
                <xsl:for-each select="$tokens">
                    <xsl:if test="position() > 1">
                        <xsl:value-of select="$separator"/>
                    </xsl:if>
                    <xsl:value-of select="."/>
                </xsl:for-each>
            </xsl:attribute>
        </xsl:if>
    </xsl:template>


</xsl:stylesheet>
