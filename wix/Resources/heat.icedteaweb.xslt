<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:wix="http://schemas.microsoft.com/wix/2006/wi">
 <xsl:output omit-xml-declaration="yes" indent="yes"/>
 <xsl:template match="node()|@*">
  <xsl:copy>
   <xsl:apply-templates select="node()|@*"/>
  </xsl:copy>
 </xsl:template>  

 <xsl:template match="wix:Directory[@Name='bin']/@Id">
  <xsl:attribute name="Id">IcedTeaWebBin</xsl:attribute>
 </xsl:template>

</xsl:stylesheet>