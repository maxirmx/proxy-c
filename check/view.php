<head>
  <meta charset="UTF-8">
  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
  <meta http-equiv="Pragma" content="no-cache" />
  <meta http-equiv="Expires" content="0" />
  <title>Intrade Management. Search results</title>
  <link type="image/x-icon" rel="shortcut icon" href="https://intrademanagement.com/wp-content/uploads/2021/04/truck-ico.png">
  <link type="image/png" sizes="16x16" rel="icon" href="https://intrademanagement.com/wp-content/uploads/2021/04/truck-ico.png">
  <link rel="stylesheet" id="classic-theme-styles-css" href="https://intrademanagement.com/wp-includes/css/classic-themes.min.css?ver=6.2.2" media="all">
  <link rel="stylesheet" id="site-font-css" href="https://fonts.googleapis.com/css2?family=Open+Sans%3Awght%40400%3B700&amp;display=swap&amp;ver=6.2.2" media="all">
</head>

<?php
  $xml = new DOMDocument();
  $xml->loadXML(file_get_contents("http://components.intrademanagement.com/search?pn=" . $_GET['pn'] . "&from=intrademanagement"));

  $xsltp = new XSLTProcessor();
  $xsl = new DOMDocument();
  $xslt=<<<EOT
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="data">
<tbody>
      <xsl:apply-templates select="item" />
</tbody>
  </xsl:template>
  <xsl:template match="item">
    <tr>
      <td><xsl:value-of select="part" /></td>
      <td><xsl:value-of select="mfg" /></td>
      <td>6-10 weeks</td>
    </tr>
  </xsl:template>
</xsl:stylesheet>
EOT
;
  $xsl->loadXML($xslt);
  $xsltp->importStyleSheet($xsl);
  echo "<table border=1><thead><tr><td>Part Number</td><td>Manufacturer</td><td>Lead time</td></tr></thead>";
	echo $xsltp->transformToXML($xml);
  echo "</table>";
?>
