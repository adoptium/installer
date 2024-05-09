<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:wix="http://wixtoolset.org/schemas/v4/wxl"
  xmlns="http://wixtoolset.org/schemas/v4/wxl"
  exclude-result-prefixes="xsl wix">

  <xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />

  <xsl:strip-space elements="*" />

  <xsl:key name="FileToRemove"
    match="wix:Component[contains(wix:File/@Source, '$(var.ReproDir)\src.zip')]"
    use="@Id" />

  <xsl:key name="FileToRemove"
    match="wix:Component[contains(wix:File/@Source, '$(var.ReproDir)\lib\src.zip')]"
    use="@Id" />

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>

  <!-- Remove the files -->
  <xsl:template
    match="*[self::wix:Component or self::wix:ComponentRef]
                        [key('FileToRemove', @Id)]" />
</xsl:stylesheet>